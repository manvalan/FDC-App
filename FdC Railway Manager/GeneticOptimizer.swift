import Foundation
import Combine

// PIGNOLO SPEED: Using structs for memory efficiency and arrays for O(1) access
struct TrainGene {
    let trainId: UUID
    var departureOffset: Double // in seconds
    var stopDwellOffsets: [Double] // Indexed by stop index
    var stopTracks: [String] // Indexed by stop index
    var legTransitTimes: [Double] // seconds
}

// LITE MODELS: Minimal data package for the evaluation loop to avoid cloning Train classes
struct LiteStop {
    let stationId: String
    var arrival: Double? // timeIntervalSinceReferenceDate
    var departure: Double? // timeIntervalSinceReferenceDate
    var extraDwell: Double // minutes
    var track: String
    let isManualTrack: Bool
    let isPreferredTrack: Bool
    let isSkipped: Bool
    let minDwell: Double
    let plannedArrival: Double?
    let plannedDeparture: Double?
}

struct LiteTrain {
    let id: UUID
    let name: String
    let lineId: String?
    var departureTime: Double
    var stops: [LiteStop]
    let maxSpeed: Double
    let acceleration: Double
    let deceleration: Double
}

struct Chromosome {
    var genes: [TrainGene]
    var fitness: Double = 0.0
    var conflictingTrainIds: Set<UUID> = []
    var conflictLocations: [UUID: Set<String>] = [:] // trainId -> Set of resourceIds
}

class GeneticOptimizer: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentGeneration = 0
    @Published var bestFitness = Double.infinity
    @Published var conflictCount = 0
    
    // Performance settings (PIGNOLO BOOSTED)
    private let populationSize = 100
    private let maxGenerations = 300
    private let mutationRate = 0.38
    
    // Cached platform info for fast evaluation
    private var stationCapacities: [String: Int] = [:]
    private var segmentCapacities: [String: Int] = [:]
    
    // State for stagnation detection
    private var lastBestConflictCount = 999
    private var stagnationGenerations = 0
    private var currentAdaptiveMutationRate: Double = 0.38
    
    @MainActor
    func optimize(newTrains: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], iterations: Int? = nil) async -> [Train] {
        await MainActor.run {
            self.isRunning = true
            self.progress = 0.0
            self.currentGeneration = 0
            self.bestFitness = Double.infinity
        }
        
        // 0. Spatial Filtering
        let focusResourceIds = Set(newTrains.flatMap { train -> [String] in
            var resources: [String] = []
            var prevId: String? = nil
            for stop in train.stops {
                resources.append("STATION::\(stop.stationId)")
                if let prev = prevId {
                    let path = NetworkModel.findPathEdges(from: prev, to: stop.stationId, edges: edges) ?? []
                    resources.append(contentsOf: path.map { "SEGMENT::\($0.canonicalKey)" })
                }
                prevId = stop.stationId
            }
            return resources
        })
        
        let relevantFixedTrains = existingTrains.filter { bgTrain in
            var bgResources: [String] = []
            var prevId: String? = nil
            for stop in bgTrain.stops {
                bgResources.append("STATION::\(stop.stationId)")
                if let prev = prevId {
                    let path = NetworkModel.findPathEdges(from: prev, to: stop.stationId, edges: edges) ?? []
                    bgResources.append(contentsOf: path.map { "SEGMENT::\($0.canonicalKey)" })
                }
                prevId = stop.stationId
            }
            return !Set(bgResources).isDisjoint(with: focusResourceIds)
        }
        
        // PIGNOLO: Pre-calculate Allowed Tracks for each stop of each train to avoid lookups in evaluate
        var allowedTracksPerStop: [UUID: [Set<String>]] = [:]
        for train in (newTrains + relevantFixedTrains) {
            var stopConstraints: [Set<String>] = []
            for j in train.stops.indices {
                let stop = train.stops[j]
                guard let node = nodes.first(where: { $0.id == stop.stationId }) else {
                    stopConstraints.append(["1"])
                    continue
                }
                let nextId = (j < train.stops.count - 1) ? train.stops[j+1].stationId : nil
                let prevId = (j > 0) ? train.stops[j-1].stationId : nil
                let allowed = node.getTracksByProvenance(from: prevId, nextStationId: nextId, forLine: train.lineId)
                stopConstraints.append(Set(allowed))
            }
            allowedTracksPerStop[train.id] = stopConstraints
        }

        // Pre-calculate Capacities and Paths
        let conflictMgr = ConflictManager()
        let caps = conflictMgr.getResourceCapacities(nodes: nodes, edges: edges)
        self.stationCapacities = caps.filter { $0.key.hasPrefix("STATION_GLOBAL") }
        self.segmentCapacities = caps.filter { $0.key.hasPrefix("SEGMENT") }
        
        var precalculatedPaths: [UUID: [[Edge]?]] = [:]
        for train in (newTrains + relevantFixedTrains) {
            var trainPaths: [[Edge]? ] = []
            var prevId = train.stops.first?.stationId ?? ""
            for j in train.stops.indices {
                if j == 0 { trainPaths.append(nil) }
                else {
                    let stop = train.stops[j]
                    let path = NetworkModel.findPathEdges(from: prevId, to: stop.stationId, edges: edges)
                    trainPaths.append(path)
                    prevId = stop.stationId
                }
            }
            precalculatedPaths[train.id] = trainPaths
        }
        
        // Convert to Lite structures
        let liteFixed = relevantFixedTrains.map { convertToLite(train: $0, precalculatedPaths: precalculatedPaths) }
        let liteNew = newTrains.map { convertToLite(train: $0, precalculatedPaths: precalculatedPaths) }
        
        let baseTransitTimes = precalculateTransitTimes(liteTrains: liteNew + liteFixed, edges: edges, precalculatedPaths: precalculatedPaths)
        
        var population: [Chromosome] = []
        population.append(createIdentityChromosome(for: liteNew, transitTimes: baseTransitTimes))
        
        for _ in 1..<populationSize {
            population.append(createRandomChromosome(for: liteNew, nodes: nodes, transitTimes: baseTransitTimes, allowedTracks: allowedTracksPerStop, intensity: 0.3))
        }
        
        let actualMaxGenerations = iterations ?? maxGenerations
        lastBestConflictCount = 999
        stagnationGenerations = 0
        currentAdaptiveMutationRate = mutationRate
        
        for gen in 0..<actualMaxGenerations {
            if gen % 10 == 0 {
                await Task.yield()
                if Task.isCancelled { break }
            }
            
            let currentPopulation = population
            let evaluatedPopulation = await withTaskGroup(of: (Int, Double, Set<UUID>, [UUID: Set<String>]).self) { group in
                for i in currentPopulation.indices {
                    group.addTask {
                        let (fit, ids, locations) = GeneticOptimizer.evaluate(
                            chromosome: currentPopulation[i],
                            candidateTrains: liteNew,
                            fixedTrains: liteFixed,
                            nodes: nodes,
                            edges: edges,
                            precalculatedPaths: precalculatedPaths,
                            stationCapacities: self.stationCapacities,
                            segmentCapacities: self.segmentCapacities,
                            allowedTracks: allowedTracksPerStop
                        )
                        return (i, fit, ids, locations)
                    }
                }
                
                var results: [(Int, Double, Set<UUID>, [UUID: Set<String>])] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
            
            for (index, fit, ids, locations) in evaluatedPopulation {
                population[index].fitness = fit
                population[index].conflictingTrainIds = ids
                population[index].conflictLocations = locations
            }
            
            population.sort { $0.fitness < $1.fitness }
            let best = population[0]
            
            await MainActor.run {
                self.bestFitness = best.fitness
                self.progress = Double(gen) / Double(actualMaxGenerations)
                self.conflictCount = best.conflictingTrainIds.count
                self.currentGeneration = gen
            }
            
            if best.conflictingTrainIds.count == 0 && gen >= 8 { break }
            
            if best.conflictingTrainIds.count < lastBestConflictCount {
                lastBestConflictCount = best.conflictingTrainIds.count
                stagnationGenerations = 0
                currentAdaptiveMutationRate = mutationRate
            } else {
                stagnationGenerations += 1
                if stagnationGenerations > 25 {
                    currentAdaptiveMutationRate = min(0.85, currentAdaptiveMutationRate * 1.04)
                }
            }
            
            var nextGen = Array(population.prefix(12))
            while nextGen.count < populationSize {
                let p1 = selectParent(from: population)
                let p2 = selectParent(from: population)
                var child = crossover(p1: p1, p2: p2)
                mutate(chromosome: &child, nodes: nodes, contextTrains: liteNew + liteFixed, allowedTracks: allowedTracksPerStop, rate: currentAdaptiveMutationRate)
                nextGen.append(child)
            }
            population = nextGen
        }
        
        await MainActor.run {
            self.isRunning = false
            self.progress = 1.0
        }
        
        // Final application
        var finalLite = GeneticOptimizer.apply(chromosome: population[0], to: liteNew, edges: edges, precalculatedPaths: precalculatedPaths)
        
        // PIGNOLO CLEANUP: Force correct tracks if GA missed any routing constraints, but NOT for manual tracks
        for i in finalLite.indices {
            let tid = finalLite[i].id
            guard let constraints = allowedTracksPerStop[tid] else { continue }
            for j in finalLite[i].stops.indices {
                if finalLite[i].stops[j].isManualTrack { continue }
                let currentTrack = finalLite[i].stops[j].track
                if !constraints[j].contains(currentTrack) {
                    finalLite[i].stops[j].track = constraints[j].first ?? currentTrack
                }
            }
        }
        
        return reconstructTrains(lite: finalLite, original: newTrains, edges: edges, precalculatedPaths: precalculatedPaths)
    }
    
    private func convertToLite(train: Train, precalculatedPaths: [UUID: [[Edge]?]]) -> LiteTrain {
        let departure = train.departureTime?.timeIntervalSinceReferenceDate ?? 0
        let stops = train.stops.map { stop in
            LiteStop(
                stationId: stop.stationId,
                arrival: stop.arrival?.timeIntervalSinceReferenceDate,
                departure: stop.departure?.timeIntervalSinceReferenceDate,
                extraDwell: stop.extraDwellTime, 
                track: stop.track ?? "1", 
                isManualTrack: stop.isManualTrack, 
                isPreferredTrack: stop.isPreferredTrack,
                isSkipped: stop.isSkipped, 
                minDwell: Double(stop.minDwellTime), 
                plannedArrival: stop.plannedArrival?.timeIntervalSinceReferenceDate, 
                plannedDeparture: stop.plannedDeparture?.timeIntervalSinceReferenceDate
            )
        }
        return LiteTrain(
            id: train.id,
            name: train.name,
            lineId: train.lineId,
            departureTime: departure,
            stops: stops,
            maxSpeed: train.maxSpeed,
            acceleration: train.acceleration,
            deceleration: train.deceleration
        )
    }

    private func reconstructTrains(lite: [LiteTrain], original: [Train], edges: [Edge], precalculatedPaths: [UUID: [[Edge]?]]) -> [Train] {
        var result = original
        for i in result.indices {
            guard let l = lite.first(where: { $0.id == result[i].id }) else { continue }
            result[i].departureTime = Date(timeIntervalSinceReferenceDate: l.departureTime)
            for j in result[i].stops.indices {
                result[i].stops[j].extraDwellTime = l.stops[j].extraDwell
                result[i].stops[j].track = l.stops[j].track
                if let arr = l.stops[j].arrival { result[i].stops[j].arrival = Date(timeIntervalSinceReferenceDate: arr) }
                if let dep = l.stops[j].departure { result[i].stops[j].departure = Date(timeIntervalSinceReferenceDate: dep) }
            }
        }
        return result
    }

    private func precalculateTransitTimes(liteTrains: [LiteTrain], edges: [Edge], precalculatedPaths: [UUID: [[Edge]?]]) -> [UUID: [Double]] {
        var results: [UUID: [Double]] = [:]
        for train in liteTrains {
            var times: [Double] = []
            for j in train.stops.indices {
                if j == 0 { times.append(0) }
                else {
                    let path = precalculatedPaths[train.id]?[j]
                    var dist = 0.0
                    var minSpeed = Double.infinity
                    if let actualPath = path {
                        for edge in actualPath {
                            dist += edge.distance
                            minSpeed = min(minSpeed, Double(edge.maxSpeed))
                        }
                    }
                    if dist > 0 {
                        let vMaxLimit = min(Double(train.maxSpeed), minSpeed == .infinity ? 100 : minSpeed) / 3.6
                        let distM = dist * 1000.0
                        let a = train.acceleration
                        let d = train.deceleration
                        let accelDist = (vMaxLimit * vMaxLimit) / (2.0 * a)
                        let brakeDist = (vMaxLimit * vMaxLimit) / (2.0 * d)
                        let t: Double
                        if accelDist + brakeDist <= distM {
                            let cruiseDist = distM - accelDist - brakeDist
                            t = (vMaxLimit / a) + (cruiseDist / vMaxLimit) + (vMaxLimit / d)
                        } else {
                            let vPeak = sqrt((2.0 * a * d * distM) / (a + d))
                            t = (vPeak / a) + (vPeak / d)
                        }
                        times.append(t)
                    } else { times.append(0) }
                }
            }
            results[train.id] = times
        }
        return results
    }

    private func createIdentityChromosome(for trains: [LiteTrain], transitTimes: [UUID: [Double]]) -> Chromosome {
        let genes = trains.map { train in
            TrainGene(
                trainId: train.id,
                departureOffset: 0,
                stopDwellOffsets: train.stops.map { $0.extraDwell },
                stopTracks: train.stops.map { $0.track },
                legTransitTimes: transitTimes[train.id] ?? Array(repeating: 0.0, count: train.stops.count)
            )
        }
        return Chromosome(genes: genes)
    }

    private func createRandomChromosome(for trains: [LiteTrain], nodes: [Node], transitTimes: [UUID: [Double]], allowedTracks: [UUID: [Set<String>]], intensity: Double = 1.0) -> Chromosome {
        let genes = trains.map { train in
            let dwellOffsets = train.stops.indices.map { _ in Double(Int.random(in: 0...Int(10.0 * intensity))) }
            let tracks = train.stops.indices.map { j -> String in
                let allowed = allowedTracks[train.id]?[j] ?? ["1"]
                return allowed.randomElement() ?? "1"
            }
            let maxShift = 30.0 * 60.0 * intensity
            return TrainGene(
                trainId: train.id,
                departureOffset: Double.random(in: -maxShift...maxShift),
                stopDwellOffsets: dwellOffsets,
                stopTracks: tracks,
                legTransitTimes: transitTimes[train.id] ?? Array(repeating: 0.0, count: train.stops.count)
            )
        }
        return Chromosome(genes: genes)
    }

    private static func evaluate(chromosome: Chromosome, candidateTrains: [LiteTrain], fixedTrains: [LiteTrain], nodes: [Node], edges: [Edge], precalculatedPaths: [UUID: [[Edge]?]], stationCapacities: [String: Int], segmentCapacities: [String: Int], allowedTracks: [UUID: [Set<String>]]) -> (Double, Set<UUID>, [UUID: Set<String>]) {
        let updatedSubset = apply(chromosome: chromosome, to: candidateTrains, edges: edges, precalculatedPaths: precalculatedPaths)
        let allTrains = updatedSubset + fixedTrains
        
        var resourceOccupations: [String: [(Double, Double, UUID)]] = [:]
        var routingViolationCount = 0
        var constraintPenalty = 0.0
        var conflictingIds = Set<UUID>()
        var conflictLocs: [UUID: Set<String>] = [:]
        var conflictCount = 0
        
        for (i, train) in allTrains.enumerated() {
            let tid = train.id
            let isCandidate = i < updatedSubset.count
            let constraints = allowedTracks[tid]
            
            var totalExtraDwell = 0.0
            
            for j in train.stops.indices {
                let stop = train.stops[j]
                if stop.isSkipped { continue }
                
                // PIGNOLO: Enforce Dwell Constraints (Min 2.0, Max 15.0 per station)
                if isCandidate {
                    let totalDwell = stop.minDwell + stop.extraDwell
                    if totalDwell > 15.0 {
                        constraintPenalty += (totalDwell - 15.0) * 500000.0
                    } else if totalDwell < 2.0 {
                        constraintPenalty += (2.0 - totalDwell) * 1000000.0 // Hard limit
                    } else if totalDwell < stop.minDwell {
                        // Light penalty for reducing dwell (encourages 2min stops only if needed)
                        constraintPenalty += (stop.minDwell - totalDwell) * 10000.0
                    }
                    totalExtraDwell += stop.extraDwell
                }
                
                if isCandidate, let currentConstraints = constraints?[j] {
                    if !currentConstraints.contains(stop.track) {
                        routingViolationCount += 1
                        conflictingIds.insert(tid)
                        conflictLocs[tid, default: []].insert("ROUTING::\(stop.stationId)")
                    }
                }
                
                let trackResId = "TRACK::\(stop.stationId)::\(stop.track)"
                let globalResId = "STATION_GLOBAL::\(stop.stationId)"
                
                if let arr = stop.arrival, let dep = stop.departure {
                    let occ = (arr, dep + 5, train.id)
                    resourceOccupations[trackResId, default: []].append(occ)
                    resourceOccupations[globalResId, default: []].append(occ)
                }
                
                if j > 0, let depPrev = train.stops[j-1].departure, let arr = stop.arrival {
                    let path = precalculatedPaths[train.id]?[j]
                    if let actualPath = path {
                        let totalTime = arr - depPrev
                        let totalDist = actualPath.reduce(0.0) { $0 + $1.distance }
                        let avgSpeed = totalDist > 0 ? (totalDist / (totalTime / 3600.0)) : 0.0
                        var curr = depPrev
                        for edge in actualPath {
                            let transit = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                            let exit = curr + transit
                            let s1Id = edge.from < edge.to ? edge.from : edge.to
                            let s2Id = edge.from < edge.to ? edge.to : edge.from
                            let resId = "SEGMENT::\(s1Id)--\(s2Id)"
                            resourceOccupations[resId, default: []].append((curr, exit + 30, train.id))
                            curr = exit
                        }
                    }
                }
            }
            if isCandidate && totalExtraDwell > 30.0 {
                constraintPenalty += (totalExtraDwell - 30.0) * 1000000.0
            }
        }
        
        
        
        for (resId, occs) in resourceOccupations {
            let cap = resId.hasPrefix("STATION_GLOBAL") ? (stationCapacities[resId] ?? 1) : (resId.hasPrefix("SEGMENT") ? (segmentCapacities[resId] ?? 1) : 1)
            if occs.count <= cap { continue }
            
            var events: [(Double, Int, UUID)] = []
            for o in occs {
                events.append((o.0, 1, o.2))
                events.append((o.1, -1, o.2))
            }
            events.sort { $0.0 < $1.0 || ($0.0 == $1.0 && $0.1 < $1.1) }
            
            var active = Set<UUID>()
            for e in events {
                if e.1 == 1 {
                    active.insert(e.2)
                    if active.count > cap {
                        conflictCount += (active.count - cap)
                        for id in active {
                            conflictingIds.insert(id)
                            conflictLocs[id, default: []].insert(resId)
                        }
                    }
                } else { active.remove(e.2) }
            }
        }
        
        var travelTimePenalty = 0.0
        var deviationPenalty = 0.0
        var preferredTrackBonus = 0.0
        for (i, train) in updatedSubset.enumerated() {
            for j in train.stops.indices {
                if train.stops[j].isPreferredTrack && train.stops[j].track == candidateTrains[i].stops[j].track {
                    preferredTrackBonus += 500.0 // Give a healthy bonus for staying on preferred track
                }
            }
            if let start = train.stops.first?.departure, let end = train.stops.last?.arrival {
                travelTimePenalty += (end - start) / 60.0
            }
            let gene = chromosome.genes[i]
            deviationPenalty += abs(gene.departureOffset) / 30.0
            for j in train.stops.indices {
                if gene.stopTracks[j] != candidateTrains[i].stops[j].track {
                    deviationPenalty += (j == 0 || j == train.stops.count - 1) ? 100.0 : 40.0
                }
            }
        }
        
        let totalScore = Double(conflictCount) + (Double(routingViolationCount) * 10.0)
        let fitness = (totalScore * 2000000.0) + constraintPenalty + (travelTimePenalty * 15.0) + deviationPenalty - preferredTrackBonus
        return (fitness, conflictingIds, conflictLocs)
    }

    private static func apply(chromosome: Chromosome, to trains: [LiteTrain], edges: [Edge], precalculatedPaths: [UUID: [[Edge]?]]) -> [LiteTrain] {
        var result = trains
        for i in result.indices {
            guard let gene = chromosome.genes.first(where: { $0.trainId == result[i].id }) else { continue }
            result[i].departureTime += gene.departureOffset
            
            var totalExtra = 0.0
            for j in result[i].stops.indices {
                // CLAMP dwell time to [2.0, 15.0] min total per station
                let minAllowedExtra = max(-5.0, 2.0 - result[i].stops[j].minDwell) // Allow down to 2.0
                let maxAllowedExtra = max(0, 15.0 - result[i].stops[j].minDwell)
                var extra = max(minAllowedExtra, min(maxAllowedExtra, gene.stopDwellOffsets[j]))
                
                // Respect total extra limit of 30 mins
                if totalExtra + extra > 30.0 {
                    extra = max(0, 30.0 - totalExtra)
                }
                
                result[i].stops[j].extraDwell = extra
                totalExtra += extra
                result[i].stops[j].track = gene.stopTracks[j]
            }
            
            var curr = result[i].departureTime
            let origin = result[i].stops.first?.stationId ?? ""
            for j in result[i].stops.indices {
                let stop = result[i].stops[j]
                if stop.stationId == origin && j == 0 {
                    result[i].stops[j].arrival = nil
                    
                    // Departure at origin can be pushed by plannedDeparture
                    let dep = max(curr, stop.plannedDeparture ?? 0)
                    result[i].stops[j].departure = dep
                    curr = dep
                } else {
                    let transit = gene.legTransitTimes[j]
                    curr += transit
                    
                    // Respect plannedArrival
                    let arrival = max(curr, stop.plannedArrival ?? 0)
                    result[i].stops[j].arrival = arrival
                    
                    let baseDwell = (stop.isSkipped ? 0 : stop.minDwell + stop.extraDwell) * 60.0
                    let earliestDeparture = arrival + baseDwell
                    
                    // Respect plannedDeparture (as a minimum)
                    let dep = max(earliestDeparture, stop.plannedDeparture ?? 0)
                    result[i].stops[j].departure = (j < result[i].stops.count - 1) ? dep : nil
                    curr = dep
                }
            }
        }
        return result
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
    
    private func mutate(chromosome: inout Chromosome, nodes: [Node], contextTrains: [LiteTrain], allowedTracks: [UUID: [Set<String>]], rate: Double) {
        let conflictingIndices = chromosome.genes.indices.filter { i in 
            chromosome.conflictingTrainIds.contains(chromosome.genes[i].trainId) 
        }
        let targets = conflictingIndices.isEmpty ? Array(chromosome.genes.indices) : conflictingIndices
        
        for i in targets {
            let trainId = chromosome.genes[i].trainId
            let isConflicting = chromosome.conflictingTrainIds.contains(trainId)
            let mutationChance = isConflicting ? rate * 2.5 : rate * 0.3
            
            if Double.random(in: 0...1) < mutationChance {
                let r = Double.random(in: 0...1)
                
                if isConflicting, let locs = chromosome.conflictLocations[trainId], !locs.isEmpty {
                    let targetLoc = locs.randomElement() ?? ""
                    if targetLoc.contains("STATION") || targetLoc.contains("TRACK") || targetLoc.contains("ROUTING") {
                        let sid = targetLoc.components(separatedBy: "::").count > 1 ? targetLoc.components(separatedBy: "::")[1] : ""
                        if let stopIdx = contextTrains[i].stops.firstIndex(where: { $0.stationId == sid }) {
                            // PIGNOLO: Respect Manual Tracks
                            if contextTrains[i].stops[stopIdx].isManualTrack { continue }
                            
                            let allowed = allowedTracks[trainId]?[stopIdx] ?? ["1"]
                            if allowed.count > 1 {
                                let current = chromosome.genes[i].stopTracks[stopIdx]
                                let others = allowed.filter { $0 != current }
                                chromosome.genes[i].stopTracks[stopIdx] = others.randomElement() ?? current
                                continue
                            }
                        }
                    } else if targetLoc.hasPrefix("SEGMENT::") {
                        let seg = targetLoc.replacingOccurrences(of: "SEGMENT::", with: "")
                        if let stopIdx = contextTrains[i].stops.firstIndex(where: { seg.contains($0.stationId) }) {
                            let current = chromosome.genes[i].stopDwellOffsets[stopIdx]
                            chromosome.genes[i].stopDwellOffsets[stopIdx] = min(15.0, current + Double.random(in: 1.0...3.0))
                            continue
                        }
                    }
                }
                
                if r < 0.4 {
                    chromosome.genes[i].departureOffset += Double.random(in: -300...300)
                } else if r < 0.7 {
                    let j = Int.random(in: 0..<chromosome.genes[i].stopDwellOffsets.count)
                    // PIGNOLO ELASTIC: Allow reduction down to 2 min (negative offset)
                    chromosome.genes[i].stopDwellOffsets[j] = max(-5.0, min(15.0, chromosome.genes[i].stopDwellOffsets[j] + Double.random(in: -1...2)))
                } else {
                    let j = Int.random(in: 0..<chromosome.genes[i].stopTracks.count)
                    // PIGNOLO: Respect Manual Tracks
                    if contextTrains[i].stops[j].isManualTrack { continue }
                    
                    let allowed = allowedTracks[trainId]?[j] ?? ["1"]
                    chromosome.genes[i].stopTracks[j] = allowed.randomElement() ?? "1"
                }
            }
        }
    }
}
