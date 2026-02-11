import Foundation
import Combine

class GeneticOptimizer: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var currentGeneration = 0
    @Published var bestFitness = Double.infinity
    @Published var conflictCount = 0
    
    // Configurazione parametri chiari
    private struct Config {
        let populationSize = 100
        let baseMutationRate = 0.38
        let stagnationThreshold = 25
        let maxMutationRate = 0.85
    }
    private let config = Config()
    
    @MainActor
    func optimize(newTrains: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], iterations: Int? = nil) async -> [Train] {
        prepareForOptimization()
        
        // 1. Pre-processing & Filtering
        let relevantFixedTrains = spatialFilter(newTrains: newTrains, existing: existingTrains, edges: edges)
        let allowedTracks = precalculateAllowedTracks(allTrains: newTrains + relevantFixedTrains, nodes: nodes)
        let paths = precalculatePaths(allTrains: newTrains + relevantFixedTrains, edges: edges)
        let transitTimes = precalculateTransitTimes(allTrains: newTrains + relevantFixedTrains, edges: edges, paths: paths)
        
        let liteFixed = relevantFixedTrains.map { ScheduleTransformer.convertToLite(train: $0) }
        let liteNew = newTrains.map { ScheduleTransformer.convertToLite(train: $0) }
        
        let capMgr = ConflictManager()
        let capacities = capMgr.getResourceCapacities(nodes: nodes, edges: edges)
        
        // 2. Setup Evaluator & Engine
        let evaluator = ScheduleEvaluator(
            stationCapacities: capacities.filter { $0.key.hasPrefix("STATION_GLOBAL") },
            segmentCapacities: capacities.filter { $0.key.hasPrefix("SEGMENT") },
            allowedTracks: allowedTracks,
            precalculatedPaths: paths
        )
        
        let engine = GeneticEngine(
            nodes: nodes,
            contextTrains: liteNew + liteFixed, 
            allowedTracks: allowedTracks
        )
        
        // 3. Initialize Population
        var population = initializePopulation(liteNew: liteNew, transitTimes: transitTimes, allowedTracks: allowedTracks)
        
        // 4. Optimization Loop
        let actualMaxGenerations = iterations ?? 300
        var state = (
            lastBestConflictCount: 999,
            stagnationGens: 0,
            mutationRate: config.baseMutationRate
        )
        
        for gen in 0..<actualMaxGenerations {
            if gen % 10 == 0 {
                await Task.yield()
                if Task.isCancelled { break }
            }
            
            // Parallel Evaluation
            population = await evaluatePopulation(population: population, liteNew: liteNew, liteFixed: liteFixed, evaluator: evaluator)
            population.sort { $0.fitness < $1.fitness }
            
            let best = population[0]
            updateUI(gen: gen, maxGen: actualMaxGenerations, best: best)
            
            if best.conflictingTrainIds.count == 0 && gen >= 8 { break }
            
            // Adaptive Mutation
            state = updateAdaptiveState(state: state, bestConflict: best.conflictingTrainIds.count)
            
            // Evolve
            population = evolvePopulation(population: population, engine: engine, mutationRate: state.mutationRate)
        }
        
        completeOptimization()
        
        // 5. Finalize & Reconstruction
        let finalLite = ScheduleTransformer.apply(chromosome: population[0], to: liteNew)
        let correctedLite = sanitizeTracks(lite: finalLite, constraints: allowedTracks)
        
        return ScheduleTransformer.reconstructTrains(lite: correctedLite, original: newTrains)
    }
    
    // MARK: - Private Helpers (Modular & Focused)
    
    private func prepareForOptimization() {
        self.isRunning = true
        self.progress = 0.0
        self.currentGeneration = 0
        self.bestFitness = Double.infinity
    }
    
    private func completeOptimization() {
        self.isRunning = false
        self.progress = 1.0
    }
    
    private func updateUI(gen: Int, maxGen: Int, best: Chromosome) {
        self.bestFitness = best.fitness
        self.progress = Double(gen) / Double(maxGen)
        self.conflictCount = best.conflictingTrainIds.count
        self.currentGeneration = gen
    }
    
    private func spatialFilter(newTrains: [Train], existing: [Train], edges: [Edge]) -> [Train] {
        let focusResources = Set(newTrains.flatMap { $0.getResourceKeys(edges: edges) })
        return existing.filter { !Set($0.getResourceKeys(edges: edges)).isDisjoint(with: focusResources) }
    }
    
    private func precalculateAllowedTracks(allTrains: [Train], nodes: [Node]) -> [UUID: [Set<String>]] {
        var results: [UUID: [Set<String>]] = [:]
        for train in allTrains {
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
            results[train.id] = stopConstraints
        }
        return results
    }
    
    private func precalculatePaths(allTrains: [Train], edges: [Edge]) -> [UUID: [[Edge]?]] {
        var results: [UUID: [[Edge]?]] = [:]
        for train in allTrains {
            var trainPaths: [[Edge]? ] = []
            var prevId = train.stops.first?.stationId ?? ""
            for j in train.stops.indices {
                if j == 0 { trainPaths.append(nil) }
                else {
                    let path = NetworkModel.findPathEdges(from: prevId, to: train.stops[j].stationId, nodes: [], edges: edges)
                    trainPaths.append(path)
                    prevId = train.stops[j].stationId
                }
            }
            results[train.id] = trainPaths
        }
        return results
    }
    
    private func precalculateTransitTimes(allTrains: [Train], edges: [Edge], paths: [UUID: [[Edge]?]]) -> [UUID: [Double]] {
        var results: [UUID: [Double]] = [:]
        for train in allTrains {
            var times: [Double] = []
            for j in train.stops.indices {
                if j == 0 { times.append(0) }
                else {
                    let path = paths[train.id]?[j]
                    let dist = path?.reduce(0.0) { $0 + $1.distance } ?? 0.0
                    let minSpeedLimit = path?.reduce(Double.infinity) { min($0, Double($1.maxSpeed)) } ?? 100.0
                    
                    if dist > 0 {
                        let vMax = min(Double(train.maxSpeed), minSpeedLimit) / 3.6
                        let distM = dist * 1000.0
                        let (a, d) = (train.acceleration, train.deceleration)
                        let t: Double
                        if (vMax * vMax / (2*a)) + (vMax * vMax / (2*d)) <= distM {
                            t = (vMax/a) + (distM - (vMax*vMax/(2*a)) - (vMax*vMax/(2*d))) / vMax + (vMax/d)
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
    
    private func initializePopulation(liteNew: [LiteTrain], transitTimes: [UUID: [Double]], allowedTracks: [UUID: [Set<String>]]) -> [Chromosome] {
        var pop: [Chromosome] = []
        // Identity
        pop.append(Chromosome(genes: liteNew.map { train in
            TrainGene(trainId: train.id, departureOffset: 0, 
                      stopDwellOffsets: train.stops.map { $0.extraDwell }, 
                      stopTracks: train.stops.map { $0.track }, 
                      legTransitTimes: transitTimes[train.id] ?? [])
        }))
        // Random
        for _ in 1..<config.populationSize {
            let genes = liteNew.map { train -> TrainGene in
                let tracks = train.stops.indices.map { j in allowedTracks[train.id]?[j].randomElement() ?? "1" }
                return TrainGene(trainId: train.id, 
                                 departureOffset: Double.random(in: -900...900), 
                                 stopDwellOffsets: train.stops.map { _ in Double.random(in: 0...5) }, 
                                 stopTracks: tracks, 
                                 legTransitTimes: transitTimes[train.id] ?? [])
            }
            pop.append(Chromosome(genes: genes))
        }
        return pop
    }
    
    private func evaluatePopulation(population: [Chromosome], liteNew: [LiteTrain], liteFixed: [LiteTrain], evaluator: ScheduleEvaluator) async -> [Chromosome] {
        var results = population
        await withTaskGroup(of: (Int, Double, Set<UUID>, [UUID: Set<String>]).self) { group in
            for i in population.indices {
                group.addTask {
                    let res = evaluator.evaluate(chromosome: population[i], candidateTrains: liteNew, fixedTrains: liteFixed)
                    return (i, res.0, res.1, res.2)
                }
            }
            for await r in group {
                results[r.0].fitness = r.1
                results[r.0].conflictingTrainIds = r.2
                results[r.0].conflictLocations = r.3
            }
        }
        return results
    }
    
    private func updateAdaptiveState(state: (lastBestConflictCount: Int, stagnationGens: Int, mutationRate: Double), bestConflict: Int) -> (lastBestConflictCount: Int, stagnationGens: Int, mutationRate: Double) {
        var newState = state
        if bestConflict < state.lastBestConflictCount {
            newState.lastBestConflictCount = bestConflict
            newState.stagnationGens = 0
            newState.mutationRate = config.baseMutationRate
        } else {
            newState.stagnationGens += 1
            if newState.stagnationGens > config.stagnationThreshold {
                newState.mutationRate = min(config.maxMutationRate, newState.mutationRate * 1.04)
            }
        }
        return newState
    }
    
    private func evolvePopulation(population: [Chromosome], engine: GeneticEngine, mutationRate: Double) -> [Chromosome] {
        var nextGen = Array(population.prefix(12)) // Elitismo
        while nextGen.count < config.populationSize {
            let p1 = engine.selectParent(from: population)
            let p2 = engine.selectParent(from: population)
            var child = engine.crossover(p1: p1, p2: p2)
            engine.mutate(chromosome: &child, rate: mutationRate)
            nextGen.append(child)
        }
        return nextGen
    }
    
    private func sanitizeTracks(lite: [LiteTrain], constraints: [UUID: [Set<String>]]) -> [LiteTrain] {
        var result = lite
        for i in result.indices {
            let tid = result[i].id
            guard let trainConstraints = constraints[tid] else { continue }
            for j in result[i].stops.indices {
                if result[i].stops[j].isManualTrack { continue }
                if !trainConstraints[j].contains(result[i].stops[j].track) {
                    result[i].stops[j].track = trainConstraints[j].first ?? "1"
                }
            }
        }
        return result
    }
}

// Estensione per ottenere le chiavi delle risorse
extension Train {
    func getResourceKeys(edges: [Edge]) -> [String] {
        var resources: [String] = []
        var prevId: String? = nil
        for stop in stops {
            resources.append("STATION::\(stop.stationId)")
            if let prev = prevId {
                let path = NetworkModel.findPathEdges(from: prev, to: stop.stationId, nodes: [], edges: edges) ?? []
                resources.append(contentsOf: path.map { "SEGMENT::\($0.canonicalKey)" })
            }
            prevId = stop.stationId
        }
        return resources
    }
}
