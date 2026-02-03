import Foundation
import Combine

struct TrainGene {
    let trainId: UUID
    var departureOffset: TimeInterval // in seconds
    var stopDwellOffsets: [String: Double] // stationId -> extra dwell minutes (can be fractional for seconds)
    var stopTracks: [String: String] // stationId -> track name/number
}

struct Chromosome {
    var genes: [TrainGene]
    var fitness: Double = 0.0
    var conflictingTrainIds: Set<UUID> = []
}

class GeneticOptimizer: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentGeneration = 0
    @Published var bestFitness = Double.infinity
    @Published var conflictCount = 0
    
    // Performance settings (PIGNOLO BOOSTED)
    private let populationSize = 60
    private let maxGenerations = 250
    private let mutationRate = 0.3
    
    // Pre-calculated paths to avoid A* searches during evaluate
    private var precalculatedPaths: [UUID: [[Edge]?]] = [:]
    
    /// Main entry point for optimization.
    func optimize(newTrains: [Train], existingTrains: [Train], network: RailwayNetwork, iterations: Int? = nil) async -> [Train] {
        await MainActor.run {
            self.isRunning = true
            self.progress = 0.0
            self.currentGeneration = 0
            self.bestFitness = Double.infinity
        }
        
        // 0. Pre-calculate paths for all trains (HUGE performance gain)
        precalculatedPaths.removeAll()
        for train in (newTrains + existingTrains) {
            var trainPaths: [[Edge]? ] = []
            var prevId = train.stops.first?.stationId ?? ""
            for j in train.stops.indices {
                if j == 0 { 
                    trainPaths.append(nil) 
                } else {
                    let stop = train.stops[j]
                    let path = network.findPathEdges(from: prevId, to: stop.stationId)
                    trainPaths.append(path)
                    prevId = stop.stationId
                }
            }
            precalculatedPaths[train.id] = trainPaths
        }
        
        let actualMaxGenerations = iterations ?? maxGenerations
        var population: [Chromosome] = []
        population.append(createIdentityChromosome(for: newTrains, network: network))
        
        for _ in 1..<populationSize {
            population.append(createRandomChromosome(for: newTrains, network: network, intensity: 0.3))
        }
        
        // PIGNOLO PROTOCOL: Heavy optimization loop
        for gen in 0..<actualMaxGenerations {
            // Permit UI updates and check for cancellation
            if gen % 5 == 0 {
                await Task.yield()
            }
            
            // 1. Parallel Evaluation of Fitness (Background Threads)
            let currentPopulation = population
            let evaluatedPopulation = await withTaskGroup(of: (Int, Double, Set<UUID>).self) { group in
                for i in currentPopulation.indices {
                    group.addTask {
                        let (fit, ids) = self.evaluate(
                            chromosome: currentPopulation[i],
                            candidateTrains: newTrains,
                            fixedTrains: existingTrains,
                            network: network
                        )
                        return (i, fit, ids)
                    }
                }
                
                var results: [(Int, Double, Set<UUID>)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            // Map results back to population
            for (index, fit, ids) in evaluatedPopulation {
                population[index].fitness = fit
                population[index].conflictingTrainIds = ids
            }
            
            // 2. Selection & Update UI
            population.sort { $0.fitness < $1.fitness }
            
            let best = population[0]
            let topConflictCount = best.conflictingTrainIds.count
            let currentProgress = Double(gen) / Double(actualMaxGenerations)
            
            await MainActor.run {
                self.bestFitness = best.fitness
                self.progress = currentProgress
                self.conflictCount = topConflictCount
                self.currentGeneration = gen
            }
            
            if topConflictCount == 0 && gen >= 5 {
                print("🧬 [GA] Soluzione Ottimale Trovata: 0 Conflitti alla Gen \(gen).")
                break
            }
            
            // 3. Breeding next generation
            var nextGen = Array(population.prefix(5)) // Elitism
            while nextGen.count < populationSize {
                let p1 = selectParent(from: population)
                let p2 = selectParent(from: population)
                var child = crossover(p1: p1, p2: p2)
                mutate(chromosome: &child, network: network)
                nextGen.append(child)
            }
            population = nextGen
        }
        
        await MainActor.run {
            self.isRunning = false
            self.progress = 1.0
        }
        
        return apply(chromosome: population[0], to: newTrains, network: network)
    }
    
    private func createIdentityChromosome(for trains: [Train], network: RailwayNetwork) -> Chromosome {
        let genes = trains.map { train in
            var tracks: [String: String] = [:]
            var dwellOffsets: [String: Double] = [:]
            for stop in train.stops {
                dwellOffsets[stop.stationId] = stop.extraDwellTime
                tracks[stop.stationId] = stop.track ?? "1"
            }
            return TrainGene(
                trainId: train.id,
                departureOffset: 0,
                stopDwellOffsets: dwellOffsets,
                stopTracks: tracks
            )
        }
        return Chromosome(genes: genes)
    }

    private func createRandomChromosome(for trains: [Train], network: RailwayNetwork, intensity: Double = 1.0) -> Chromosome {
        let genes = trains.map { train in
            var dwellOffsets: [String: Double] = [:]
            var tracks: [String: String] = [:]
            for stop in train.stops {
                // Se intensity < 1, riduciamo la probabilità di sosta aggiuntiva casuale
                let maxRandomDwell = Double(10.0 * intensity)
                dwellOffsets[stop.stationId] = Double(Int.random(in: 0...Int(max(1, maxRandomDwell))))
                
                if let _ = network.nodes.first(where: { $0.id == stop.stationId }) {
                    tracks[stop.stationId] = stop.track ?? "1"
                }
            }
            
            let maxShift = Int(15.0 * intensity)
            return TrainGene(
                trainId: train.id,
                departureOffset: TimeInterval(Int.random(in: -maxShift...maxShift) * 60),
                stopDwellOffsets: dwellOffsets,
                stopTracks: tracks
            )
        }
        return Chromosome(genes: genes)
    }
    
    private func evaluate(chromosome: Chromosome, candidateTrains: [Train], fixedTrains: [Train], network: RailwayNetwork) -> (Double, Set<UUID>) {
        let updatedSubset = apply(chromosome: chromosome, to: candidateTrains, network: network)
        let allTrains = updatedSubset + fixedTrains
        
        // 1. Conflict penalty (SUPREME PRIORITY)
        let tempManager = ConflictManager()
        let conflicts = tempManager.calculateConflicts(network: network, trains: allTrains)
        let conflictCount = conflicts.count
        let conflictPenalty = Double(conflictCount) * 1000000.0 // PIGNOLO: even higher to force 0 conflicts
        
        var conflictingIds = Set<UUID>()
        for c in conflicts {
            conflictingIds.insert(c.trainAId)
            conflictingIds.insert(c.trainBId)
        }
        
        // 2. Travel Time & Deviation (EFFICIENCY PRIORITY)
        var travelTimeMinutes = 0.0
        var deviationPenalty = 0.0
        
        for (i, train) in updatedSubset.enumerated() {
            if let start = train.stops.first?.departure, let end = train.stops.last?.arrival {
                let duration = end.timeIntervalSince(start) / 60.0
                travelTimeMinutes += duration
            }
            
            let gene = chromosome.genes[i]
            let originalTrain = candidateTrains[i]
            
            // Penalty for base departure shift (to avoid arbitrary large gaps)
            deviationPenalty += abs(gene.departureOffset) / 20.0 
            
            // Track changes penalty
            for (j, stop) in originalTrain.stops.enumerated() {
                let currentTrack = gene.stopTracks[stop.stationId] ?? "1"
                let originalTrack = stop.track ?? "1"
                if currentTrack != originalTrack {
                    let isTerminal = (j == 0 || j == originalTrain.stops.count - 1)
                    deviationPenalty += isTerminal ? 80.0 : 30.0
                }
            }
        }
        
        // BALANCED FITNESS: 
        // We want (0 conflicts) FIRST, then (minimum travel time), then (minimum deviation).
        let finalFitness = conflictPenalty + (travelTimeMinutes * 10.0) + deviationPenalty
        return (finalFitness, conflictingIds)
    }
    
    /// Applies a chromosome's changes to a specific set of trains and recalculates their physics-based schedules.
    private func apply(chromosome: Chromosome, to trains: [Train], network: RailwayNetwork) -> [Train] {
        var result = trains
        for i in result.indices {
            guard let gene = chromosome.genes.first(where: { $0.trainId == result[i].id }) else { continue }
            
            // 1. Shift Departure
            if let baseDep = result[i].departureTime {
                result[i].departureTime = baseDep.addingTimeInterval(gene.departureOffset)
            }
            
            // 2. Apply Dwell Offsets and Tracks to Stops
            for j in result[i].stops.indices {
                let sid = result[i].stops[j].stationId
                if let offset = gene.stopDwellOffsets[sid] {
                    result[i].stops[j].extraDwellTime = offset
                }
                if let track = gene.stopTracks[sid] {
                    result[i].stops[j].track = track
                }
            }
        }
        
        // 3. Recalculate all stop arrivals/departures locally (No side-effects on shared state)
        refreshSchedulesLocally(trains: &result, network: network)
        
        return result
    }
    
    private func refreshSchedulesLocally(trains: inout [Train], network: RailwayNetwork) {
        for i in trains.indices {
            guard let depTime = trains[i].departureTime, !trains[i].stops.isEmpty else { continue }
            
            var currentTime = depTime.normalized()
            let originId = trains[i].stops.first?.stationId ?? ""
            var prevId = originId
            
            for j in trains[i].stops.indices {
                let stop = trains[i].stops[j]
                let isSkipped = stop.isSkipped
                
                if stop.stationId == originId && j == 0 {
                    // ORIGIN
                    trains[i].stops[j].arrival = nil
                    let departure = stop.plannedDeparture?.normalized() ?? currentTime
                    trains[i].stops[j].departure = departure
                    currentTime = departure
                } else {
                    // LEG TRANSIT - Calculate as continuous motion between stops
                    var legDistance: Double = 0
                    var legMinSpeed: Double = Double.infinity
                    
                    let path = precalculatedPaths[trains[i].id]?[j]
                    if let actualPath = path {
                        for edge in actualPath {
                            legDistance += edge.distance
                            legMinSpeed = min(legMinSpeed, Double(edge.maxSpeed))
                        }
                    }
                    
                    var transitDuration: TimeInterval = 0
                    if legDistance > 0 {
                        let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: legDistance,
                            maxSpeedKmh: legMinSpeed == .infinity ? 100 : legMinSpeed,
                            train: trains[i],
                            initialSpeedKmh: 0,
                            finalSpeedKmh: 0
                        )
                        transitDuration = hours * 3600
                    }
                    
                    // PIGNOLO PROTOCOL: Sync perfectly with TrainManager.refreshSchedules
                    currentTime = currentTime.addingTimeInterval(transitDuration)
                    
                    let roundedArrVal = floor(currentTime.timeIntervalSinceReferenceDate + 0.5)
                    let roundedArrival = Date(timeIntervalSinceReferenceDate: roundedArrVal)
                    
                    let actualArrival = stop.plannedArrival?.normalized() ?? roundedArrival
                    trains[i].stops[j].arrival = actualArrival
                    
                    // CRITICAL FIX: Include extraDwellTime (CTC/AI/GA offsets)
                    let baseDwell = isSkipped ? 0 : Double(stop.minDwellTime)
                    let dwellDuration = (baseDwell + stop.extraDwellTime) * 60
                    
                    let earliestDep = actualArrival.addingTimeInterval(dwellDuration)
                    let targetDep = stop.plannedDeparture?.normalized() ?? earliestDep
                    
                    let finalDep = max(earliestDep, targetDep)
                    let roundedDepVal = floor(finalDep.timeIntervalSinceReferenceDate + 0.5)
                    let roundedDep = Date(timeIntervalSinceReferenceDate: roundedDepVal)
                    
                    trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? roundedDep : nil
                    currentTime = roundedDep
                }
                prevId = stop.stationId
            }
        }
    }
    
    private func detectConflictsCount(trains: [Train], network: RailwayNetwork) -> Int {
        let tempManager = ConflictManager()
        return tempManager.calculateConflicts(network: network, trains: trains).count
    }
    
    private func selectParent(from population: [Chromosome]) -> Chromosome {
        let i1 = Int.random(in: 0..<population.count)
        let i2 = Int.random(in: 0..<population.count)
        return population[i1].fitness < population[i2].fitness ? population[i1] : population[i2]
    }
    
    private func crossover(p1: Chromosome, p2: Chromosome) -> Chromosome {
        var childGenes: [TrainGene] = []
        for i in p1.genes.indices {
            childGenes.append(Bool.random() ? p1.genes[i] : p2.genes[i])
        }
        return Chromosome(genes: childGenes)
    }
    
    private func mutate(chromosome: inout Chromosome, network: RailwayNetwork) {
        let conflictingIndices = chromosome.genes.indices.filter { i in
            chromosome.conflictingTrainIds.contains(chromosome.genes[i].trainId)
        }
        
        // Elitism: We only mutate trains with conflicts + a small percentage of others to explore efficiency
        let targets = conflictingIndices.isEmpty ? Array(chromosome.genes.indices) : conflictingIndices
        
        for i in targets {
            let trainId = chromosome.genes[i].trainId
            let isConflicting = chromosome.conflictingTrainIds.contains(trainId)
            let mutationChance = isConflicting ? mutationRate * 2.5 : mutationRate * 0.5 
            
            if Double.random(in: 0...1) < mutationChance {
                let r = Double.random(in: 0...1)
                
                if isConflicting && r < 0.6 {
                    // Precision Shift to clear the track
                    let shift = Double(Int.random(in: 1...10) * (Bool.random() ? 1 : -1))
                    chromosome.genes[i].departureOffset += (shift * 60)
                } else {
                    let rr = Double.random(in: 0...1)
                    if rr < 0.3 {
                        // Change track at a station
                        let stations = Array(chromosome.genes[i].stopTracks.keys)
                        if let sid = stations.randomElement(),
                           let node = network.nodes.first(where: { $0.id == sid }), (node.platforms ?? 2) > 1 {
                            let maxPlatforms = min(node.platforms ?? 2, 8)
                            chromosome.genes[i].stopTracks[sid] = "\(Int.random(in: 1...maxPlatforms))"
                        }
                    } else if rr < 0.5 {
                        // NUDGE MUTATION: Small dwell adjustment (+/- 30s or 60s) for micro-conflicts
                        let stations = Array(chromosome.genes[i].stopDwellOffsets.keys)
                        if let sid = stations.randomElement() {
                            let current = chromosome.genes[i].stopDwellOffsets[sid] ?? 0
                            let nudge = Bool.random() ? 0.5 : 1.0 // 0.5 min = 30s
                            let direction = Bool.random() ? 1.0 : -1.0
                            chromosome.genes[i].stopDwellOffsets[sid] = max(0, current + (nudge * direction))
                        }
                    } else {
                        // Regular Dwell mutation
                        let stations = Array(chromosome.genes[i].stopDwellOffsets.keys)
                        if let sid = stations.randomElement() {
                            let current = chromosome.genes[i].stopDwellOffsets[sid] ?? 0
                            let change = Double(Int.random(in: -1...3))
                            chromosome.genes[i].stopDwellOffsets[sid] = max(0, current + change)
                        }
                    }
                }
            }
        }
    }
}
