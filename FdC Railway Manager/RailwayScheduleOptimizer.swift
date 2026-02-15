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
        newTrains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        useAI: Bool = true,
        useGA: Bool = true,
        geneticOptimizer: GeneticOptimizer? = nil
    ) async -> [Train] {
        if Task.isCancelled { 
            print("⚠️ [PIPELINE] Task cancellata all'avvio!")
            return newTrains 
        }
        var localPathCache: [String: [Edge]] = [:] 
        
        print("\n🚀 [PIPELINE] AVVIO PIPELINE DI OTTIMIZZAZIONE (7 STEP) per \(newTrains.count) treni")
        print("   Input: \(newTrains.count) nuovi treni, \(existingTrains.count) esistenti")
        print("   Rete: \(nodes.count) nodi, \(edges.count) edges")
        print("   Flags: useAI=\(useAI), useGA=\(useGA)")
        
        // --- STEP 1: Time Optimization (Orari di Partenza) ---
        // Cerchiamo di evitare i conflitti più banali spostando la partenza di +/- 15 minuti.
        var workingTrains = newTrains
        if useGA {
            print("🕒 [STEP 1] Ottimizzazione Orari di Partenza...")
            try? await Task.yield()
            if Task.isCancelled { return newTrains }
            workingTrains = optimizeDepartureTimes(newTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        } else {
            print("🕒 [STEP 1] SKIP: Ottimizzazione Orari di Partenza disabilitata.")
        }
        
        // --- STEP 2: Generazione Orario (Refresh) ---
        // Assicuriamoci che i dati fisici (arrivi/partenze fermate) siano coerenti.
        print("⚙️ [STEP 2] Calcolo Fisico Orari...")
        if Task.isCancelled { return workingTrains }
        workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        
        // --- STEP 3: Analisi Criticità ---
        // Analizziamo dove avvengono i conflitti residui per capire quali sono i colli di bottiglia.
        print("🔍 [STEP 3] Analisi Conflitti Residui...")
        if Task.isCancelled { return workingTrains }
        let conflicts = detectConflicts(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        
        if !conflicts.isEmpty {
            print("   ⚠️ Rilevati \(conflicts.count) conflitti residui. Avvio Analisi Hotspot.")
            
            // Identifica le stazioni dove avvengono più conflitti o le tratte sature
            let hotspots = analyzeHotspots(conflicts: conflicts, nodes: nodes)
            let hotspotNames = hotspots.keys.sorted { hotspots[$0]! > hotspots[$1]! }.prefix(5)
            print("   📍 Hotspots identificati: \(hotspotNames.joined(separator: ", "))")
            
            // --- STEP 5: CTC Single Track Resolution (DETERMINISTIC) ---
            // Invece di indovinare "soste tattiche", calcoliamo gli incroci esatti.
            if useGA {
                print("🚦 [STEP 5] Risoluzione Conflitti CTC (Binario Unico)...")
                if Task.isCancelled { return workingTrains }
                workingTrains = await resolveSingleTrackConflicts(
                    trains: workingTrains,
                    existingTrains: existingTrains,
                    nodes: nodes,
                    edges: edges,
                    conflicts: conflicts,
                    pathCache: &localPathCache
                )
            } else {
                print("🚦 [STEP 5] SKIP: Risoluzione CTC disabilitata.")
            }
            
            // Refresh post-CTC
            workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        } else {
            print("   ✅ Nessun conflitto rilevato dopo Step 1. Skipping Step 3-5.")
        }
        
        // --- STEP 6: AI Cloud Optimization ---
        // Se rimangono conflitti complessi, chiediamo all'AI.
        if useAI {
            print("🧠 [STEP 6] AI Cloud Optimization...")
            if Task.isCancelled { return workingTrains }
            let conflictsBeforeAI = detectConflicts(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache).count
            print("   🔍 Conflitti pre-AI: \(conflictsBeforeAI)")
            
            let preAITrains = workingTrains // BACKUP for rollback
            let aiResponse = await performCloudOptimization(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
            
            if let response = aiResponse, let resolutions = response.resolutions, !resolutions.isEmpty {
                // PIGNOLO PROTOCOL: Calculate average confidence across all resolutions
                let avgConfidence = resolutions.compactMap { $0.confidence }.reduce(0.0, +) / Double(resolutions.count)
                let confidence = response.ml_confidence ?? (resolutions.isEmpty ? 0.0 : avgConfidence)
                
                print("   📥 Ricevute \(resolutions.count) risoluzioni dall'AI (Confidenza Media: \(Int(confidence * 100))%).")
                
                // PIGNOLO PROTOCOL: Confidence Filter (Regression Handling)
                if confidence < 0.15 {
                    print("   ⚠️ [WARNING] Confidenza AI troppo bassa (\(Int(confidence * 100))%). Soluzione scartata.")
                } else {
                    workingTrains = applyAIResolutions(workingTrains, resolutions: resolutions)
                    // Refresh post-AI
                    workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
                    
                    let conflictsAfterAI = detectConflicts(workingTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache).count
                    
                    // Solo se migliora davvero i conflitti o mantiene lo status quo senza creare caos
                    if conflictsAfterAI > conflictsBeforeAI + 2 {
                        print("   ❌ [ROLLBACK] L'AI ha peggiorato lo scenario (\(conflictsBeforeAI) -> \(conflictsAfterAI)). Ripristino stato pre-AI.")
                        workingTrains = preAITrains
                    } else {
                        print("   ✅ Conflitti post-AI: \(conflictsAfterAI) (Variazione: \(conflictsAfterAI - conflictsBeforeAI))")
                    }
                }
            } else {
                print("   ℹ️ L'AI non ha proposto risoluzioni o la chiamata è fallita.")
            }
        } else {
            print("   ⏭️ AI Cloud disabilitata o non richiesta.")
        }
        
        // --- STEP 7: Genetic Refinement ---
        // Pulizia finale per limare i dettagli o risolvere conflitti minori ignorati dall'AI.
        var finalTrains = workingTrains
        if useGA {
            print("🧬 [STEP 7] Genetic Algorithm Refinement...")
            if Task.isCancelled { return workingTrains }
            // Usiamo l'optimizer passato (per la UI) o quello interno
            let ga = geneticOptimizer ?? self.geneticOptimizer
            
            finalTrains = await ga.optimize(
                newTrains: workingTrains,
                existingTrains: existingTrains,
                nodes: nodes,
                edges: edges,
                iterations: 250 // PIGNOLO BOOST: Raised from 100 to 250 for final conflict clearance
            )
        } else {
            print("🧬 [STEP 7] SKIP: Genetic Refinement disabilitata.")
        }
        
        
        // --- STEP 8: Final Verification & Reporting ---
        print("📊 [STEP 8] Verifica Finale...")
        // Refresh finale per sicurezza
        let verifiedTrains = refreshPhysicalSchedules(finalTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        let finalConflicts = detectConflicts(verifiedTrains, existingTrains: existingTrains, nodes: nodes, edges: edges, pathCache: &localPathCache)
        
        if finalConflicts.isEmpty {
            print("\n✨ 🏆 OTTIMIZZAZIONE PERFETTA! 0 Conflitti residui. 🏆 ✨")
        } else {
            print("\n⚠️ [RESULT] Ottimizzazione terminata con \(finalConflicts.count) conflitti residui.")
            let uniqueConflictingTrains = Set(finalConflicts.flatMap { [$0.trainAId, $0.trainBId] })
            print("   🚂 Treni coinvolti: \(uniqueConflictingTrains.count) (su \(verifiedTrains.count) totali)")
            
            // Log per Stazione
            let perStation = analyzeHotspots(conflicts: finalConflicts, nodes: nodes)
            let sortedStations = perStation.sorted { $0.value > $1.value }
            for (station, count) in sortedStations.prefix(5) {
                print("      • \(station): \(count)")
            }
            
            // Loggare i primi 3 conflitti per capire il problema
            for (i, c) in finalConflicts.prefix(3).enumerated() {
                print("   ❌ Conflitto \(i+1): \(c.description) [\(c.timeStart.formatted(date: .omitted, time: .shortened)) - \(c.timeEnd.formatted(date: .omitted, time: .shortened))]")
            }
        }
        
        print("🏁 [PIPELINE] Completata. Output: \(verifiedTrains.count) treni.\n")
        return verifiedTrains
    }
    
    // MARK: - Step 1: Time Optimization
    
    private func optimizeDepartureTimes(_ newTrains: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) -> [Train] {
        var optimized: [Train] = []
        
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
    
    private func analyzeHotspots(conflicts: [ScheduleConflict], nodes: [Node]) -> [String: Int] {
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
    
    private func resolveSingleTrackConflicts(
        trains: [Train],
        existingTrains: [Train],
        nodes: [Node],
        edges: [Edge],
        conflicts: [ScheduleConflict],
        pathCache: inout [String: [Edge]]
    ) async -> [Train] {
        var processedTrains = trains
        let maxPasses = 8
        
        for pass in 1...maxPasses {
            if Task.isCancelled { break }
            await Task.yield()
            
            var all = existingTrains + processedTrains
            refreshMultipleSchedules(&all, nodes: nodes, edges: edges, pathCache: &pathCache)
            processedTrains = Array(all.suffix(processedTrains.count))
            
            var cacheWrapper: [String: [Edge]]? = pathCache
            let (lineConflictsFull, capacities) = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: all, pathCache: &cacheWrapper)
            if let updatedCache = cacheWrapper { pathCache = updatedCache }
            
            // Filtra solo conflitti su BINARIO UNICO (Track Capacity = 1)
            let lineConflicts = lineConflictsFull.filter { c in
                let cap = capacities[c.locationId] ?? 1
                return cap == 1 && (c.locationId.contains("--") || c.locationId.contains("SEGMENT"))
            }.sorted { $0.timeStart < $1.timeStart } // Risolviamo il primo che accade
            
            if lineConflicts.isEmpty {
                print("      ✅ Nessun conflitto di linea residuo al pass \(pass).")
                break
            }
            
            // 3. Risolvi il PRIMO conflitto (quello che blocca tutto)
            let conflict = lineConflicts[0]
            
            // Identifica i treni (dobbiamo lavorare sugli indici di processedTrains)
            guard let idxA = processedTrains.firstIndex(where: { $0.id == conflict.trainAId }),
                  let idxB = processedTrains.firstIndex(where: { $0.id == conflict.trainBId }) else {
                // Uno dei treni è "existing" (immutabile). Dobbiamo spostare l'altro.
                if let idxMutable = processedTrains.firstIndex(where: { $0.id == conflict.trainAId } ) {
                    solveConflict(mutableIdx: idxMutable, immutableId: conflict.trainBId, conflict: conflict, trains: &processedTrains, nodes: nodes)
                } else if let idxMutable = processedTrains.firstIndex(where: { $0.id == conflict.trainBId }) {
                solveConflict(mutableIdx: idxMutable, immutableId: conflict.trainAId, conflict: conflict, trains: &processedTrains, nodes: nodes)
                }
                continue
            }
            
            // Entrambi mutabili. Chi vince?
            // Vince chi arriva PRIMA alla risorsa (segmento o stazione)
            let trainA = processedTrains[idxA]
            let trainB = processedTrains[idxB]
            
            // Troviamo i tempi di arrivo alla risorsa per entrambi
            let stopA = trainA.stops.first(where: { s in
                if let dep = s.departure { return dep >= conflict.timeStart }
                return false
            })
            let arrivalA = stopA?.arrival ?? trainA.departureTime ?? Date.distantPast
            
            let stopB = trainB.stops.first(where: { s in
                if let dep = s.departure { return dep >= conflict.timeStart }
                return false
            })
            let arrivalB = stopB?.arrival ?? trainB.departureTime ?? Date.distantPast
            
            if arrivalA <= arrivalB {
                solveCrossing(winnerIdx: idxA, loserIdx: idxB, conflict: conflict, trains: &processedTrains, nodes: nodes)
            } else {
                solveCrossing(winnerIdx: idxB, loserIdx: idxA, conflict: conflict, trains: &processedTrains, nodes: nodes)
            }
        }
        
        return processedTrains
    }
    
    private func solveConflict(mutableIdx: Int, immutableId: UUID, conflict: ScheduleConflict, trains: inout [Train], nodes: [Node]) {
         delayTrainBeforeConflict(trainIdx: mutableIdx, conflict: conflict, trains: &trains, nodes: nodes)
    }
    
    private func solveCrossing(winnerIdx: Int, loserIdx: Int, conflict: ScheduleConflict, trains: inout [Train], nodes: [Node]) {
        delayTrainBeforeConflict(trainIdx: loserIdx, conflict: conflict, trains: &trains, nodes: nodes)
    }
    
    private func delayTrainBeforeConflict(trainIdx: Int, conflict: ScheduleConflict, trains: inout [Train], nodes: [Node]) {
        let train = trains[trainIdx]
        
        // Cerchiamo la stazione di incrocio ideale (quella con > 1 binario)
        var bestStopIndex: Int? = train.stops.lastIndex(where: { stop in
            guard let dep = stop.departure else { return false }
            // Troviamo l'ultima fermata PRIMA del conflitto
            return dep <= conflict.timeStart.addingTimeInterval(30)
        })
        
        // Se la stazione trovata ha solo 1 binario, cerchiamo una stazione con più binari precedente.
        if let currentIdx = bestStopIndex {
            for i in (0...currentIdx).reversed() {
                let sid = train.stops[i].stationId
                if let node = nodes.first(where: { $0.id == sid }), (node.platforms ?? 2) > 1 {
                    bestStopIndex = i
                    break
                }
            }
        }
        
        guard let stopIndex = bestStopIndex else { return }
        
        // PIGNOLO: Cap cumulative delay per stop to 45 mins to avoid "messed up" schedules
        if trains[trainIdx].stops[stopIndex].minDwellTime > 45 { return }

        // Calcoliamo quanto ritardo serve (Deterministic Crossing)
        // Usiamo un buffer di 5 minuti per essere più decisi negli incroci su binario unico
        let neededDeparture = conflict.timeEnd.addingTimeInterval(300) 
        let currentDeparture = train.stops[stopIndex].departure ?? Date()
        
        if neededDeparture > currentDeparture.addingTimeInterval(5) { // 5s tolerance
            let addedMinutes = Int(ceil(neededDeparture.timeIntervalSince(currentDeparture) / 60))
            if addedMinutes > 0 {
                let oldMinDwell = trains[trainIdx].stops[stopIndex].minDwellTime
                let newMinDwell = oldMinDwell + addedMinutes
                
                if newMinDwell < 60 && newMinDwell > oldMinDwell {
                    let stationName = nodes.first(where: { $0.id == trains[trainIdx].stops[stopIndex].stationId })?.name ?? trains[trainIdx].stops[stopIndex].stationId
                    print("      🛑 CTC Incrocio: \(trains[trainIdx].name) aspetta a \(stationName) (+ \(addedMinutes)m)")
                    trains[trainIdx].stops[stopIndex].minDwellTime = newMinDwell
                    
                    // PIGNOLO PROTOCOL: Resolve the plannedDeparture bottleneck.
                    // Se la sosta minima supera l'orario pianificato, dobbiamo invalidare l'orario pianificato
                    // per permettere alla sosta di spingere effettivamente il treno nel futuro.
                    if let planned = trains[trainIdx].stops[stopIndex].plannedDeparture {
                         if neededDeparture > planned {
                             trains[trainIdx].stops[stopIndex].plannedDeparture = nil
                             // print("         (Note: Invalidate planned departure to allow dwell shift)")
                         }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Helpers & Step 6 Integation
    
    private func performCloudOptimization(_ trains: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) async -> RailwayAIResponse? {
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
    
    private func refreshPhysicalSchedules(_ trains: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) -> [Train] {
        var all = existingTrains + trains
        refreshMultipleSchedules(&all, nodes: nodes, edges: edges, pathCache: &pathCache)
        
        let updatedIds = Set(trains.map { $0.id })
        return all.filter { updatedIds.contains($0.id) }
    }
    
    private func detectConflicts(_ trainSubset: [Train], existingTrains: [Train], nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        var dc: [String: [Edge]]? = pathCache
        let res = conflictManager.calculateConflictsWithCapacities(nodes: nodes, edges: edges, trains: allTrains, pathCache: &dc).0
        if let u = dc { pathCache = u }
        return res
    }
    
    // MARK: - Local Schedule Helpers (Replacing TrainManager)
    
    private func refreshMultipleSchedules(_ trains: inout [Train], nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) {
        for i in trains.indices {
            refreshSingleTrainSchedule(&trains[i], nodes: nodes, edges: edges, pathCache: &pathCache)
        }
    }
    
    private func refreshSingleTrainSchedule(_ train: inout [Train].Element, nodes: [Node], edges: [Edge], pathCache: inout [String: [Edge]]) {
        guard let depTime = train.departureTime else {
            #if DEBUG
            print("⚠️ [Optimizer] Train '\(train.name)' has no departureTime")
            #endif
            return
        }
        var currentTime = depTime.normalized()
        
        #if DEBUG
        print("🔄 [Optimizer] Refreshing schedule for train '\(train.name)' (\(train.stops.count) stops)")
        #endif
        
        for j in train.stops.indices {
            let stop = train.stops[j]
            if j == 0 {
                train.stops[j].arrival = nil
                train.stops[j].departure = currentTime
                #if DEBUG
                print("   Stop 0: \(stop.stationId) → Departure: \(formatTime(currentTime))")
                #endif
            } else {
                let prevId = train.stops[j-1].stationId
                let pathKey = "\(prevId)--\(stop.stationId)"
                
                // Try bidirectional path finding
                var pathEdges = pathCache[pathKey]
                if pathEdges == nil {
                    pathEdges = NetworkModel.findPathEdges(from: prevId, to: stop.stationId, nodes: nodes, edges: edges, ignoreDirection: false)
                    
                    // If no directed path found, try ignoring direction
                    if pathEdges == nil {
                        pathEdges = NetworkModel.findPathEdges(from: prevId, to: stop.stationId, nodes: nodes, edges: edges, ignoreDirection: true)
                    }
                }
                
                if let actualPath = pathEdges {
                    pathCache[pathKey] = actualPath
                    let dist = actualPath.reduce(0.0) { $0 + $1.distance }
                    let speed = actualPath.map { Double($0.maxSpeed) }.min() ?? 100.0
                    
                    let hours = FDCSchedulerEngine.calculateTravelTime(
                        distanceKm: dist,
                        maxSpeedKmh: speed,
                        train: train,
                        initialSpeedKmh: 0,
                        finalSpeedKmh: 0
                    )
                    
                    currentTime = currentTime.addingTimeInterval(hours * 3600)
                    
                    train.stops[j].arrival = currentTime
                    // PIGNOLO FIX: Include extraDwellTime (CTC/AI/GA offsets)
                    let baseDwell = Double(stop.minDwellTime)
                    let extraDwell = stop.extraDwellTime
                    let dwellDuration = (baseDwell + extraDwell) * 60
                    
                    currentTime = currentTime.addingTimeInterval(dwellDuration)
                    train.stops[j].departure = (j < train.stops.count - 1) ? currentTime : nil
                    
                    #if DEBUG
                    let arr = train.stops[j].arrival.map { formatTime($0) } ?? "nil"
                    let dep = train.stops[j].departure.map { formatTime($0) } ?? "nil"
                    print("   Stop \(j): \(stop.stationId) → Arrival: \(arr), Departure: \(dep)")
                    #endif
                } else {
                    // FALLBACK: Use estimated time based on distance if no path found
                    #if DEBUG
                    print("   ⚠️ Stop \(j): No path found from \(prevId) to \(stop.stationId) - using fallback")
                    #endif
                    
                    // Use 5km fallback distance and 60 km/h speed
                    let fallbackDist = 5.0
                    let fallbackSpeed = 60.0
                    let hours = FDCSchedulerEngine.calculateTravelTime(
                        distanceKm: fallbackDist,
                        maxSpeedKmh: fallbackSpeed,
                        train: train,
                        initialSpeedKmh: 0,
                        finalSpeedKmh: 0
                    )
                    
                    currentTime = currentTime.addingTimeInterval(hours * 3600)
                    train.stops[j].arrival = currentTime
                    
                    let baseDwell = Double(stop.minDwellTime)
                    let extraDwell = stop.extraDwellTime
                    let dwellDuration = (baseDwell + extraDwell) * 60
                    
                    currentTime = currentTime.addingTimeInterval(dwellDuration)
                    train.stops[j].departure = (j < train.stops.count - 1) ? currentTime : nil
                    
                    // Mark train as having a scheduling error
                    train.schedulingError = "Missing path: \(prevId) → \(stop.stationId)"
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func minutesDiff(_ t1: Train, _ t2: Train) -> Int {
        guard let d1 = t1.departureTime, let d2 = t2.departureTime else { return 0 }
        return Int(d2.timeIntervalSince(d1) / 60)
    }
}
