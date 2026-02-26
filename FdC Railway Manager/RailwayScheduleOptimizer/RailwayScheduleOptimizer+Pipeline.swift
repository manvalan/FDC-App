import Foundation
import SwiftUI
import Combine

extension RailwayScheduleOptimizer {
    // MARK: - Pipeline Steps

    func logPipelineInit(newTrains: [RailwayTrain], existingTrains: [RailwayTrain], nodes: [RailwayNode], edges: [Edge], useAI: Bool, useGA: Bool) {
        print("\n🚀 [PIPELINE] AVVIO PIPELINE DI OTTIMIZZAZIONE (7 STEP) per \(newTrains.count) treni")
        print("   Input: \(newTrains.count) nuovi treni, \(existingTrains.count) esistenti")
        print("   Rete: \(nodes.count) nodi, \(edges.count) edges")
        print("   Flags: useAI=\(useAI), useGA=\(useGA)")
    }

    func runStep1_TimeOptimization(
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

    func runStep2_PhysicalRefresh(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        preferredTaktNodeId: String?,
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        print("⚙️ [STEP 2] Calcolo Fisico Orari...")
        if Task.isCancelled { return workingTrains }
        return refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredTaktNodeId)
    }

    func runStep3_5_Alignment(
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

    func runStep6_AIOptimization(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        useAI: Bool, 
        hasTaktRequired: Bool, 
        preferredTaktNodeId: String?,
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
        let aiResponse = await performCloudOptimization(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredTaktNodeId)
        
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

    func runStep7_GeneticRefinement(
        workingTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        useGA: Bool, 
        hasTaktRequired: Bool, 
        preferredTaktNodeId: String?,
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

    func runStep8_FinalVerification(
        finalTrains: [RailwayTrain], 
        existingTrains: [RailwayTrain], 
        nodes: [RailwayNode], 
        edges: [Edge], 
        hasTaktRequired: Bool,
        preferredTaktNodeId: String?,
        pathCache: inout [String: [Edge]]
    ) async -> [RailwayTrain] {
        print("📊 [STEP 8] Verifica Finale...")
        if Task.isCancelled { return finalTrains }
        
        var verifiedTrains = finalTrains
        // Refresh finale per garantire che tutti i tempi fisici siano allineati,
        // ma forzando l'Hub corretto per i treni Takt.
        refreshMultipleSchedules(&verifiedTrains, nodes: nodes, edges: edges, pathCache: &pathCache, preferredHubId: preferredTaktNodeId)
        
        let finalConflicts = detectConflicts(verifiedTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &pathCache)
        logFinalReport(conflicts: finalConflicts, totalTrains: verifiedTrains.count, nodes: nodes)
        
        print("🏁 [PIPELINE] Completata. Output: \(verifiedTrains.count) treni.\n")
        return verifiedTrains
    }

    func logFinalReport(conflicts: [ScheduleConflict], totalTrains: Int, nodes: [RailwayNode]) {
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
    

}
