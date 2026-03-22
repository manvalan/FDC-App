import Foundation
import SwiftUI

extension ScheduleCreationView {
    
    func greedyOptimizeDepartureTimes(newTrains: [Train], existingTrains: [Train], network: RailwayNetwork) -> [Train] {
        var optimizedTrains: [Train] = []
        let cm = ConflictManager()
        let tempManager = TrainManager(network: network) // Reused instance
        
        print("🧠 [SMART OPTIMIZER] Avvio ottimizzazione per \(newTrains.count) treni...")
        
        for (index, train) in newTrains.enumerated() {
            var bestTrain = train
            var minConflicts = Int.max
            
            // 1. Definisci i candidati di offset da testare
// ... (rest of function body clipped for brevity, assuming replace_file_content handles large blocks correctly if I target specific lines. BUT I should better target specific small areas)
            
            // 1. Definisci i candidati di offset da testare
            // Includiamo 0 (originale) e poi cerchiamo shift intelligenti
            var candidateOffsets: Set<Int> = [0]
            
            // Analisi preliminare dei conflitti con orario base
            tempManager.trains = existingTrains + optimizedTrains + [train]
            tempManager.refreshSchedules()
            var dummyCache: [String: [Edge]]? = nil
            let initialConflicts = cm.calculateConflictsWithCapacities(nodes: network.nodes, edges: network.edges, trains: tempManager.trains, pathCache: &dummyCache).0
            
            if !initialConflicts.isEmpty {
                // Strategia SMART: Se ci scontriamo in linea, proviamo a spostare l'incrocio alla stazione precedente o successiva
                for conflict in initialConflicts where conflict.trainAId == train.id || conflict.trainBId == train.id {
                     // Se il conflitto è su una linea a binario singolo, cerchiamo di anticipare o posticipare
                     // Prova shift aggressivi per saltare il blocco
                     candidateOffsets.insert(5)
                     candidateOffsets.insert(-5)
                     candidateOffsets.insert(10)
                     candidateOffsets.insert(-10)
                     candidateOffsets.insert(15) // Max shift
                }
            } else {
                // Se non ci sono conflitti, confermiamolo subito!
                optimizedTrains.append(train)
                continue
            }
            
            // 2. Test candidati
            for offset in candidateOffsets.sorted(by: { abs($0) < abs($1) }) { // Prova prima i piccoli shift
                var testTrain = train
                if let originalDep = train.departureTime {
                    testTrain.departureTime = Calendar.current.date(byAdding: .minute, value: offset, to: originalDep)
                }
                
                tempManager.trains = existingTrains + optimizedTrains + [testTrain]
                tempManager.refreshSchedules()
                
                var dCache: [String: [Edge]]? = nil
                let conflicts = cm.calculateConflictsWithCapacities(nodes: network.nodes, edges: network.edges, trains: tempManager.trains, pathCache: &dCache).0
                let count = conflicts.count
                
                // Penalizziamo gli shift grandi se i conflitti sono uguali
                // Score = Conflitti * 100 + abs(offset)
                
                if count < minConflicts {
                    minConflicts = count
                    bestTrain = testTrain
                    if count == 0 { break } // Trovato slot perfetto
                }
            }
            
            optimizedTrains.append(bestTrain)
        } // Chiude il ciclo for (index, train)
        
        print("🧠 [SMART OPTIMIZER] Completato. Treni in uscita: \(optimizedTrains.count)/\(newTrains.count)")
        return optimizedTrains
    }


    func findDynamicCriticalStation(out: Train, ret: Train, network: RailwayNetwork, existingTrains: [Train]) -> String? {
        let tempManager = TrainManager(network: network)
        tempManager.trains = [out, ret] + existingTrains
        tempManager.refreshSchedules()
        
        let cm = ConflictManager()
        var dummyCache: [String: [Edge]]? = nil
        let conflicts = cm.calculateConflictsWithCapacities(nodes: network.nodes, edges: network.edges, trains: tempManager.trains, pathCache: &dummyCache).0
        
        let pairConflict = conflicts.first { c in
            let match1 = (c.trainAId == out.id && c.trainBId == ret.id)
            let match2 = (c.trainAId == ret.id && c.trainBId == out.id)
            return match1 || match2
        }
        
        if let conflict = pairConflict {
            if conflict.locationType == ScheduleConflict.LocationType.station {
                return conflict.locationId
            }
            
            let segmentNodes = conflict.locationId.replacingOccurrences(of: "LINE::", with: "").split(separator: "-").map(String.init)
            for nid in segmentNodes {
                // Assuming Node.NodeType.interchange
                if let node = network.nodes.first(where: { $0.id == nid }), node.type == Node.NodeType.interchange || (node.platforms ?? 1) > 1 {
                    return nid
                }
            }
            return segmentNodes.first
        }
        return nil
    }
}
