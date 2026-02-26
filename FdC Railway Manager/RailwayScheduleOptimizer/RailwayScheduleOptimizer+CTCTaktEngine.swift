import Foundation
import SwiftUI
import Combine

extension RailwayScheduleOptimizer {
    // MARK: - Step 5: CTC Logic (Deterministic Crossing)
    
    // MARK: - Step 5: Swiss-AStar Logic (A* Space-Time Search)
    
    // MARK: - Takt Engine: Entry Point

    func generaOrarioCadenzato(
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
        let isMainBatch = newTrains.first?.isMainTrain == true
        print("   📋 \(trainsGrouped.count) gruppi – modalità: \(isMainBatch ? "PRINCIPALE" : "SECONDARIO")")

        let calendar = Calendar.current

        if isMainBatch {
            let taktNodeId = preferredTaktNodeId // Store for refreshes
            guard let taktNode = resolveTaktNode(from: nodes, preferredId: taktNodeId) else {
                print("❌ [TaktEngine] Impossibile trovare un nodo Hub Takt valido.")
                return newTrains
            }
            let taktMinute = taktNode.taktMinutes ?? 0
            
            // Gruppiamo per orario e direzione per evitare sovrapposizioni inutili
            let trainsGrouped = groupTrainsByDirection(newTrains, taktNodeId: taktNode.id)
            var allResults: [Train] = []
            
            for var group in trainsGrouped {
                if Task.isCancelled { break }
                let sequence = group[0].stops.map { $0.stationId }
                guard let taktIdx = sequence.firstIndex(of: taktNode.id) else { continue }
                
                print("\n🔵 Gruppo MAIN: \(group.count) treni [Hub \(taktNode.id) @:\(taktMinute)]")
                
                // Refresh con il preferred ID fisso
                for i in group.indices {
                    refreshTaktSchedule(train: &group[i], hIdx: taktIdx, hNode: taktNode, nodes: nodes, edges: edges)
                }
                
                allResults.append(contentsOf: group)
            }
            print("\n🏁 [TaktEngine] \(allResults.count) treni principali generati")
            return allResults

        } else {
            // ═══ TRENI SECONDARI: hub relativo ai principali esistenti + conflict resolution ═══
            var allResults: [Train] = []
            let preferredId = preferredTaktNodeId // Fix identification for refreshes
            
            for var group in trainsGrouped {
                if Task.isCancelled { break }
                let sequence = group[0].stops.map { $0.stationId }
                guard let taktIdx = sequence.firstIndex(of: taktNode.id) else { continue }
                print("\n🟡 Gruppo SEC: \(group.count) treni [Hub \(taktNode.id)]")

                // Per ogni treno, fissa hub relativo al principale esistente
                for i in group.indices {
                    let train = group[i]
                    let mainHubTimes = findMainTrainHubTimes(
                        for: train, taktIdx: taktIdx, taktMinute: taktMinute,
                        existingTrains: existingTrains, taktNodeId: taktNode.id, calendar: calendar)

                    if let mainArr = mainHubTimes?.arr, let mainDep = mainHubTimes?.dep {
                        // Allineamento relativo: Arrivo PRIMA, partenza DOPO.
                        // Usiamo una finestra di 10 min che garantisce transfer in entrambi i sensi.
                        let secArr = mainArr.addingTimeInterval(-10 * 60)
                        let secDep = mainDep.addingTimeInterval(10 * 60)
                        
                        group[i].stops[taktIdx].arrival = secArr
                        group[i].stops[taktIdx].departure = (taktIdx < group[i].stops.count - 1) ? secDep : nil
                        
                        print("   📐 \(train.name): Relativo a IC -> Arr \(formatTime(secArr)) Dep \(formatTime(secDep ?? secArr))")
                    } else {
                        // Nessun principale trovato: usa offset standard dal Takt
                        print("   ⚠️ \(train.name): nessun principale esistente, uso offset standard")
                        let (arr, dep2) = calculateHubTimes(for: train, hIdx: taktIdx, hNode: taktNode)
                        group[i].stops[taktIdx].arrival = arr
                        group[i].stops[taktIdx].departure = (taktIdx < group[i].stops.count - 1) ? dep2 : nil
                    }
                    
                    // Propaga dal hub bloccato
                    var single = group[i]
                    let hubArr = single.stops[taktIdx].arrival!
                    let hubDep = single.stops[taktIdx].departure ?? hubArr
                    
                    propagateBackward(from: taktIdx, arrival: hubArr, train: &single, nodes: nodes, edges: edges)
                    propagateForward(from: taktIdx, departure: hubDep, train: &single, nodes: nodes, edges: edges)
                    single.departureTime = single.stops.first?.departure ?? single.stops.first?.arrival
                    group[i] = single
                }

                // ─── Risoluzione conflitti: shift +1 min iterativo ───
                var pathCache: [String: [Edge]] = [:]
                let maxShift = 30
                for i in group.indices {
                    var shifted = 0
                    while shifted < maxShift {
                        let conflicts = detectConflicts([group[i]], existingTrains: existingTrains,
                                                         nodes: nodes, edges: edges, pathCache: &pathCache)
                        if conflicts.isEmpty { break }
                        shifted += 1
                        
                        // Shiftiamo l'intero orario all'hub
                        if let oldArr = group[i].stops[taktIdx].arrival {
                            group[i].stops[taktIdx].arrival = calendar.date(byAdding: .minute, value: 1, to: oldArr)
                        }
                        if let oldDep = group[i].stops[taktIdx].departure {
                            group[i].stops[taktIdx].departure = calendar.date(byAdding: .minute, value: 1, to: oldDep)
                        }
                        
                        var single = group[i]
                        let hArr = single.stops[taktIdx].arrival!
                        let hDep = single.stops[taktIdx].departure ?? hArr
                        propagateBackward(from: taktIdx, arrival: hArr, train: &single, nodes: nodes, edges: edges)
                        propagateForward(from: taktIdx, departure: hDep, train: &single, nodes: nodes, edges: edges)
                        single.departureTime = single.stops.first?.departure ?? single.stops.first?.arrival
                        group[i] = single
                    }
                    if shifted > 0 {
                        print("   🔧 \(group[i].name): +\(shifted) min shift per conflitti")
                    }
                }

                allResults.append(contentsOf: group)
            }
            print("\n🏁 [TaktEngine] \(allResults.count) treni secondari generati")
            return allResults
        }
    }

    /// Trova gli orari hub del treno principale esistente più vicino al treno secondario.
    func findMainTrainHubTimes(
        for secTrain: Train, taktIdx: Int, taktMinute: Int,
        existingTrains: [Train], taktNodeId: String, calendar: Calendar
    ) -> (arr: Date, dep: Date)? {
        guard let secDep = secTrain.departureTime else { return nil }
        let estTravel = Double(taktIdx) * 3.0 * 60.0
        let estHubTime = secDep.addingTimeInterval(estTravel)

        // Cerca i principali esistenti che passano per l'hub
        let mainAtHub = existingTrains.filter { $0.isMainTrain && $0.stops.contains(where: { $0.stationId == taktNodeId }) }
        guard !mainAtHub.isEmpty else { return nil }

        // Trova quello con orario hub (arrivo o partenza) più vicino nel tempo
        return mainAtHub.compactMap { main -> (arr: Date, dep: Date, dist: TimeInterval)? in
            let mainSeq = main.stops.map { $0.stationId }
            guard let mainTIdx = mainSeq.firstIndex(of: taktNodeId) else { return nil }
            
            // Per treni che iniziano o finiscono al hub, usiamo l'unico orario disponibile
            let mArr = main.stops[mainTIdx].arrival ?? main.stops[mainTIdx].departure
            let mDep = main.stops[mainTIdx].departure ?? main.stops[mainTIdx].arrival
            
            guard let finalArr = mArr, let finalDep = mDep else { return nil }
            
            return (finalArr, finalDep, abs(finalArr.timeIntervalSince(estHubTime)))
        }
        .sorted(by: { $0.dist < $1.dist })
        .first
        .map { (arr: $0.arr, dep: $0.dep) }
    }

    // MARK: - Takt Engine: Helpers

    func resolveTaktNode(from nodes: [RailwayNode], preferredId: String?) -> Node? {
        if let id = preferredId, !id.isEmpty {
            let node = nodes.first(where: { $0.id == id && $0.taktMinutes != nil })
            if node == nil { print("⚠️ Nodo Takt specificato '\(id)' non trovato o senza taktMinutes") }
            return node
        }
        return nodes.first(where: { $0.taktMinutes != nil })
    }

    func resetDwellTimes(_ trains: [Train]) -> [Train] {
        var result = trains
        for i in result.indices {
            for j in result[i].stops.indices { result[i].stops[j].extraDwellTime = 0 }
        }
        return result
    }

    func groupTrainsByDirection(_ trains: [Train], taktNodeId: String) -> [[Train]] {
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

    func buildCycleBaseTimes(from trains: [Train], taktNode: Node) -> [Date: Date] {
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
        
        // Assegna un taktBaseTime a ciascun gruppo di partenze.
        // Avanza di 1 ora: il minuto Takt si ripete ogni ora, quindi ogni ciclo
        // di partenza deve avere il proprio slot hub univoco.
        // Funziona sia per cadenza 60 min (1 slot/ora) che 120 min (1 slot/2 ore).
        var result: [Date: Date] = [:]
        var currentBase = base
        for cycleDep in departures {
            // Avanza currentBase fino a superare o eguagliare cycleDep
            while currentBase < cycleDep {
                currentBase = calendar.date(byAdding: .hour, value: 1, to: currentBase) ?? currentBase
            }
            result[cycleDep] = currentBase
            print("   🕐 Ciclo \(formatTime(cycleDep)): taktBase = \(formatTime(currentBase))")
        }
        
        return result
    }

    func lockHubTimesGlobally(groups: inout [[Train]], taktNode: Node, cycleBaseTimes: [Date: Date]) {
        let taktMinute = taktNode.taktMinutes!
        let calendar = Calendar.current
        for gIdx in 0..<groups.count {
            let seq = groups[gIdx][0].stops.map { $0.stationId }
            guard let tIdx = seq.firstIndex(of: taktNode.id) else { continue }
            for i in groups[gIdx].indices {
                let train = groups[gIdx][i]
                
                let base: Date?
                if train.isMainTrain {
                    // Treni principali: match per partenza dal capolinea (come prima)
                    guard let dep = train.departureTime else { continue }
                    base = cycleBaseTimes.first(where: { abs($0.key.timeIntervalSince(dep)) < 120 })?.value
                } else {
                    // Treni non principali: cerchiamo il taktBase più vicino all'arrivo
                    // STIMATO all'hub, così si allineano allo stesso ciclo dei principali.
                    // Stima: partenza + (indice hub × 3 min come approssimazione per fermata)
                    guard let dep = train.departureTime else { continue }
                    let estimatedTravelToHub = Double(tIdx) * 3.0 * 60.0  // ~3 min per fermata
                    let estimatedHubArrival = dep.addingTimeInterval(estimatedTravelToHub)
                    
                    // Trova il taktBase al minuto Takt più vicino all'arrivo stimato
                    var nearestBase = calendar.date(bySetting: .minute, value: taktMinute, of: estimatedHubArrival) ?? estimatedHubArrival
                    nearestBase = calendar.date(bySetting: .second, value: 0, of: nearestBase) ?? nearestBase
                    // Se nearestBase è troppo prima dell'arrivo stimato, avanza di 1 ora
                    if nearestBase < estimatedHubArrival.addingTimeInterval(-1800) {
                        nearestBase = calendar.date(byAdding: .hour, value: 1, to: nearestBase) ?? nearestBase
                    }
                    base = nearestBase
                    
                    print("   📐 [SEC] \(train.name): dep=\(formatTime(dep)) estHubArr=\(formatTime(estimatedHubArrival)) → taktBase=\(formatTime(nearestBase))")
                }
                
                guard let taktBase = base else { continue }
                let (arr, dep2) = taktHubTimes(train: train, base: taktBase, calendar: calendar)
                groups[gIdx][i].stops[tIdx].arrival = arr
                groups[gIdx][i].stops[tIdx].departure = (tIdx < groups[gIdx][i].stops.count - 1) ? dep2 : nil
                print("   🚆 [\(train.isMainTrain ? "MAIN" : "SEC ")] \(train.name): Hub :\(taktMinute) | Arr \(formatTime(arr)) Dep \(formatTime(dep2))")
            }
        }
    }

    /// Ritorna (arrivo, partenza) all'hub takt per un treno.
    /// - Treni principali: crossing stretto ±2-3 min attorno al minuto Takt
    /// - Treni non principali: posizionati FUORI dalla finestra dei principali.
    ///   Arrivano 10-20 min prima del Takt e ripartono 10-20 min dopo.
    ///   Es. con Takt :45 → arrivi :25-:35, partenze :55-:05
    func taktHubTimes(train: Train, base: Date, calendar: Calendar) -> (Date, Date) {
        if train.isMainTrain {
            let isT1 = (train.number ?? 0) % 2 == 1
            // T1 (dispari): arriva -2, parte +1 → crossing window di 3 minuti
            // T2 (pari):   arriva -3, parte +2 → crossing window di 5 minuti
            let arr = calendar.date(byAdding: .minute, value: isT1 ? -2 : -3, to: base) ?? base
            let dep = calendar.date(byAdding: .minute, value: isT1 ?  1 :  2, to: base) ?? base
            return (arr, dep)
        } else {
            // Treni non principali: posizionati fuori dalla finestra dei principali.
            // Dir 1 (dispari): arriva Takt-20, parte Takt+10 → sosta 30 min
            //   Es. Takt :45 → arr :25, dep :55
            // Dir 2 (pari):    arriva Takt-10, parte Takt+15 → sosta 25 min
            //   Es. Takt :45 → arr :35, dep :00
            // I secondari NON si sovrappongono ai principali (che sono a ±3 min dal Takt)
            let isT1 = (train.number ?? 0) % 2 == 1
            let arr = calendar.date(byAdding: .minute, value: isT1 ? -20 : -10, to: base) ?? base
            let dep = calendar.date(byAdding: .minute, value: isT1 ?  10 :  15, to: base) ?? base
            return (arr, dep)
        }
    }

    func propagateBackward(
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

    func propagateForward(
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

    
    enum ExpansionDirection { case forward, backward }
    
    struct PlanningCursor {
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
    
    func expandCursorOneStep(_ cursor: inout PlanningCursor, direction: ExpansionDirection, core: RailSchedulerCore, network: NetworkModel) {
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
    
    func shiftForward(_ cursor: inout PlanningCursor, delta: TimeInterval) {
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

    func shiftBackward(_ cursor: inout PlanningCursor, delta: TimeInterval) {
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

    func formatTimeWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func isIdJunction(_ id: String, nodes: [RailwayNode]) -> Bool {
        // Fallback check on ID prefix if nodes list isn't handy
        if id.hasPrefix("N-") || id.hasPrefix("NODE_") { return true }
        if let n = nodes.first(where: { $0.id == id }), n.type == .junction { return true }
        return false
    }
    
    /// Arrotonda una data ai 30 secondi più vicini per rendere l'orario più "pulito"
    func roundToBusinessSeconds(_ date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        let rounded = (seconds / 30.0).rounded() * 30.0
        return Date(timeIntervalSince1970: rounded)
    }
    
    
    

}
