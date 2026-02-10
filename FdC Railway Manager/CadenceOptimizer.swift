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
            
            // Breeding
            var nextGen = Array(population.prefix(5))
            while nextGen.count < populationSize {
                let p1 = population.randomElement()!
                let p2 = population.randomElement()!
                var child = CadenceChromosome(offsetMinutes: (p1.offsetMinutes + p2.offsetMinutes) / 2.0)
                
                // Mutazione
                if Double.random(in: 0...1) < 0.3 {
                    child.offsetMinutes += Double.random(in: -2.0...2.0)
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
    
    private func evaluateCadence(offset: Double, line: RailwayLine, frequency: Double, existingTrains: [Train], nodes: [Node], edges: [Edge]) async -> Double {
        // Simuliamo una serie di treni durante la giornata (es. 10 treni campioni)
        var testTrains: [Train] = []
        let baseDate = Calendar.current.startOfDay(for: Date()).addingTimeInterval(6 * 3600) // Start at 06:00
        
        for i in 0..<8 { // 8 treni di prova per coprire varie fasce orarie
            let departure = baseDate.addingTimeInterval((Double(i) * frequency + offset) * 60)
            let train = Train(
                id: UUID(),
                number: (line.numberPrefix ?? 0) * 1000 + i,
                name: "\(line.name) \(i)",
                type: line.codePrefix ?? "REG",
                lineId: line.id,
                departureTime: departure,
                stops: line.stops,
                vehicleId: nil,
                maxSpeed: 140,
                acceleration: 0.5,
                deceleration: 0.5,
                priority: 5
            )
            testTrains.append(train)
        }
        
        // Rinfreschiamo l'orario fisico per i treni di prova
        var localTrains = testTrains
        refreshSchedules(trains: &localTrains, nodes: nodes, edges: edges)
        
        // Calcoliamo i conflitti totali
        var dummyCache: [String: [Edge]]? = nil
        let conflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: localTrains + existingTrains, pathCache: &dummyCache).0
        
        // Penalità: Conflitti + Deviazione (preferiamo offset arrotondati se possibile)
        let conflictPenalty = Double(conflicts.count) * 1000.0
        let roundnessPenalty = abs(offset - round(offset)) * 10.0
        
        return conflictPenalty + roundnessPenalty
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
                    if let pathEdges = NetworkModel.findPathEdges(from: prevId, to: stop.stationId, edges: edges) {
                        let dist = pathEdges.reduce(0.0) { $0 + $1.distance }
                        let speed = pathEdges.map { Double($0.maxSpeed) }.min() ?? 100.0
                        
                        let hours = FDCSchedulerEngine.calculateTravelTime(
                            distanceKm: dist,
                            maxSpeedKmh: speed,
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
