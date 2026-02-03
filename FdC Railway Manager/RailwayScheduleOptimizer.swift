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
    private var localPathCache: [String: [Edge]] = [:]
    
    func executePipeline(
        newTrains: [Train],
        existingTrains: [Train],
        network: RailwayNetwork,
        useAI: Bool = true,
        geneticOptimizer: GeneticOptimizer? = nil
    ) async -> [Train] {
        if Task.isCancelled { return newTrains }
        localPathCache.removeAll() // Reset per nuova esecuzione
        
        print("\n🚀 [PIPELINE] AVVIO PIPELINE DI OTTIMIZZAZIONE (7 STEP) per \(newTrains.count) treni")
        
        // --- STEP 1: Time Optimization (Orari di Partenza) ---
        // Cerchiamo di evitare i conflitti più banali spostando la partenza di +/- 15 minuti.
        print("🕒 [STEP 1] Ottimizzazione Orari di Partenza...")
        try? await Task.yield()
        if Task.isCancelled { return newTrains }
        var workingTrains = optimizeDepartureTimes(newTrains, existingTrains: existingTrains, network: network)
        
        // --- STEP 2: Generazione Orario (Refresh) ---
        // Assicuriamoci che i dati fisici (arrivi/partenze fermate) siano coerenti.
        print("⚙️ [STEP 2] Calcolo Fisico Orari...")
        if Task.isCancelled { return workingTrains }
        workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, network: network)
        
        // --- STEP 3: Analisi Criticità ---
        // Analizziamo dove avvengono i conflitti residui per capire quali sono i colli di bottiglia.
        print("🔍 [STEP 3] Analisi Conflitti Residui...")
        if Task.isCancelled { return workingTrains }
        let conflicts = detectConflicts(workingTrains, existingTrains: existingTrains, network: network)
        
        if !conflicts.isEmpty {
            print("   ⚠️ Rilevati \(conflicts.count) conflitti residui. Avvio Analisi Hotspot.")
            
            // Identifica le stazioni dove avvengono più conflitti o le tratte sature
            let hotspots = analyzeHotspots(conflicts: conflicts, network: network)
            let hotspotNames = hotspots.keys.sorted { hotspots[$0]! > hotspots[$1]! }.prefix(5)
            print("   📍 Hotspots identificati: \(hotspotNames.joined(separator: ", "))")
            
            // --- STEP 5: CTC Single Track Resolution (DETERMINISTIC) ---
            // Invece di indovinare "soste tattiche", calcoliamo gli incroci esatti.
            print("🚦 [STEP 5] Risoluzione Conflitti CTC (Binario Unico)...")
            if Task.isCancelled { return workingTrains }
            workingTrains = await resolveSingleTrackConflicts(
                trains: workingTrains,
                existingTrains: existingTrains,
                network: network,
                conflicts: conflicts
            )
            
            // Refresh post-CTC
            workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, network: network)
        } else {
            print("   ✅ Nessun conflitto rilevato dopo Step 1. Skipping Step 3-5.")
        }
        
        // --- STEP 6: AI Cloud Optimization ---
        // Se rimangono conflitti complessi, chiediamo all'AI.
        if useAI {
            print("🧠 [STEP 6] AI Cloud Optimization...")
            if Task.isCancelled { return workingTrains }
            let conflictsBeforeAI = detectConflicts(workingTrains, existingTrains: existingTrains, network: network).count
            print("   🔍 Conflitti pre-AI: \(conflictsBeforeAI)")
            
            let preAITrains = workingTrains // BACKUP for rollback
            let aiResponse = await performCloudOptimization(workingTrains, existingTrains: existingTrains, network: network)
            
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
                    workingTrains = refreshPhysicalSchedules(workingTrains, existingTrains: existingTrains, network: network)
                    
                    let conflictsAfterAI = detectConflicts(workingTrains, existingTrains: existingTrains, network: network).count
                    
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
        print("🧬 [STEP 7] Genetic Algorithm Refinement...")
        if Task.isCancelled { return workingTrains }
        // Usiamo l'optimizer passato (per la UI) o quello interno
        let ga = geneticOptimizer ?? self.geneticOptimizer
        
        let finalTrains = await ga.optimize(
            newTrains: workingTrains,
            existingTrains: existingTrains,
            network: network,
            iterations: 250 // PIGNOLO BOOST: Raised from 100 to 250 for final conflict clearance
        )
        
        
        // --- STEP 8: Final Verification & Reporting ---
        print("📊 [STEP 8] Verifica Finale...")
        // Refresh finale per sicurezza
        let verifiedTrains = refreshPhysicalSchedules(finalTrains, existingTrains: existingTrains, network: network)
        let finalConflicts = detectConflicts(verifiedTrains, existingTrains: existingTrains, network: network)
        
        if finalConflicts.isEmpty {
            print("\n✨ 🏆 OTTIMIZZAZIONE PERFETTA! 0 Conflitti residui. 🏆 ✨")
        } else {
            print("\n⚠️ [RESULT] Ottimizzazione terminata con \(finalConflicts.count) conflitti residui.")
            let uniqueConflictingTrains = Set(finalConflicts.flatMap { [$0.trainAId, $0.trainBId] })
            print("   🚂 Treni coinvolti: \(uniqueConflictingTrains.count) (su \(verifiedTrains.count) totali)")
            
            // Log per Stazione
            let perStation = analyzeHotspots(conflicts: finalConflicts, network: network)
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
    
    private func optimizeDepartureTimes(_ newTrains: [Train], existingTrains: [Train], network: RailwayNetwork) -> [Train] {
        var optimized: [Train] = []
        let tempManager = TrainManager()
        
        // Iteriamo su ogni nuovo treno.
        // NOTA: È fondamentale ottimizzarli uno alla volta accumulando il risultato in 'optimized'.
        for (idx, train) in newTrains.enumerated() {
            if Task.isCancelled { break }
            var bestTrain = train
            var minConflicts = Int.max
            var initialConflicts = 0
            
            // Calcolo baseline
            tempManager.trains = existingTrains + optimized + [train]
            tempManager.refreshSchedules(with: network)
            initialConflicts = conflictManager.calculateConflicts(network: network, trains: tempManager.trains).count
            minConflicts = initialConflicts
            
            // Range di shift da testare (in minuti) ESTESO e AGGRESSIVO
            // Privilegiamo lo 0, poi piccoli spostamenti, poi grandi fino a 1 ora.
            let shifts = [1,-1,2,-2,3,-3,4,-4,5, -5, 10, -10, 15, -15, 20, -20, 25,-25,30, -30, 35,-35,40,-40,45, -45, 50,-50, 55,-55, 60, -60]
            
            // Se partiamo già da 0, proviamo a migliorare solo se necessario
            if minConflicts > 0 {
                for shift in shifts {
                    var candidate = train
                    if let dep = train.departureTime {
                        candidate.departureTime = Calendar.current.date(byAdding: .minute, value: shift, to: dep)
                    }
                    
                    // Testiamo il candidato contro: Treni Esistenti + Treni Nuovi GIA' Ottimizzati
                    tempManager.trains = existingTrains + optimized + [candidate]
                    tempManager.refreshSchedules(with: network)
                    
                    let count = conflictManager.calculateConflicts(network: network, trains: tempManager.trains).count
                    
                    if count < minConflicts {
                        minConflicts = count
                        bestTrain = candidate
                        if count == 0 { break } // Ottimo locale trovato
                    }
                }
            }
            
            optimized.append(bestTrain)
            
            let finalShift = minutesDiff(train, bestTrain)
            if finalShift != 0 || minConflicts != initialConflicts {
                print("   🔹 Treno \(idx+1)/\(newTrains.count): Partenza ottimizzata per numero conflitti da \(initialConflicts) a \(minConflicts). Shift: \(finalShift)m.")
            } else {
                 print("   🔹 Treno \(idx+1)/\(newTrains.count): Nessun miglioramento possibile (Conflitti: \(minConflicts)).")
            }
        }
        
        return optimized
    }
    
    /// Identifica le Stazioni o Tratte dove avvengono i conflitti.
    /// Ritorna una mappa [ReadableName: Int] che indica la frequenza dei conflitti in quel punto.
    private func analyzeHotspots(conflicts: [ScheduleConflict], network: RailwayNetwork) -> [String: Int] {
        var heatmap: [String: Int] = [:]
        
        for conflict in conflicts {
            let resId = conflict.locationId
            let name = conflict.locationName
            
            if resId.hasPrefix("SEGMENT::") {
                let content = resId.replacingOccurrences(of: "SEGMENT::", with: "")
                let parts = content.components(separatedBy: "--")
                for stationId in parts {
                    let stationName = network.nodes.first(where: { $0.id == stationId })?.name ?? stationId
                    heatmap[stationName, default: 0] += 1
                }
            } else if resId.hasPrefix("STATION::") {
                let stationId = resId.components(separatedBy: "::")[1]
                let stationName = network.nodes.first(where: { $0.id == stationId })?.name ?? stationId
                heatmap[stationName, default: 0] += 1
            } else {
                heatmap[name, default: 0] += 1
            }
        }
        
        // Filtriamo solo quelli rilevanti (> 0)
        return heatmap
    }
    
    // MARK: - Step 5: CTC Logic (Deterministic Crossing)
    
    private func resolveSingleTrackConflicts(
        trains: [Train],
        existingTrains: [Train],
        network: RailwayNetwork,
        conflicts: [ScheduleConflict]
    ) async -> [Train] {
        var processedTrains = trains
        let tempManager = TrainManager()
        
        // Limite di sicurezza per evitare loop infiniti
        let maxPasses = 20
        
        for pass in 1...maxPasses {
            if Task.isCancelled { break }
            await Task.yield() // Permettiamo alla UI di respirare ad ogni iterazione CTC
            
            // 1. Refresh stato attuale
            tempManager.trains = existingTrains + processedTrains
            tempManager.refreshSchedules(with: network, pathCache: &localPathCache) // Aggiorna orari fisici con cache
            
            // Reimportiamo i treni aggiornati dal manager (importante per avere i tempi corretti)
            let updatedMap = Dictionary(uniqueKeysWithValues: tempManager.trains.map { ($0.id, $0) })
            for i in processedTrains.indices {
                if let up = updatedMap[processedTrains[i].id] {
                    processedTrains[i] = up
                }
            }
            
            // 2. Calcola conflitti
            var cacheWrapper: [String: [Edge]]? = localPathCache
            let (currentConflicts, capacities) = conflictManager.calculateConflictsWithCapacities(network: network, trains: tempManager.trains, pathCache: &cacheWrapper)
            if let updatedCache = cacheWrapper { localPathCache = updatedCache }
            
            // Filtra solo conflitti su BINARIO UNICO (Track Capacity = 1)
            let lineConflicts = currentConflicts.filter { c in
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
                    solveConflict(mutableIdx: idxMutable, immutableId: conflict.trainBId, conflict: conflict, trains: &processedTrains, network: network)
                } else if let idxMutable = processedTrains.firstIndex(where: { $0.id == conflict.trainBId }) {
                    solveConflict(mutableIdx: idxMutable, immutableId: conflict.trainAId, conflict: conflict, trains: &processedTrains, network: network)
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
                solveCrossing(winnerIdx: idxA, loserIdx: idxB, conflict: conflict, trains: &processedTrains, network: network)
            } else {
                solveCrossing(winnerIdx: idxB, loserIdx: idxA, conflict: conflict, trains: &processedTrains, network: network)
            }
        }
        
        return processedTrains
    }
    
    private func solveConflict(mutableIdx: Int, immutableId: UUID, conflict: ScheduleConflict, trains: inout [Train], network: RailwayNetwork) {
         // Il treno mutable deve aspettare che l'immutable liberi la risorsa.
         delayTrainBeforeConflict(trainIdx: mutableIdx, conflict: conflict, trains: &trains, network: network)
    }
    
    private func solveCrossing(winnerIdx: Int, loserIdx: Int, conflict: ScheduleConflict, trains: inout [Train], network: RailwayNetwork) {
        // Il winner passa. Il loser aspetta.
        delayTrainBeforeConflict(trainIdx: loserIdx, conflict: conflict, trains: &trains, network: network)
    }
    
    private func delayTrainBeforeConflict(trainIdx: Int, conflict: ScheduleConflict, trains: inout [Train], network: RailwayNetwork) {
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
                if let node = network.nodes.first(where: { $0.id == sid }), (node.platforms ?? 2) > 1 {
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
                    let stationName = network.nodes.first(where: { $0.id == train.stops[stopIndex].stationId })?.name ?? train.stops[stopIndex].stationId
                    print("      🛑 CTC Incrocio: \(train.name) aspetta a \(stationName) (+ \(addedMinutes)m)")
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
    
    private func performCloudOptimization(_ trains: [Train], existingTrains: [Train], network: RailwayNetwork) async -> RailwayAIResponse? {
        // Prepara il payload completo
        let tempManager = TrainManager()
        tempManager.trains = existingTrains + trains
        tempManager.refreshSchedules(with: network)
        let currentConflicts = conflictManager.calculateConflicts(network: network, trains: tempManager.trains)
        
        if currentConflicts.isEmpty { return nil }
        
        // PIGNOLO PROTOCOL: Pass fixed train IDs to AI so it treats them as immutable constraints
        let fixedIds = Set(existingTrains.map { $0.id })
        let req = aiService.createRequest(network: network, trains: tempManager.trains, fixedTrainIds: fixedIds, conflicts: currentConflicts)
        
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
    
    private func refreshPhysicalSchedules(_ trains: [Train], existingTrains: [Train], network: RailwayNetwork) -> [Train] {
        let tempManager = TrainManager()
        tempManager.trains = existingTrains + trains
        tempManager.refreshSchedules(with: network, pathCache: &localPathCache)
        
        // Estraiamo solo i nostri treni aggiornati
        // (Assumendo che refreshSchedules modifichi in-place gli oggetti nel manager)
        let updatedIds = Set(trains.map { $0.id })
        return tempManager.trains.filter { updatedIds.contains($0.id) }
    }
    
    private func detectConflicts(_ trainSubset: [Train], existingTrains: [Train], network: RailwayNetwork) -> [ScheduleConflict] {
        let allTrains = existingTrains + trainSubset
        return conflictManager.calculateConflicts(network: network, trains: allTrains)
    }
    
    private func minutesDiff(_ t1: Train, _ t2: Train) -> Int {
        guard let d1 = t1.departureTime, let d2 = t2.departureTime else { return 0 }
        return Int(d2.timeIntervalSince(d1) / 60)
    }
}
