import Foundation
import SwiftUI
import Combine // Required for Publisher bridge

/// 🚂 **RailwayScheduleOptimizer**
///
/// Questa classe gestisce la pipeline completa di generazione e ottimizzazione degli orari ferroviari.
/// Segue un processo rigoroso a 7 step per garantire la massima stabilità e il minimo numero di conflitti
/// prima ancora di interpellare l'AI o l'utente.
///
/// **Pipeline Logic:**
/// 1. Ottimizzazione Orari Partenza (Shift Temporale)
/// 2. Generazione Orario Base
/// 3. Analisi Criticità (Hotspot Detection)
/// 4. Risoluzione Conflitti CTC
/// 5. Hybrid Cloud AI
/// 6. Genetic Algorithm Refinement
final class RailwayScheduleOptimizer {
    
    // Singleton pattern per accesso facile, ma può essere istanziato
    static let shared = RailwayScheduleOptimizer()
    
    private let conflictManager = ConflictManager()
    private let aiService = RailwayAIService.shared
    private let geneticOptimizer = GeneticOptimizer() // Assumendo che sia adattabile o stateless
    
    /// Esegue l'intera pipeline di ottimizzazione.
    /// - Parameters:
    ///   - newTrains: I treni appena generati (Andata + Ritorno)
    ///   - existingTrains: I treni già presenti nel sistema (immutabili)
    ///   - network: La rete ferroviaria
    ///   - useAI: Flag per abilitare l'AI Cloud
    /// - Returns: La lista di treni ottimizzati pronti per l'inserimento
    /// Esegue l'intera pipeline di ottimizzazione.
    /// - Parameters:
    ///   - newTrains: I treni appena generati (Andata + Ritorno)
    ///   - existingTrains: I treni già presenti nel sistema (immutabili)
    ///   - network: La rete ferroviaria
    ///   - useAI: Flag per abilitare l'AI Cloud
    ///   - geneticOptimizer: Opzionale. Se passato, viene usato questo oggetto (utile per aggiornare la UI progress).
    /// - Returns: La lista di treni ottimizzati pronti per l'inserimento
    func executePipeline(
        newTrains: [RailwayTrain],
        existingTrains: [RailwayTrain],
        nodes: [RailwayNode],
        edges: [Edge],
        useAI: Bool = true,
        useGA: Bool = true,
        geneticOptimizer: GeneticOptimizer? = nil,
        preferredTaktNodeId: String? = nil
    ) async -> [RailwayTrain] {
        if Task.isCancelled { 
            print("⚠️ [PIPELINE] Task cancellata all'avvio!")
            return newTrains 
        }
        var localPathCache: [String: [Edge]] = [:] 
        let hasTaktRequired = nodes.contains(where: { (node: RailwayNode) in node.taktMinutes != nil })
        
        logPipelineInit(newTrains: newTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, useAI: useAI, useGA: useGA)

        // --- STEP 1: Time Optimization ---
        var workingTrains = await runStep1_TimeOptimization(
            newTrains: newTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useGA: useGA, 
            hasTaktRequired: hasTaktRequired, 
            pathCache: &localPathCache
        )
        
        // --- STEP 2: Physical Refresh ---
        workingTrains = await runStep2_PhysicalRefresh(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            pathCache: &localPathCache
        )
        
        // --- STEP 3-5: Optimization & Takt Alignment ---
        workingTrains = await runStep3_5_Alignment(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            hasTaktRequired: hasTaktRequired, 
            preferredTaktNodeId: preferredTaktNodeId, 
            pathCache: &localPathCache
        )
        
        // --- STEP 6: AI Cloud Optimization ---
        workingTrains = await runStep6_AIOptimization(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useAI: useAI, 
            hasTaktRequired: hasTaktRequired, 
            pathCache: &localPathCache
        )
        
        // --- STEP 7: Genetic Refinement ---
        var finalTrains = await runStep7_GeneticRefinement(
            workingTrains: workingTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            useGA: useGA, 
            hasTaktRequired: hasTaktRequired, 
            pathCache: &localPathCache,
            geneticOptimizer: geneticOptimizer
        )
        
        // --- STEP 8: Final Verification & Reporting ---
        return await runStep8_FinalVerification(
            finalTrains: finalTrains, 
            existingTrains: existingTrains, 
            nodes: nodes, 
            edges: edges, 
            hasTaktRequired: hasTaktRequired, 
            pathCache: &localPathCache
        )
    }

    // MARK: - Pipeline Steps

    private func logPipelineInit(newTrains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], useAI: Bool, useGA: Bool) {
        print("\n🚀 [PIPELINE] AVVIO PIPELINE DI OTTIMIZZAZIONE (7 STEP) per \(newTrains.count) treni")
        print("   Input: \(newTrains.count) nuovi treni, \(existingTrains.count) esistenti")
        print("   Rete: \(nodes.count) nodi, \(edges.count) edges")
        print("   Flags: useAI=\(useAI), useGA=\(useGA)")
    }

    private func runStep1_TimeOptimization(
        newTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        useGA: Bool, 
        hasTaktRequired: Bool, 
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        if useGA && !hasTaktRequired {
            print("🕒 [STEP 1] Ottimizzazione Orari di Partenza...")
            try? await Task.yield()
            if Task.isCancelled { return newTrains }
            return optimizeDepartureTimes(newTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        } else if hasTaktRequired {
            print("🕒 [STEP 1] SKIP: Takt rilevato, manteniamo orari deterministici per precisione hub.")
        } else {
            print("🕒 [STEP 1] SKIP: Ottimizzazione Orari di Partenza disabilitata.")
        }
        return newTrains
    }

    private func runStep2_PhysicalRefresh(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        print("⚙️ [STEP 2] Calcolo Fisico Orari...")
        if Task.isCancelled { return workingTrains }
        return refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
    }

    private func runStep3_5_Alignment(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        hasTaktRequired: Bool, 
        preferredTaktNodeId: String?, 
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        let conflicts = detectConflicts(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        
        if !conflicts.isEmpty || hasTaktRequired {
            if !conflicts.isEmpty {
                print("   ⚠️ Rilevati \(conflicts.count) conflitti residui. Avvio Analisi Hotspot.")
                let hotspots = analyzeHotspots(conflicts: conflicts, nodes: nodes)
                let hotspotNames = hotspots.keys.sorted { hotspots[$0]! > hotspots[$1]! }.prefix(5)
                print("   📍 Hotspots identificati: \(hotspotNames.joined(separator: ", "))")
            } else {
                print("   ℹ️ Nessun conflitto rilevato, ma rilevati obiettivi Takt. Avvio ri-allineamento deterministico.")
            }
            
            if hasTaktRequired {
                print("🚦 [STEP 5] Generazione Orario Cadenzato (Parallel Pulse Scheduler)...")
                if Task.isCancelled { return workingTrains }
                
                let results = await generaOrarioCadenzato(
                    newTrains: workingTrains,
                    existingTrains: existingTrains,
                    nodes: nodes,
                    edges: edges,
                    preferredTaktNodeId: preferredTaktNodeId
                )
                print("   ✅ Orari cadenzati generati, preservati per evitare sovrascritture")
                return results
            } else {
                print("🚦 [STEP 5] SKIP: Nessun nodo Takt configurato.")
            }
        } else {
            print("   ✅ Nessun conflitto rilevato e nessun obiettivo Takt impostato. Skipping Step 3-5.")
        }
        return workingTrains
    }

    private func runStep6_AIOptimization(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        useAI: Bool, 
        hasTaktRequired: Bool, 
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        if !useAI {
            print("   ⏭️ AI Cloud disabilitata o non richiesta.")
            return workingTrains
        }

        print("🧠 [STEP 6] AI Cloud Optimization...")
        if Task.isCancelled { return workingTrains }
        
        let conflictsBeforeAI = detectConflicts(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache).count
        print("   🔍 Conflitti pre-AI: \(conflictsBeforeAI)")
        
        let preAITrains = workingTrains
        let aiResponse = await performCloudOptimization(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        
        guard let response = aiResponse, let resolutions = response.resolutions, !resolutions.isEmpty else {
            print("   ℹ️ L'AI non ha proposto risoluzioni o la chiamata è fallita.")
            return workingTrains
        }

        let avgConfidence = resolutions.compactMap { $0.confidence }.reduce(0.0, +) / Double(resolutions.count)
        let confidence = response.ml_confidence ?? (resolutions.isEmpty ? 0.0 : avgConfidence)
        print("   📥 Ricevute \(resolutions.count) risoluzioni dall'AI (Confidenza Media: \(Int(confidence * 100))%).")
        
        if confidence < 0.15 {
            print("   ⚠️ [WARNING] Confidenza AI troppo bassa (\(Int(confidence * 100))%). Soluzione scartata.")
            return workingTrains
        }

        var results = applyAIResolutions(workingTrains, resolutions: resolutions)
        if !hasTaktRequired {
            results = refreshPhysicalSchedules(results, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        }
        
        let conflictsAfterAI = detectConflicts(results, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache).count
        
        if conflictsAfterAI > conflictsBeforeAI + 2 {
            print("   ❌ [ROLLBACK] L'AI ha peggiorato lo scenario (\(conflictsBeforeAI) -> \(conflictsAfterAI)). Ripristino stato pre-AI.")
            return preAITrains
        } else {
            print("   ✅ Conflitti post-AI: \(conflictsAfterAI) (Variazione: \(conflictsAfterAI - conflictsBeforeAI))")
            return results
        }
    }

    private func runStep7_GeneticRefinement(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        useGA: Bool, 
        hasTaktRequired: Bool, 
        pathCache: inout [String: [Edge]],
        geneticOptimizer: GeneticOptimizer?
    ) async -> [RailwayTrain] {
        if useGA && !hasTaktRequired {
            print("🧬 [STEP 7] Genetic Algorithm Refinement...")
            if Task.isCancelled { return workingTrains }
            let ga = geneticOptimizer ?? self.geneticOptimizer
            
            return await ga.optimize(
                newTrains: workingTrains,
                existingTrains: existingTrains,
                nodes: nodes,
                edges: edges,
                iterations: 250
            )
        } else if hasTaktRequired {
            print("🧬 [STEP 7] SKIP: Genetic Refinement disabilitata per proteggere il cadenzamento Takt.")
        } else {
            print("🧬 [STEP 7] SKIP: Genetic Refinement disabilitata.")
        }
        return workingTrains
    }

    private func runStep8_FinalVerification(
        finalTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        hasTaktRequired: Bool, 
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        print("📊 [STEP 8] Verifica Finale...")
        let verifiedTrains: [RailwayTrain]
        if hasTaktRequired {
            print("   ℹ️ Takt attivo: salto refresh fisico per preservare orari cadenzati")
            verifiedTrains = finalTrains
        } else {
            verifiedTrains = refreshPhysicalSchedules(finalTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        }
        
        let finalConflicts = detectConflicts(verifiedTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        logFinalReport(conflicts: finalConflicts, totalTrains: verifiedTrains.count, nodes: nodes)
        
        print("🏁 [PIPELINE] Completata. Output: \(verifiedTrains.count) treni.\n")
        return verifiedTrains
    }

    private func logFinalReport(conflicts: [ScheduleConflict], totalTrains: Int, nodes: [RailwayNode]) {
        if conflicts.isEmpty {
            print("\n✨ 🏆 OTTIMIZZAZIONE PERFETTA! 0 Conflitti residui. 🏆 ✨")
        } else {
            print("\n⚠️ [RESULT] Ottimizzazione terminata con \(conflicts.count) conflitti residui.")
            let uniqueConflictingTrains = Set(conflicts.flatMap { [$0.trainAId, $0.trainBId] })
            print("   🚂 Treni coinvolti: \(uniqueConflictingTrains.count) (su \(totalTrains) totali)")
            
            let perStation = analyzeHotspots(conflicts: conflicts, nodes: nodes)
            let sortedStations = perStation.sorted { $0.value > $1.value }
            for (station, count) in sortedStations.prefix(5) {
                print("      • \(station): \(count)")
            }
            
            for (i, c) in conflicts.prefix(3).enumerated() {
                print("   ❌ Conflitto \(i+1): \(c.description) [\(c.timeStart.formatted(date: .omitted, time: .shortened)) - \(c.timeEnd.formatted(date: .omitted, time: .shortened))]")
            }
        }
    }
    
    // MARK: - Step 1: Time Optimization
    
    private func optimizeDepartureTimes(_ newTrains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) -> [RailwayTrain] {
        var optimized: [RailwayTrain] = []
        
        // PIGNOLO BOOST: 2-Phase Optimization (Coarse -> Fine)
        // Drastically reduces simulations from ~32 per train to ~10 per train
        
        for (idx, train) in newTrains.enumerated() {
            if Task.isCancelled { break }
            var bestTrain = train
            var minConflicts = Int.max
            var initialConflicts = 0
            
            // Baseline calculation
            var candidate = train
            refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
            let all = existingTrains + optimized + [candidate]
            var dummyCache: [String: [Edge]]? = pathCache
            initialConflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dummyCache).0.count
            if let updated = dummyCache { pathCache = updated }
            minConflicts = initialConflicts
            
            // IF base is perfect, skip optimization
            if minConflicts == 0 {
                optimized.append(bestTrain)
                continue
            }
            
            // Phase 1: Coarse Search (Steps of 10 mins)
            // Range: -60 to +60
            let coarseShifts = [-10, 10, -20, 20, -30, 30, -50, 50]
            var bestCoarseShift = 0
            
            for shift in coarseShifts {
                var candidate = train
                if let dep = train.departureTime {
                    candidate.departureTime = Calendar.current.date(byAdding: .minute, value: shift, to: dep)
                }
                
                refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
                let all = existingTrains + optimized + [candidate]
                var dc: [String: [Edge]]? = pathCache
                let count = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0.count
                if let u = dc { pathCache = u }
                
                if count < minConflicts {
                    minConflicts = count
                    bestTrain = candidate
                    bestCoarseShift = shift
                }
            }
            
            // Phase 2: Fine Refinement (Around best coarse shift)
            // Range: +/- 5 mins around the winner
            if minConflicts > 0 {
                 let fineShifts = [-5, -2, -1, 1, 2, 5]
                 for fine in fineShifts {
                     let totalShift = bestCoarseShift + fine
                     var candidate = train
                     if let dep = train.departureTime {
                         candidate.departureTime = Calendar.current.date(byAdding: .minute, value: totalShift, to: dep)
                     }
                     
                     refreshSingleTrainSchedule(&candidate, nodes: nodes, edges: edges, pathCache: &pathCache)
                     let all = existingTrains + optimized + [candidate]
                     var dc: [String: [Edge]]? = pathCache
                     let count = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0.count
                     if let u = dc { pathCache = u }
                     
                     if count < minConflicts {
                         minConflicts = count
                         bestTrain = candidate
                     }
                 }
            }
            
            optimized.append(bestTrain)
            
            let finalShift = minutesDiff(train, bestTrain)
            if finalShift != 0 || minConflicts != initialConflicts {
                print("   🔹 Treno \(idx+1)/\(newTrains.count): Shift \(finalShift)m (Conf: \(initialConflicts)->\(minConflicts))")
            }
        }
        
        return optimized
    }
    
    private func analyzeHotspots(conflicts: [ScheduleConflict], nodes: [RailwayNode]) -> [String: Int] {
        var heatmap: [String: Int] = [:]
        
        for conflict in conflicts {
            let resId = conflict.locationId
            let name = conflict.locationName
            
            if resId.hasPrefix("SEGMENT::") {
                let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                let parts = content.components(separatedBy: "--")
                for stationId in parts {
                    let stationName = nodes.first(where: { $0.id == stationId })?.name ?? stationId
                    heatmap[stationName, default: 0] += 1
                }
            } else if resId.hasPrefix("STATION::") {
                let stationId = resId.components(separatedBy: "::")[1]
                let stationName = nodes.first(where: { $0.id == stationId })?.name ?? stationId
                heatmap[stationName, default: 0] += 1
            } else {
                heatmap[name, default: 0] += 1
            }
        }
        return heatmap
    }
    
    // MARK: - Step 5: CTC Logic (Deterministic Crossing)
    
    // MARK: - Step 5: Swiss-AStar Logic (A* Space-Time Search)
    
    // MARK: - Takt Engine: Entry Point

    private func generaOrarioCadenzato(
        newTrains: [RailwayTrain],
        existingTrains: [RailwayTrain],
        nodes: [RailwayNode],
        edges: [Edge],
        preferredTaktNodeId: String? = nil
    ) async -> [RailwayTrain] {
        print("\n🌊🌊🌊 [TaktEngine] AVVIO GENERAZIONE ORARIO CADENZATO 🌊🌊🌊")
        guard let taktNode = resolveTaktNode(from: nodes, preferredId: preferredTaktNodeId) else {
            print("⚠️ Nessun nodo Takt trovato, ritorno treni originali")
            return newTrains
        }
        let taktMinute = taktNode.taktMinutes!
        print("📍 Nodo Takt: \(taktNode.name ?? taktNode.id) al minuto :\(taktMinute)")

        let networkContext = NetworkModel(nodes: nodes, edges: edges)
        let core = RailSchedulerCore(network: networkContext,
                                     occupancies: RailSchedulerCore.extractOccupancies(from: existingTrains, network: networkContext))
        var workingTrains = resetDwellTimes(newTrains)
        var trainsGrouped = groupTrainsByDirection(workingTrains, taktNodeId: taktNode.id)
        print("   📋 Trovati \(trainsGrouped.count) gruppi di treni (direzioni)")

        // Passo 1: calcola taktBaseTime condiviso per ciclo e blocca l'hub
        let cycleBaseTimes = buildCycleBaseTimes(from: workingTrains, taktNode: taktNode)
        lockHubTimesGlobally(groups: &trainsGrouped, taktNode: taktNode, cycleBaseTimes: cycleBaseTimes)

        // Passi 2+3: propaga per ogni gruppo
        var allResults: [Train] = []
        for groupIdx in 0..<trainsGrouped.count {
            if Task.isCancelled { break }
            var group = trainsGrouped[groupIdx]
            let sequence = group[0].stops.map { $0.stationId }
            guard let taktIdx = sequence.firstIndex(of: taktNode.id) else { continue }
            print("\n🚂 Gruppo \(groupIdx + 1): \(group.count) treni – \(sequence.first ?? "?") → \(sequence.last ?? "?")")
            propagateBackward(group: &group, taktIdx: taktIdx, sequence: sequence, nodes: nodes, edges: edges, core: core)
            propagateForward(group: &group, taktIdx: taktIdx, sequence: sequence, nodes: nodes, edges: edges, core: core)
            for i in group.indices {
                group[i].departureTime = group[i].stops.first?.departure ?? group[i].stops.first?.arrival
            }
            allResults.append(contentsOf: group)
        }
        print("\n🏁 [TaktEngine] Completata generazione per \(allResults.count) treni")
        return allResults
    }

    // MARK: - Takt Engine: Helpers

    private func resolveTaktNode(from nodes: [RailwayNode], preferredId: String?) -> Node? {
        if let id = preferredId, !id.isEmpty {
            let node = nodes.first(where: { $0.id == id && $0.taktMinutes != nil })
            if node == nil { print("⚠️ Nodo Takt specificato '\(id)' non trovato o senza taktMinutes") }
            return node
        }
        return nodes.first(where: { $0.taktMinutes != nil })
    }

    private func resetDwellTimes(_ trains: [Train]) -> [Train] {
        var result = trains
        for i in result.indices {
            for j in result[i].stops.indices { result[i].stops[j].extraDwellTime = 0 }
        }
        return result
    }

    private func groupTrainsByDirection(_ trains: [Train], taktNodeId: String) -> [[Train]] {
        var groups: [[Train]] = []
        for train in trains {
            let seq = train.stops.map { $0.stationId }
            guard seq.contains(taktNodeId) else { continue }
            if let idx = groups.firstIndex(where: { $0.first?.stops.map { $0.stationId } == seq }) {
                groups[idx].append(train)
            } else {
                groups.append([train])
            }
        }
        return groups
    }

    private func buildCycleBaseTimes(from trains: [Train], taktNode: Node) -> [Date: Date] {
        let calendar = Calendar.current
        let taktMinute = taktNode.taktMinutes!
        
        // Per Taktfahrplan: ignora gli orari di partenza dell'utente e usa solo il taktMinute
        // Crea taktBaseTime basati SOLO sul minuto Takt, partendo dalla prima partenza
        guard let firstDep = trains.compactMap({ $0.departureTime }).sorted().first else {
            return [:]
        }
        
        // Calcola il primo taktBaseTime al minuto Takt dell'ora più vicina
        var base = calendar.date(bySetting: .minute, value: taktMinute, of: firstDep) ?? firstDep
        if let secondComp = calendar.dateComponents([.second], from: base).second, secondComp != 0 {
            base = calendar.date(bySetting: .second, value: 0, of: base) ?? base
        }
        // Se il base è prima della partenza, aggiungi un'ora
        if base < firstDep { 
            base = calendar.date(byAdding: .hour, value: 1, to: base) ?? base 
        }
        
        // Raggruppa i treni per orario di partenza (con tolleranza di 2 minuti)
        var departures: [Date] = []
        for train in trains {
            guard let dep = train.departureTime else { continue }
            let rounded = calendar.date(bySetting: .second, value: 0, of: dep) ?? dep
            if !departures.contains(where: { abs($0.timeIntervalSince(rounded)) < 120 }) { 
                departures.append(rounded) 
            }
        }
        departures.sort()
        
        // Assegna un taktBaseTime a ciascun gruppo di partenze
        var result: [Date: Date] = [:]
        var currentBase = base
        for cycleDep in departures {
            // Avanza currentBase fino a superare cycleDep
            while currentBase < cycleDep {
                currentBase = calendar.date(byAdding: .hour, value: 2, to: currentBase) ?? currentBase  // +120 min
            }
            result[cycleDep] = currentBase
            print("   🕐 Ciclo \(formatTime(cycleDep)): taktBase = \(formatTime(currentBase))")
        }
        
        return result
    }

    private func lockHubTimesGlobally(groups: inout [[Train]], taktNode: Node, cycleBaseTimes: [Date: Date]) {
        let taktMinute = taktNode.taktMinutes!
        let calendar = Calendar.current
        for gIdx in 0..<groups.count {
            let seq = groups[gIdx][0].stops.map { $0.stationId }
            guard let tIdx = seq.firstIndex(of: taktNode.id) else { continue }
            for i in groups[gIdx].indices {
                let train = groups[gIdx][i]
                guard let dep = train.departureTime,
                      let base = cycleBaseTimes.first(where: { abs($0.key.timeIntervalSince(dep)) < 120 })?.value
                else { continue }
                let (arr, dep2) = taktHubTimes(train: train, base: base, calendar: calendar)
                groups[gIdx][i].stops[tIdx].arrival = arr
                groups[gIdx][i].stops[tIdx].departure = (tIdx < groups[gIdx][i].stops.count - 1) ? dep2 : nil
                print("   🚆 [\(train.isMainTrain ? "MAIN" : "SEC ")] \(train.name): Hub :\(taktMinute) | Arr \(formatTime(arr)) Dep \(formatTime(dep2))")
            }
        }
    }

    /// Ritorna (arrivo, partenza) all'hub takt per un treno.
    /// Per Taktfahrplan 120 min: i treni si incrociano con offset simmetrici
    /// T1 arriva 2-3 min prima, T2 arriva 3 min prima ma parte dopo
    private func taktHubTimes(train: Train, base: Date, calendar: Calendar) -> (Date, Date) {
        if train.isMainTrain {
            let isT1 = (train.number ?? 0) % 2 == 1
            // T1 (dispari): arriva -2, parte +1 → crossing window di 3 minuti
            // T2 (pari):   arriva -3, parte +2 → crossing window di 5 minuti
            // Questo permette l'incrocio simmetrico
            let arr = calendar.date(byAdding: .minute, value: isT1 ? -2 : -3, to: base) ?? base
            let dep = calendar.date(byAdding: .minute, value: isT1 ?  1 :  2, to: base) ?? base
            return (arr, dep)
        } else {
            // Treni non principali: ≥10 min di buffer prima/dopo il minuto takt
            let arr = calendar.date(byAdding: .minute, value: -10, to: base) ?? base
            let dep = calendar.date(byAdding: .minute, value:  10, to: base) ?? base
            return (arr, dep)
        }
    }

    private func propagateBackward(
        group: inout [Train], taktIdx: Int, sequence: [String],
        nodes: [RailwayNode], edges: [Edge], core: RailSchedulerCore
    ) {
        guard taktIdx > 0 else { return }
        print("\n⬅️ [PASSO 2] Propagazione INDIETRO da Takt verso origine...")
        for dist in 1...taktIdx {
            let curIdx = taktIdx - dist
            let nxtIdx = curIdx + 1
            let staCur = sequence[curIdx]
            let staNxt = sequence[nxtIdx]
            guard let edge = edges.first(where: {
                ($0.from == staCur && $0.to == staNxt) || ($0.from == staNxt && $0.to == staCur)
            }) else { continue }
            print("   📍 Stazione \(curIdx): \(staCur)")
            for i in group.indices {
                let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(
                    from: staCur, to: staNxt, train: group[i], nodes: nodes, edges: edges,
                    isStarting: !group[i].stops[curIdx].isSkipped, isStopping: !group[i].stops[nxtIdx].isSkipped)
                let nxtDep = group[i].stops[nxtIdx].departure ?? group[i].stops[nxtIdx].arrival!
                let propDep = nxtDep.addingTimeInterval(-tt)
                let dwell = Double((group[i].stops[curIdx].isSkipped ? 0 : group[i].stops[curIdx].minDwellTime) * 60)
                var propArr = propDep.addingTimeInterval(-dwell)
                var extra = 0.0
                for _ in 0..<10 {
                    if core.isTrattaLibera(edge: edge, tInizio: propDep, tFine: nxtDep, verso: staNxt)
                        && core.isStazioneLibera(stazioneId: staCur, at: propArr) { break }
                    extra += 2; propArr = propArr.addingTimeInterval(-120)
                }
                group[i].stops[curIdx].arrival = (curIdx > 0) ? propArr : nil
                group[i].stops[curIdx].departure = propDep
                group[i].stops[curIdx].extraDwellTime = extra
                if extra > 0 { print("      ⏳ \(group[i].name): +\(Int(extra))m") }
                let s1 = staCur < staNxt ? staCur : staNxt; let s2 = staCur < staNxt ? staNxt : staCur
                core.addOccupancies([OccupazioneTratta(resId: "SEGMENT::\(s1)--\(s2)", intervallo: propDep...nxtDep, direzione: staNxt)])
                if dwell > 0 || extra > 0 {
                    core.addOccupancies([OccupazioneTratta(resId: "STATION_GLOBAL::\(staCur)", intervallo: propArr...propDep, direzione: "STAY")])
                }
            }
        }
    }

    private func propagateForward(
        group: inout [Train], taktIdx: Int, sequence: [String],
        nodes: [RailwayNode], edges: [Edge], core: RailSchedulerCore
    ) {
        guard taktIdx < sequence.count - 1 else { return }
        print("\n➡️ [PASSO 3] Propagazione AVANTI da Takt verso destinazione...")
        for dist in 1..<(sequence.count - taktIdx) {
            let curIdx = taktIdx + dist
            let prvIdx = curIdx - 1
            let staPrv = sequence[prvIdx]
            let staCur = sequence[curIdx]
            guard let edge = edges.first(where: {
                ($0.from == staPrv && $0.to == staCur) || ($0.from == staCur && $0.to == staPrv)
            }) else { continue }
            print("   📍 Stazione \(curIdx): \(staCur)")
            for i in group.indices {
                let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(
                    from: staPrv, to: staCur, train: group[i], nodes: nodes, edges: edges,
                    isStarting: !group[i].stops[prvIdx].isSkipped, isStopping: !group[i].stops[curIdx].isSkipped)
                let prvDep = group[i].stops[prvIdx].departure ?? group[i].stops[prvIdx].arrival!
                let propArr = prvDep.addingTimeInterval(tt)
                let dwell = Double((group[i].stops[curIdx].isSkipped ? 0 : group[i].stops[curIdx].minDwellTime) * 60)
                let propDep = propArr.addingTimeInterval(dwell)
                var extra = 0.0
                for _ in 0..<10 {
                    if core.isTrattaLibera(edge: edge, tInizio: prvDep.addingTimeInterval(extra * 60), tFine: propArr.addingTimeInterval(extra * 60), verso: staCur)
                        && core.isStazioneLibera(stazioneId: staCur, at: propArr.addingTimeInterval(extra * 60)) { break }
                    extra += 2
                }
                if extra > 0 {
                    group[i].stops[prvIdx].extraDwellTime = (group[i].stops[prvIdx].extraDwellTime ?? 0) + extra
                    group[i].stops[prvIdx].departure = group[i].stops[prvIdx].departure?.addingTimeInterval(extra * 60)
                    print("      ⏳ \(group[i].name): +\(Int(extra))m @ \(staPrv)")
                }
                let adjPrvDep = prvDep.addingTimeInterval(extra * 60)
                let adjArr    = propArr.addingTimeInterval(extra * 60)
                let adjDep    = propDep.addingTimeInterval(extra * 60)
                group[i].stops[curIdx].arrival   = adjArr
                group[i].stops[curIdx].departure = (curIdx < sequence.count - 1) ? adjDep : nil
                let s1 = staPrv < staCur ? staPrv : staCur; let s2 = staPrv < staCur ? staCur : staPrv
                core.addOccupancies([OccupazioneTratta(resId: "SEGMENT::\(s1)--\(s2)", intervallo: adjPrvDep...adjArr, direzione: staCur)])
                if dwell > 0 {
                    core.addOccupancies([OccupazioneTratta(resId: "STATION_GLOBAL::\(staCur)", intervallo: adjArr...adjDep, direzione: "STAY")])
                }
            }
        }
    }

    
    private enum ExpansionDirection { case forward, backward }
    
    private struct PlanningCursor {
        var train: Train
        var sequence: [String]
        var hubIndex: Int
        var forwardTime: Date
        var backwardTime: Date
        var forwardStops: [RelationStop] = []
        var backwardStops: [RelationStop] = []
        var anchorStop: RelationStop?
        
        var forwardFinished: Bool { (hubIndex + forwardStops.count) >= sequence.count - 1 }
        var backwardFinished: Bool { (hubIndex - backwardStops.count) <= 0 }
    }
    
    private func expandCursorOneStep(_ cursor: inout PlanningCursor, direction: ExpansionDirection, core: RailSchedulerCore, network: NetworkModel) {
        let isForward = direction == .forward
        let idxCur = isForward ? (cursor.hubIndex + cursor.forwardStops.count) : (cursor.hubIndex - cursor.backwardStops.count)
        let idxNext = isForward ? idxCur + 1 : idxCur - 1
        
        guard idxNext >= 0 && idxNext < cursor.sequence.count else { return }
        
        let idCur = cursor.sequence[idxCur]
        let idNext = cursor.sequence[idxNext]
        let curTime = isForward ? cursor.forwardTime : cursor.backwardTime
        
        let templateNext = cursor.train.stops.first(where: { $0.stationId == idNext })
        let templateCur = cursor.train.stops.first(where: { $0.stationId == idCur })
        let isSkipped = templateNext?.isSkipped ?? false
        let prevSkipped = templateCur?.isSkipped ?? false
        
        let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: isForward ? idCur : idNext, to: isForward ? idNext : idCur, train: cursor.train, nodes: network.nodes, edges: network.edges, isStarting: isForward ? !prevSkipped : !isSkipped, isStopping: isForward ? !isSkipped : !prevSkipped)
        
        guard let edge = network.edges.first(where: { ($0.from == idCur && $0.to == idNext) || ($0.from == idNext && $0.to == idCur) }) else { return }
        
        let potArr = isForward ? curTime.addingTimeInterval(tt) : curTime.addingTimeInterval(-tt)
        let tStart = isForward ? curTime : potArr
        let tEnd = isForward ? potArr : curTime
        
        let trackOk = core.isTrattaLibera(edge: edge, tInizio: tStart, tFine: tEnd, verso: isForward ? idNext : idCur)
        let stationOk = core.isStazioneLibera(stazioneId: idNext, at: isForward ? potArr : tStart)
        
        if trackOk && stationOk {
            let nodeType = network.nodes.first(where: { $0.id == idNext })?.type ?? .station
        let actuallySkipped = isSkipped || nodeType == .junction
        let dwellMin = actuallySkipped ? 0 : (templateNext?.minDwellTime ?? 2)
        let dwellSec = Double(dwellMin) * 60.0
            
            var newStop = RelationStop(stationId: idNext, minDwellTime: dwellMin, isSkipped: actuallySkipped, arrival: isForward ? potArr : nil, departure: isForward ? nil : potArr)
            
            if isForward {
                newStop.arrival = potArr
                newStop.departure = potArr.addingTimeInterval(dwellSec)
                cursor.forwardStops.append(newStop)
                cursor.forwardTime = newStop.departure!
                print("   ✅ [FWD] \(cursor.train.name): \(idCur) -> \(idNext) (TT: \(Int(tt))s) | Arr: \(formatTimeWithSeconds(potArr)), Dep: \(formatTimeWithSeconds(newStop.departure!))")
            } else {
                newStop.departure = curTime
                newStop.arrival = potArr.addingTimeInterval(-dwellSec)
                cursor.backwardStops.append(newStop)
                cursor.backwardTime = newStop.arrival!
                print("   ✅ [BKW] \(cursor.train.name): \(idCur) <- \(idNext) (TT: \(Int(tt))s) | Dep: \(formatTimeWithSeconds(curTime)), Arr: \(formatTimeWithSeconds(newStop.arrival!))")
            }
            
            // Occupazioni
            let s1 = idCur < idNext ? idCur : idNext
            let s2 = idCur < idNext ? idNext : idCur
            core.addOccupancies([OccupazioneTratta(resId: "SEGMENT::\(s1)--\(s2)", intervallo: tStart...tEnd, direzione: isForward ? idNext : idCur)])
            let tA = isForward ? potArr : newStop.arrival!
            let tD = isForward ? newStop.departure! : curTime
            core.addOccupancies([OccupazioneTratta(resId: "STATION_GLOBAL::\(idNext)", intervallo: tA...tD, direzione: "STAY")])
        } else {
            let reason = !trackOk ? "Tratta Occupata" : "Stazione Piena"
            print("   ❌ [WAIT] \(cursor.train.name): Conflitto verso \(idNext) (\(reason)).")
            if isForward {
                shiftForward(&cursor, delta: 120) // PASSO 3: +2 min
            } else {
                shiftBackward(&cursor, delta: 120) // PASSO 2: +2 min
            }
        }
    }
    
    private func shiftForward(_ cursor: inout PlanningCursor, delta: TimeInterval) {
        var target: Int? = nil 
        if cursor.forwardStops.isEmpty { target = -1 }
        else {
            for i in (0..<cursor.forwardStops.count).reversed() {
                let sId = cursor.forwardStops[i].stationId
                let isJunction = cursor.train.stops.first(where: { $0.stationId == sId })?.isSkipped ?? false
                // Note: using isSkipped as a proxy for junctions here, but we could check nodes array if passed
                if !cursor.forwardStops[i].isSkipped && !isIdJunction(sId, nodes: []) { 
                    target = i; break 
                } 
            }
            if target == nil { target = -1 }
        }
        
        var stationName = ""
        if target == -1 {
            if var a = cursor.anchorStop {
                a.extraDwellTime = (a.extraDwellTime ?? 0) + (delta/60.0)
                a.departure = a.departure?.addingTimeInterval(delta)
                cursor.anchorStop = a
                stationName = a.stationId
            }
        } else if let idx = target {
            cursor.forwardStops[idx].extraDwellTime = (cursor.forwardStops[idx].extraDwellTime ?? 0) + (delta/60.0)
            cursor.forwardStops[idx].departure = cursor.forwardStops[idx].departure?.addingTimeInterval(delta)
            stationName = cursor.forwardStops[idx].stationId
        }
        
        print("      🕒 [SHIFT FWD] \(cursor.train.name): +\(Int(delta/60))m attesa a \(stationName)")
        
        let start = (target == -1) ? 0 : (target! + 1)
        for i in start..<cursor.forwardStops.count {
            cursor.forwardStops[i].arrival = cursor.forwardStops[i].arrival?.addingTimeInterval(delta)
            cursor.forwardStops[i].departure = cursor.forwardStops[i].departure?.addingTimeInterval(delta)
        }
        cursor.forwardTime = (cursor.forwardStops.last?.departure ?? cursor.anchorStop?.departure)!
    }

    private func shiftBackward(_ cursor: inout PlanningCursor, delta: TimeInterval) {
        var target: Int? = nil // -1 per hub, >=0 per backwardStops
        if cursor.backwardStops.isEmpty { target = -1 }
        else {
            for i in (0..<cursor.backwardStops.count).reversed() {
                let sId = cursor.backwardStops[i].stationId
                if !cursor.backwardStops[i].isSkipped && !isIdJunction(sId, nodes: []) { 
                    target = i; break 
                }
            }
            if target == nil { target = -1 }
        }
        
        var stationName = ""
        if target == -1 {
            if var a = cursor.anchorStop {
                a.extraDwellTime = (a.extraDwellTime ?? 0) + (delta/60.0)
                a.arrival = a.arrival?.addingTimeInterval(-delta)
                cursor.anchorStop = a
                stationName = a.stationId
            }
        } else if let idx = target {
            cursor.backwardStops[idx].extraDwellTime = (cursor.backwardStops[idx].extraDwellTime ?? 0) + (delta/60.0)
            cursor.backwardStops[idx].arrival = cursor.backwardStops[idx].arrival?.addingTimeInterval(-delta)
            stationName = cursor.backwardStops[idx].stationId
        }
        
        print("      🕒 [SHIFT BKW] \(cursor.train.name): +\(Int(delta/60))m attesa a \(stationName) (anticipo arrivo)")
        
        let start = (target == -1) ? 0 : (target! + 1)
        for i in start..<cursor.backwardStops.count {
            cursor.backwardStops[i].arrival = cursor.backwardStops[i].arrival?.addingTimeInterval(-delta)
            cursor.backwardStops[i].departure = cursor.backwardStops[i].departure?.addingTimeInterval(-delta)
        }
        cursor.backwardTime = (cursor.backwardStops.last?.arrival ?? cursor.anchorStop?.arrival)!
    }

    private func formatTimeWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func isIdJunction(_ id: String, nodes: [RailwayNode]) -> Bool {
        // Fallback check on ID prefix if nodes list isn't handy
        if id.hasPrefix("N-") || id.hasPrefix("NODE_") { return true }
        if let n = nodes.first(where: { $0.id == id }), n.type == .junction { return true }
        return false
    }
    
    /// Arrotonda una data ai 30 secondi più vicini per rendere l'orario più "pulito"
    private func roundToBusinessSeconds(_ date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        let rounded = (seconds / 30.0).rounded() * 30.0
        return Date(timeIntervalSince1970: rounded)
    }
    
    
    
    // MARK: - Helpers & Step 6 Integation
    
    private func performCloudOptimization(_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) async -> RailwayAIResponse? {
        var all = existingTrains + trains
        refreshMultipleSchedules(&all, nodes: nodes, edges: edges, pathCache: &pathCache)
        var dc: [String: [Edge]]? = pathCache
        let currentConflicts = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &dc).0
        if let u = dc { pathCache = u }
        
        if currentConflicts.isEmpty { return nil }
        
        // PIGNOLO PROTOCOL: Pass fixed train IDs to AI so it treats them as immutable constraints
        // Also specify activeAgentIds (the mobile ones) to enable Focus mode on the server
        let fixedIds = Set(existingTrains.map { $0.id })
        let activeIds = Set(trains.map { $0.id })
        
        let req = aiService.createRequest(
            nodes: nodes,
            edges: edges,
            trains: all, 
            fixedTrainIds: fixedIds, 
            activeAgentIds: activeIds,
            temporalObstacles: nil,
            conflicts: currentConflicts
        )
        
        do {
            // PIGNOLO PROTOCOL: Combine Publisher to Async/Await bridge
            for try await response in aiService.optimize(request: req).values {
                return response
            }
            return nil 
        } catch {
            print("⚠️ [PIPELINE] Errore chiamata AI: \(error)")
            return nil
        }
    }
    
    private func applyAIResolutions(_ trains: [Train], resolutions: [RailwayAIResolution]) -> [Train] {
        var updated = trains
        for res in resolutions {
            if let idx = updated.firstIndex(where: { aiService.getTrainUUID(optimizerId: res.train_id) == $0.id }) {
                // Applica Time Shift
                if let dep = updated[idx].departureTime {
                    updated[idx].departureTime = dep.addingTimeInterval(res.time_adjustment_min * 60)
                }
                
                if let delays = res.dwell_delays {
                    for (sIdx, delay) in delays.enumerated() where sIdx < updated[idx].stops.count {
                        if delay > 0 {
                            updated[idx].stops[sIdx].extraDwellTime += delay
                        }
                    }
                }
            }
        }
        return updated
    }
    
    private func refreshPhysicalSchedules(_ trains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) -> [RailwayTrain] {
        var all = existingTrains + trains
        refreshMultipleSchedules(&all, nodes: nodes, edges: edges, pathCache: &pathCache)
        
        let updatedIds = Set(trains.map { $0.id })
        return all.filter { updatedIds.contains($0.id) }
    }
    
    private func detectConflicts(_ trainSubset: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        var dc: [String: [Edge]]? = pathCache
        let res = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: allTrains, pathCache: &dc).0
        if let u = dc { pathCache = u }
        return res
    }
    
    // MARK: - Local Schedule Helpers (Replacing TrainManager)
    
    private func refreshMultipleSchedules(_ trains: inout [RailwayTrain], nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) {
        for i in trains.indices {
            refreshSingleTrainSchedule(&trains[i], nodes: nodes, edges: edges, pathCache: &pathCache)
        }
    }
    
    private func refreshSingleTrainSchedule(_ train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge], pathCache: inout [String: [Edge]]) {
        if let (hIdx, hNode) = findHubNode(in: train, nodes: nodes) {
            refreshTaktSchedule(train: &train, hIdx: hIdx, hNode: hNode, nodes: nodes, edges: edges)
        } else {
            refreshStandardSchedule(train: &train, nodes: nodes, edges: edges)
        }
    }

    private func findHubNode(in train: [RailwayTrain].Element, nodes: [RailwayNode]) -> (Int, RailwayNode)? {
        for i in train.stops.indices {
            if let node = nodes.first(where: { $0.id == train.stops[i].stationId && $0.taktMinutes != nil }) {
                return (i, node)
            }
        }
        return nil
    }
    private func refreshTaktSchedule(train: inout [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode, nodes: [RailwayNode], edges: [Edge]) {
        let (hArr, hDep) = calculateHubTimes(for: train, hIdx: hIdx, hNode: hNode)
        
        train.stops[hIdx].arrival = hArr
        train.stops[hIdx].departure = (hIdx < train.stops.count - 1) ? hDep : nil
        
        propagateBackward(from: hIdx, arrival: hArr, train: &train, nodes: nodes, edges: edges)
        propagateForward(from: hIdx, departure: hDep, train: &train, nodes: nodes, edges: edges)
        
        train.departureTime = train.stops.first?.departure ?? train.stops.first?.arrival
    }

    private func calculateHubTimes(for train: [RailwayTrain].Element, hIdx: Int, hNode: RailwayNode) -> (Date, Date) {
        let calendar = Calendar.current
        let takt = hNode.taktMinutes ?? 0
        let isT1 = (train.number ?? 0) % 2 == 0

        let referenceTime = train.stops[hIdx].arrival ?? train.departureTime ?? Date()
        let ttToHub = (train.stops[hIdx].arrival == nil) ? Double(hIdx) * 180.0 : 0
        let estArrAtHub = referenceTime.addingTimeInterval(ttToHub)
        
        var anchorBase = calendar.date(bySetting: .minute, value: takt, of: estArrAtHub) ?? estArrAtHub
        if anchorBase < estArrAtHub.addingTimeInterval(-1800) { anchorBase = calendar.date(byAdding: .hour, value: 1, to: anchorBase) ?? anchorBase }
        if anchorBase > estArrAtHub.addingTimeInterval(1800) { anchorBase = calendar.date(byAdding: .hour, value: -1, to: anchorBase) ?? anchorBase }

        var hArr: Date
        if isT1 {
            hArr = calendar.date(bySetting: .minute, value: (takt - 1 + 60) % 60, of: anchorBase) ?? anchorBase
        } else {
            hArr = calendar.date(bySetting: .minute, value: (takt - 2 + 60) % 60, of: anchorBase) ?? anchorBase
        }
        hArr = calendar.date(bySetting: .second, value: 0, of: hArr) ?? hArr
        let hDep = hArr.addingTimeInterval((isT1 ? 3 : 5) * 60)
        
        #if DEBUG
        print("🔄 [Refresh Takt] \(train.name) Hub: \(hNode.id) (#\(hIdx)) -> EstArrAtHub: \(formatTime(estArrAtHub)), Final Hub Dep: \(formatTime(hDep))")
        #endif

        return (hArr, hDep)
    }

    private func propagateBackward(from hIdx: Int, arrival: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard hIdx > 0 else { return }
        var nextArrivalAtTarget = arrival
        for j in (0..<hIdx).reversed() {
            let idNext = train.stops[j+1].stationId
            let idCur = train.stops[j].stationId
            let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: idCur, to: idNext, train: train, nodes: nodes, edges: edges, isStarting: j==0, isStopping: true)
            
            let depTime = nextArrivalAtTarget.addingTimeInterval(-tt)
            train.stops[j].departure = roundToBusinessSeconds(depTime)
            
            let dwell = max(120.0, (Double(train.stops[j].minDwellTime) + (train.stops[j].extraDwellTime ?? 0)) * 60.0)
            let arrTime = (train.stops[j].departure ?? depTime).addingTimeInterval(-dwell)
            train.stops[j].arrival = (j > 0) ? roundToBusinessSeconds(arrTime) : nil
            
            nextArrivalAtTarget = train.stops[j].arrival ?? (train.stops[j].departure!.addingTimeInterval(-60))
        }
    }

    private func propagateForward(from hIdx: Int, departure: Date, train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard hIdx < train.stops.count - 1 else { return }
        var currentDeparture = departure
        for j in (hIdx + 1)..<train.stops.count {
            let idPrev = train.stops[j-1].stationId
            let idCur = train.stops[j].stationId
            let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: idPrev, to: idCur, train: train, nodes: nodes, edges: edges, isStarting: false, isStopping: true)
            
            let arrTime = currentDeparture.addingTimeInterval(tt)
            train.stops[j].arrival = roundToBusinessSeconds(arrTime)
            
            let dwell = max(120.0, (Double(train.stops[j].minDwellTime) + (train.stops[j].extraDwellTime ?? 0)) * 60.0)
            let depTime = (train.stops[j].arrival ?? arrTime).addingTimeInterval(dwell)
            train.stops[j].departure = (j < train.stops.count - 1) ? roundToBusinessSeconds(depTime) : nil
            
            if let d = train.stops[j].departure { currentDeparture = d } 
            else { currentDeparture = (train.stops[j].arrival ?? arrTime).addingTimeInterval(60) }
        }
    }

    private func refreshStandardSchedule(train: inout [RailwayTrain].Element, nodes: [RailwayNode], edges: [Edge]) {
        guard let depTime = train.departureTime else { return }
        var currentTime = depTime.normalized()
        
        for j in train.stops.indices {
            if j == 0 {
                train.stops[j].arrival = nil
                train.stops[j].departure = currentTime
            } else {
                let prevId = train.stops[j-1].stationId
                let tt = FDCSchedulerEngine.calculateTravelTimeBetweenNodes(from: prevId, to: train.stops[j].stationId, train: train, nodes: nodes, edges: edges, isStarting: j==1, isStopping: true)
                
                currentTime = currentTime.addingTimeInterval(tt)
                let roundedArr = roundToBusinessSeconds(currentTime)
                train.stops[j].arrival = roundedArr
                
                let extraDwell = train.stops[j].extraDwellTime ?? 0
                let dwellDuration = (Double(train.stops[j].minDwellTime) + extraDwell) * 60
                
                currentTime = roundedArr.addingTimeInterval(dwellDuration)
                let roundedDep = roundToBusinessSeconds(currentTime)
                train.stops[j].departure = (j < train.stops.count - 1) ? roundedDep : nil
                if let d = train.stops[j].departure { currentTime = d }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// Intervalla i treni per l'elaborazione A* (Andata 1, Ritorno 1, Andata 2, Ritorno 2...)
    private func interleaveTrainsForAStar(_ trains: [Train]) -> [Train] {
        guard trains.count > 1 else { return trains }
        
        let lineId = trains.first?.lineId
        let lineTrains = trains.filter { $0.lineId == lineId }
        
        // PIGNOLO BOOST: Determine direction by destination if numbers are missing/same
        let firstDest = lineTrains.first?.stops.last?.stationId
        let outward = lineTrains.filter { $0.stops.last?.stationId == firstDest }
        let returns = lineTrains.filter { $0.stops.last?.stationId != firstDest }
        
        var interleaved: [Train] = []
        let maxCount = max(outward.count, returns.count)
        
        for i in 0..<maxCount {
            if i < outward.count { interleaved.append(outward[i]) }
            if i < returns.count { interleaved.append(returns[i]) }
        }
        
        let others = trains.filter { $0.lineId != lineId }
        interleaved.append(contentsOf: others)
        
        print("   🔄 [A*] Treni intervallati (Andata: \(outward.count), Ritorno: \(returns.count)): \(interleaved.map { $0.name }.joined(separator: ", "))")
        return interleaved
    }
    
    private let returnStartNumber = 1 // Convenzione di default se non rilevabile
    
    private func minutesDiff(_ t1: Train, _ t2: Train) -> Int {
        guard let d1 = t1.departureTime, let d2 = t2.departureTime else { return 0 }
        return Int(d2.timeIntervalSince(d1) / 60)
    }
}
