import Foundation
import FDCDomain

/// Generazione orari cadenzati (Taktfahrplan) — logica unificata
/// precedentemente in RailwayScheduleOptimizer+CTCTaktEngine.
extension TaktEngine {

    public typealias ConflictDetector = (
        _ trainSubset: [Train],
        _ existingTrains: [Train],
        _ pathCache: inout [String: [Edge]]
    ) -> [ScheduleConflict]

    // MARK: - Entry point

    public func generaOrarioCadenzato(
        newTrains: [Train],
        existingTrains: [Train],
        preferredTaktNodeId: String? = nil,
        conflictDetector: ConflictDetector? = nil
    ) async -> [Train] {
        let nodes = topology.nodes
        let edges = topology.edges

        print("\n🌊🌊🌊 [TaktEngine] AVVIO GENERAZIONE ORARIO CADENZATO 🌊🌊🌊")
        guard let taktNode = resolveTaktNode(preferredId: preferredTaktNodeId) else {
            print("⚠️ Nessun nodo Takt trovato, ritorno treni originali")
            return newTrains
        }
        let taktMinute = taktNode.taktMinutes!
        print("📍 Nodo Takt: \(taktNode.name ?? taktNode.id) al minuto :\(taktMinute)")

        var workingTrains = resetDwellTimes(newTrains)
        let trainsGrouped = groupTrainsByDirection(workingTrains, taktNodeId: taktNode.id)
        let isMainBatch = newTrains.first?.isMainTrain == true
        print("   📋 \(trainsGrouped.count) gruppi – modalità: \(isMainBatch ? "PRINCIPALE" : "SECONDARIO")")

        let calendar = Calendar.current

        if isMainBatch {
            var allResults: [Train] = []

            for var group in trainsGrouped {
                if Task.isCancelled { break }
                let sequence = group[0].stops.map { $0.stationId }
                guard let taktIdx = sequence.firstIndex(of: taktNode.id) else { continue }

                print("\n🔵 Gruppo MAIN: \(group.count) treni [Hub \(taktNode.id) @:\(taktMinute)]")

                for i in group.indices {
                    refreshTaktSchedule(
                        train: &group[i], hIdx: taktIdx, hNode: taktNode
                    )
                }

                allResults.append(contentsOf: group)
            }
            print("\n🏁 [TaktEngine] \(allResults.count) treni principali generati")
            return allResults

        } else {
            var allResults: [Train] = []

            for var group in trainsGrouped {
                if Task.isCancelled { break }
                let sequence = group[0].stops.map { $0.stationId }
                guard let taktIdx = sequence.firstIndex(of: taktNode.id) else { continue }
                print("\n🟡 Gruppo SEC: \(group.count) treni [Hub \(taktNode.id)]")

                for i in group.indices {
                    let train = group[i]
                    let mainHubTimes = findMainTrainHubTimes(
                        for: train, taktIdx: taktIdx, taktMinute: taktMinute,
                        existingTrains: existingTrains, taktNodeId: taktNode.id,
                        calendar: calendar
                    )

                    if let mainArr = mainHubTimes?.arr, let mainDep = mainHubTimes?.dep {
                        let secArr = mainArr.addingTimeInterval(-10 * 60)
                        let secDep = mainDep.addingTimeInterval(10 * 60)

                        group[i].stops[taktIdx].arrival = secArr
                        group[i].stops[taktIdx].departure =
                            (taktIdx < group[i].stops.count - 1) ? secDep : nil

                        print("   📐 \(train.name): Relativo a IC -> Arr \(formatScheduleTime(secArr)) Dep \(formatScheduleTime(secDep ?? secArr))")
                    } else {
                        print("   ⚠️ \(train.name): nessun principale esistente, uso offset standard")
                        let (arr, dep2) = calculateHubTimes(
                            for: train, hIdx: taktIdx, hNode: taktNode
                        )
                        group[i].stops[taktIdx].arrival = arr
                        group[i].stops[taktIdx].departure =
                            (taktIdx < group[i].stops.count - 1) ? dep2 : nil
                    }

                    var single = group[i]
                    let hubArr = single.stops[taktIdx].arrival!
                    let hubDep = single.stops[taktIdx].departure ?? hubArr

                    propagateBackward(
                        from: taktIdx, arrival: hubArr, train: &single
                    )
                    propagateForward(
                        from: taktIdx, departure: hubDep, train: &single
                    )
                    single.departureTime =
                        single.stops.first?.departure ?? single.stops.first?.arrival
                    group[i] = single
                }

                if let detect = conflictDetector {
                    var pathCache: [String: [Edge]] = [:]
                    let maxShift = 30
                    for i in group.indices {
                        var shifted = 0
                        while shifted < maxShift {
                            let conflicts = detect([group[i]], existingTrains, &pathCache)
                            if conflicts.isEmpty { break }
                            shifted += 1

                            if let oldArr = group[i].stops[taktIdx].arrival {
                                group[i].stops[taktIdx].arrival =
                                    calendar.date(byAdding: .minute, value: 1, to: oldArr)
                            }
                            if let oldDep = group[i].stops[taktIdx].departure {
                                group[i].stops[taktIdx].departure =
                                    calendar.date(byAdding: .minute, value: 1, to: oldDep)
                            }

                            var single = group[i]
                            let hArr = single.stops[taktIdx].arrival!
                            let hDep = single.stops[taktIdx].departure ?? hArr
                            propagateBackward(
                                from: taktIdx, arrival: hArr, train: &single
                            )
                            propagateForward(
                                from: taktIdx, departure: hDep, train: &single
                            )
                            single.departureTime =
                                single.stops.first?.departure
                                ?? single.stops.first?.arrival
                            group[i] = single
                        }
                        if shifted > 0 {
                            print("   🔧 \(group[i].name): +\(shifted) min shift per conflitti")
                        }
                    }
                }

                allResults.append(contentsOf: group)
            }
            print("\n🏁 [TaktEngine] \(allResults.count) treni secondari generati")
            return allResults
        }
    }

    // MARK: - Hub times

    /// Ritorna (arrivo, partenza) all'hub takt per un treno.
    public func taktHubTimes(
        train: Train, base: Date, calendar: Calendar = .current
    ) -> (Date, Date) {
        if train.isMainTrain {
            let isT1 = (train.number ?? 0) % 2 == 1
            let arr = calendar.date(
                byAdding: .minute, value: isT1 ? -2 : -3, to: base
            ) ?? base
            let dep = calendar.date(
                byAdding: .minute, value: isT1 ? 1 : 2, to: base
            ) ?? base
            return (arr, dep)
        } else {
            let isT1 = (train.number ?? 0) % 2 == 1
            let arr = calendar.date(
                byAdding: .minute, value: isT1 ? -20 : -10, to: base
            ) ?? base
            let dep = calendar.date(
                byAdding: .minute, value: isT1 ? 10 : 15, to: base
            ) ?? base
            return (arr, dep)
        }
    }

    func findMainTrainHubTimes(
        for secTrain: Train, taktIdx: Int, taktMinute: Int,
        existingTrains: [Train], taktNodeId: String, calendar: Calendar
    ) -> (arr: Date, dep: Date)? {
        guard let secDep = secTrain.departureTime else { return nil }
        let estTravel = Double(taktIdx) * 3.0 * 60.0
        let estHubTime = secDep.addingTimeInterval(estTravel)

        let mainAtHub = existingTrains.filter {
            $0.isMainTrain && $0.stops.contains(where: { $0.stationId == taktNodeId })
        }
        guard !mainAtHub.isEmpty else { return nil }

        return mainAtHub.compactMap { main -> (arr: Date, dep: Date, dist: TimeInterval)? in
            let mainSeq = main.stops.map { $0.stationId }
            guard let mainTIdx = mainSeq.firstIndex(of: taktNodeId) else { return nil }

            let mArr = main.stops[mainTIdx].arrival ?? main.stops[mainTIdx].departure
            let mDep = main.stops[mainTIdx].departure ?? main.stops[mainTIdx].arrival

            guard let finalArr = mArr, let finalDep = mDep else { return nil }

            return (finalArr, finalDep, abs(finalArr.timeIntervalSince(estHubTime)))
        }
        .sorted(by: { $0.dist < $1.dist })
        .first
        .map { (arr: $0.arr, dep: $0.dep) }
    }

    // MARK: - Schedule refresh

    public func refreshTaktSchedule(
        train: inout Train, hIdx: Int, hNode: Node
    ) {
        let (hArr, hDep) = calculateHubTimes(for: train, hIdx: hIdx, hNode: hNode)

        train.stops[hIdx].arrival = hArr
        train.stops[hIdx].departure = (hIdx < train.stops.count - 1) ? hDep : nil

        propagateBackward(from: hIdx, arrival: hArr, train: &train)
        propagateForward(from: hIdx, departure: hDep, train: &train)

        train.departureTime = train.stops.first?.departure ?? train.stops.first?.arrival
    }

    func calculateHubTimes(
        for train: Train, hIdx: Int, hNode: Node
    ) -> (Date, Date) {
        let calendar = Calendar.current
        let takt = hNode.taktMinutes ?? 0
        let isT1 = (train.number ?? 0) % 2 == 1

        let referenceTime = train.stops[hIdx].arrival ?? train.departureTime ?? Date()
        let ttToHub = (train.stops[hIdx].arrival == nil) ? Double(hIdx) * 180.0 : 0
        let estArrAtHub = referenceTime.addingTimeInterval(ttToHub)

        var anchorBase = calendar.date(
            bySetting: .minute, value: takt, of: estArrAtHub
        ) ?? estArrAtHub
        if anchorBase < estArrAtHub.addingTimeInterval(-1800) {
            anchorBase = calendar.date(byAdding: .hour, value: 1, to: anchorBase) ?? anchorBase
        }
        if anchorBase > estArrAtHub.addingTimeInterval(1800) {
            anchorBase = calendar.date(byAdding: .hour, value: -1, to: anchorBase) ?? anchorBase
        }

        let hArr: Date
        let hDep: Date

        if train.isMainTrain {
            if isT1 {
                hArr = calendar.date(
                    bySetting: .minute, value: (takt - 2 + 60) % 60, of: anchorBase
                ) ?? anchorBase
            } else {
                hArr = calendar.date(
                    bySetting: .minute, value: (takt - 3 + 60) % 60, of: anchorBase
                ) ?? anchorBase
            }
            let roundedArr = calendar.date(bySetting: .second, value: 0, of: hArr) ?? hArr
            hDep = roundedArr.addingTimeInterval((isT1 ? 3 : 5) * 60)
            return (roundedArr, hDep)
        } else {
            let arr = calendar.date(
                bySetting: .minute, value: (takt - 10 + 60) % 60, of: anchorBase
            ) ?? anchorBase
            let roundedArr = calendar.date(bySetting: .second, value: 0, of: arr) ?? arr
            var dep = calendar.date(
                bySetting: .minute, value: (takt + 10 + 60) % 60, of: anchorBase
            ) ?? anchorBase
            dep = calendar.date(bySetting: .second, value: 0, of: dep) ?? dep
            if dep < roundedArr {
                dep = calendar.date(byAdding: .hour, value: 1, to: dep) ?? dep
            }
            return (roundedArr, dep)
        }
    }

    func propagateBackward(from hIdx: Int, arrival: Date, train: inout Train) {
        guard hIdx > 0 else { return }
        let nodes = topology.nodes
        let edges = topology.edges
        var nextArrivalAtTarget = arrival
        for j in (0..<hIdx).reversed() {
            let idNext = train.stops[j + 1].stationId
            let idCur = train.stops[j].stationId
            let isStoppingAtNext = !train.stops[j + 1].isSkipped
            let isStartingAtCur = (j == 0)

            let tt = travelTimeCalculator.travelTimeBetweenNodes(
                from: idCur, to: idNext, train: train,
                nodes: nodes, edges: edges,
                isStarting: isStartingAtCur, isStopping: isStoppingAtNext
            )

            let depTime = nextArrivalAtTarget.addingTimeInterval(-1.0 * tt)
            train.stops[j].departure = Self.roundToBusinessSeconds(depTime)

            let dwellMinutes = train.stops[j].isSkipped
                ? 0.0 : Double(train.stops[j].minDwellTime)
            let extraDwell = train.stops[j].extraDwellTime
            let dwell = train.stops[j].isSkipped
                ? 0.0 : max(120.0, (dwellMinutes + extraDwell) * 60.0)

            let arrTime = (train.stops[j].departure ?? depTime).addingTimeInterval(-dwell)
            train.stops[j].arrival = (j > 0)
                ? Self.roundToBusinessSeconds(arrTime) : nil

            nextArrivalAtTarget = train.stops[j].arrival
                ?? (train.stops[j].departure!.addingTimeInterval(-60))
        }
    }

    func propagateForward(from hIdx: Int, departure: Date, train: inout Train) {
        guard hIdx < train.stops.count - 1 else { return }
        let nodes = topology.nodes
        let edges = topology.edges
        var currentDeparture = departure
        for j in (hIdx + 1)..<train.stops.count {
            let idPrev = train.stops[j - 1].stationId
            let idCur = train.stops[j].stationId
            let isStoppingAtCur = !train.stops[j].isSkipped
            let isStartingAtPrev = (j - 1 == 0) && !train.stops[j - 1].isSkipped

            let tt = travelTimeCalculator.travelTimeBetweenNodes(
                from: idPrev, to: idCur, train: train,
                nodes: nodes, edges: edges,
                isStarting: isStartingAtPrev, isStopping: isStoppingAtCur
            )

            let arrTime = currentDeparture.addingTimeInterval(tt)
            train.stops[j].arrival = Self.roundToBusinessSeconds(arrTime)

            let dwellMinutes = train.stops[j].isSkipped
                ? 0.0 : Double(train.stops[j].minDwellTime)
            let extraDwell = train.stops[j].extraDwellTime
            let dwell = train.stops[j].isSkipped
                ? 0.0 : max(120.0, (dwellMinutes + extraDwell) * 60.0)

            let depTime = (train.stops[j].arrival ?? arrTime).addingTimeInterval(dwell)
            train.stops[j].departure = (j < train.stops.count - 1)
                ? Self.roundToBusinessSeconds(depTime) : nil

            if let d = train.stops[j].departure {
                currentDeparture = d
            } else {
                currentDeparture = (train.stops[j].arrival ?? arrTime).addingTimeInterval(60)
            }
        }
    }

    // MARK: - Helpers

    func resolveTaktNode(preferredId: String?) -> Node? {
        if let id = preferredId, !id.isEmpty {
            let node = topology.nodes.first(where: { $0.id == id && $0.taktMinutes != nil })
            if node == nil {
                print("⚠️ Nodo Takt specificato '\(id)' non trovato o senza taktMinutes")
            }
            return node
        }
        return topology.nodes.first(where: { $0.taktMinutes != nil })
    }

    func resetDwellTimes(_ trains: [Train]) -> [Train] {
        var result = trains
        for i in result.indices {
            for j in result[i].stops.indices {
                result[i].stops[j].extraDwellTime = 0
            }
        }
        return result
    }

    func groupTrainsByDirection(_ trains: [Train], taktNodeId: String) -> [[Train]] {
        var groups: [[Train]] = []
        for train in trains {
            let seq = train.stops.map { $0.stationId }
            guard seq.contains(taktNodeId) else { continue }
            if let idx = groups.firstIndex(where: {
                $0.first?.stops.map { $0.stationId } == seq
            }) {
                groups[idx].append(train)
            } else {
                groups.append([train])
            }
        }
        return groups
    }

    public static func roundToBusinessSeconds(_ date: Date) -> Date {
        let seconds = date.timeIntervalSince1970
        let rounded = (seconds / 30.0).rounded() * 30.0
        return Date(timeIntervalSince1970: rounded)
    }

    private func formatScheduleTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
