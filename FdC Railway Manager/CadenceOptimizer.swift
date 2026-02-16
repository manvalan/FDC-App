import Foundation
import Combine

/// Algoritmo Genetico per trovare la finestra di partenza ideale per una linea cadenzata.
class CadenceOptimizer: ObservableObject {
    @Published var isRunning = false
    @Published var progress: Double = 0.0
    @Published var bestOffset: Double = 0.0 // in minuti
    @Published var fitness: Double = Double.infinity
    
    private let conflictManager = ConflictManager()
    
    struct CadenceChromosome {
        var offsetMinutes: Double
        var fitness: Double = 0.0
    }
    
    /// Propone l'offset migliore (finestra) per una linea cadenzata.
    /// - Parameters:
    ///   - line: La linea da cadenzare
    ///   - frequency: Frequenza in minuti
    ///   - existingTrains: Traffico reale già presente
    ///   - network: La rete ferroviaria
    @MainActor
    func proposeIdealWindow(for line: RailwayLine, frequency: Double, existingTrains: [Train], network: NetworkModel) async -> Double {
        self.isRunning = true
        self.progress = 0.0
        
        let populationSize = 20
        let generations = 25
        
        var population: [CadenceChromosome] = (0..<populationSize).map { _ in
            CadenceChromosome(offsetMinutes: Double.random(in: 0..<frequency))
        }
        
        // Aggiungiamo il minuto 0 e il minuto frequenza/2 come punti di partenza forti
        population[0].offsetMinutes = 0
        population[1].offsetMinutes = frequency / 2
        
        for gen in 0..<generations {
            await Task.yield()
            
            // Valutazione parallela
            for i in population.indices {
                population[i].fitness = await evaluateCadence(
                    offset: population[i].offsetMinutes,
                    line: line,
                    frequency: frequency,
                    existingTrains: existingTrains,
                    nodes: network.nodes,
                    edges: network.edges
                )
            }
            
            population.sort { $0.fitness < $1.fitness }
            
            self.bestOffset = population[0].offsetMinutes
            self.fitness = population[0].fitness
            self.progress = Double(gen) / Double(generations)
            
            if self.fitness == 0 { break }
            
            // Breeding: Elitismo + Tournament Selection
            var nextGen = Array(population.prefix(5))  // Mantieni i 5 migliori
            while nextGen.count < populationSize {
                // Tournament selection per entrambi i genitori
                let p1 = tournamentSelect(from: population, tournamentSize: 3)
                let p2 = tournamentSelect(from: population, tournamentSize: 3)
                
                // Crossover: media pesata verso il migliore
                let betterParent = p1.fitness < p2.fitness ? p1 : p2
                let weight = Double.random(in: 0.3...0.7)
                var child = CadenceChromosome(
                    offsetMinutes: betterParent.offsetMinutes * weight + 
                                   (p1.fitness < p2.fitness ? p2 : p1).offsetMinutes * (1.0 - weight)
                )
                
                // Mutazione con intensità decrescente
                let mutationRate = 0.3 * (1.0 - Double(gen) / Double(generations))  // Diminuisce col tempo
                if Double.random(in: 0...1) < mutationRate {
                    let mutationStrength = Double.random(in: -5.0...5.0)
                    child.offsetMinutes += mutationStrength
                    child.offsetMinutes = (child.offsetMinutes + frequency).truncatingRemainder(dividingBy: frequency)
                }
                nextGen.append(child)
            }
            population = nextGen
        }
        
        self.isRunning = false
        self.progress = 1.0
        return self.bestOffset
    }
    
    /// Tournament selection: seleziona il migliore tra N candidati casuali
    private func tournamentSelect(from population: [CadenceChromosome], tournamentSize: Int) -> CadenceChromosome {
        var best = population.randomElement()!
        for _ in 1..<tournamentSize {
            let candidate = population.randomElement()!
            if candidate.fitness < best.fitness {
                best = candidate
            }
        }
        return best
    }
    
    private func evaluateCadence(offset: Double, line: RailwayLine, frequency: Double, existingTrains: [Train], nodes: [Node], edges: [Edge]) async -> Double {
        // Simuliamo una serie di treni durante la giornata (es. 10 treni campioni)
        var testTrains: [Train] = []
        let baseDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(6 * 3600) // Start at 06:00
        
        for i in 0..<8 { // 8 treni di prova per coprire varie fasce orarie
            let departure = baseDate.addingTimeInterval((Double(i) * frequency + offset) * 60)
            
            // Calcola il numero corretto del treno
            let trainNumber = (line.numberPrefix ?? 0) * 100 + i
            
            // Genera il nome corretto
            let trainName: String
            if let prefix = line.codePrefix, let code = line.numberPrefix {
                trainName = "\(prefix)\(code) \(trainNumber)"
            } else {
                trainName = "\(trainNumber)"
            }
            
            // Usa parametri realistici basati sul tipo di treno
            let trainCategory = TrainCategory.regional // Default per cadenze
            
            // Parametri fisici tipici per categoria
            let (acceleration, deceleration): (Double, Double) = {
                switch trainCategory {
                case .highSpeed: return (0.6, 0.8)
                case .direct: return (0.5, 0.7)
                case .regional: return (0.5, 0.7)
                case .freight: return (0.2, 0.4)
                case .support: return (0.3, 0.5)
                }
            }()
            
            let train = Train(
                id: UUID(),
                number: trainNumber,
                name: trainName,
                type: line.codePrefix ?? trainCategory.rawValue,
                lineId: line.id,
                departureTime: departure,
                stops: line.stops,
                vehicleId: nil,
                maxSpeed: Double(trainCategory.defaultMaxSpeed),
                acceleration: acceleration,
                deceleration: deceleration,
                priority: trainCategory.defaultPriority
            )
            testTrains.append(train)
        }
        
        // Rinfreschiamo l'orario fisico per i treni di prova
        var localTrains = testTrains
        refreshSchedules(trains: &localTrains, nodes: nodes, edges: edges)
        
        // Calcoliamo i conflitti totali
        var dummyCache: [String: [Edge]]? = nil
        let conflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: localTrains + existingTrains, pathCache: &dummyCache).0
        
        // Penalità: Conflitti + Preferenza per orari cadenzati
        let conflictPenalty = Double(conflicts.count) * 500.0  // Ridotto da 1000 per permettere convergenza
        
        // Bonus per offset che sono multipli di 5, 15, o 30 minuti
        let roundnessBonus: Double
        if offset.truncatingRemainder(dividingBy: 30.0) < 0.5 {
            roundnessBonus = -20.0  // Perfetto: multiplo di 30
        } else if offset.truncatingRemainder(dividingBy: 15.0) < 0.5 {
            roundnessBonus = -10.0  // Buono: multiplo di 15
        } else if offset.truncatingRemainder(dividingBy: 5.0) < 0.5 {
            roundnessBonus = -5.0   // Accettabile: multiplo di 5
        } else {
            roundnessBonus = abs(offset - round(offset)) * 2.0  // Penalità per decimali strani
        }
        
        return max(0, conflictPenalty + roundnessBonus)
    }
    
    private func refreshSchedules(trains: inout [Train], nodes: [Node], edges: [Edge]) {
        // Logica semplificata di refresh schedule (simile a TrainManager)
        for i in trains.indices {
            guard let depTime = trains[i].departureTime else { continue }
            var currentTime = depTime
            
            for j in trains[i].stops.indices {
                let stop = trains[i].stops[j]
                if j == 0 {
                    trains[i].stops[j].arrival = nil
                    trains[i].stops[j].departure = currentTime
                } else {
                    let prevId = trains[i].stops[j-1].stationId
                    if let pathEdges = NetworkModel.findPathEdges(from: prevId, to: stop.stationId, nodes: nodes, edges: edges) {
                        let dist = pathEdges.reduce(0.0) { $0 + $1.distance }
                        let trackMaxSpeed = pathEdges.map { Double($0.maxSpeed) }.min() ?? 100.0
                        
                        // Usa la velocità minima tra tracciato e treno
                        let effectiveSpeed = min(trackMaxSpeed, trains[i].maxSpeed)
                        
                        let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: dist,
                            maxSpeedKmh: effectiveSpeed,
                            train: trains[i],
                            initialSpeedKmh: 0,
                            finalSpeedKmh: 0
                        )
                        currentTime = currentTime.addingTimeInterval(hours * 3600)
                        
                        trains[i].stops[j].arrival = currentTime
                        let dwell = Double(stop.minDwellTime) * 60
                        currentTime = currentTime.addingTimeInterval(dwell)
                        trains[i].stops[j].departure = (j < trains[i].stops.count - 1) ? currentTime : nil
                    }
                }
            }
        }
    }
}
