import Foundation
import CoreLocation

/// Modulo "Swiss-AStar Rail Scheduler"
/// Implementazione di un motore di ricerca per la generazione di tracce orarie ferroviarie 
/// che evita conflitti, gestisce infrastrutture a binario singolo/doppio e rispetta vincoli Takt.

// MARK: - Modelli di Supporto

/// Rappresenta l'occupazione di una tratta (arco) in un intervallo temporale.
struct OccupazioneTratta: Hashable {
    let resId: String // "SEGMENT::A--B" o "STATION_GLOBAL::A"
    let intervallo: ClosedRange<Date>
    let direzione: String? // ID della stazione di destinazione (per binario doppio)
}

/// Vincolo "alla svizzera" per una stazione (finestre temporali prefissate).
struct VincoloSvizzero {
    let stazioneId: String
    let finestraArrivo: ClosedRange<Date>
    let finestraPartenza: ClosedRange<Date>
}

// MARK: - Core Scheduler

class RailSchedulerCore {
    
    struct SearchNode: Comparable {
        let stazioneId: String
        let tempoCorrente: Date
        let percorsoEseguito: [RelationStop]
        let costoStimato: TimeInterval // f(n) = g(n) + h(n)
        
        static func < (lhs: SearchNode, rhs: SearchNode) -> Bool {
            if lhs.costoStimato != rhs.costoStimato {
                return lhs.costoStimato < rhs.costoStimato
            }
            return lhs.tempoCorrente < rhs.tempoCorrente
        }
        
        static func == (lhs: SearchNode, rhs: SearchNode) -> Bool {
            return lhs.stazioneId == rhs.stazioneId && abs(lhs.tempoCorrente.timeIntervalSince(rhs.tempoCorrente)) < 1
        }
    }
    
    private let network: NetworkModel
    /// Mappa delle occupazioni indicizzata per risorsa (resId) per performance O(1) in ricerca risorsa.
    private var occupancyMap: [String: [OccupazioneTratta]]
    private let bufferSicurezza: TimeInterval = 120 // 2 minuti
    
    init(network: NetworkModel, occupancies: [OccupazioneTratta]) {
        self.network = network
        self.occupancyMap = [:]
        for occ in occupancies {
            self.occupancyMap[occ.resId, default: []].append(occ)
        }
    }
    
    func addOccupancies(_ newOccs: [OccupazioneTratta]) {
        for occ in newOccs {
            self.occupancyMap[occ.resId, default: []].append(occ)
        }
    }
    
    /// Estrae le occupazioni di tutti i treni presenti.
    static func extractOccupancies(from trains: [Train], network: NetworkModel) -> [OccupazioneTratta] {
        var all: [OccupazioneTratta] = []
        for t in trains {
            all.append(contentsOf: extractSingleTrainOccupancy(train: t, network: network))
        }
        return all
    }
    
    /// Estrae l'occupazione di un singolo treno.
    static func extractSingleTrainOccupancy(train: Train, network: NetworkModel) -> [OccupazioneTratta] {
        var occupancies: [OccupazioneTratta] = []
        var prevStop: RelationStop? = nil
        
        for stop in train.stops {
            // Occupazione Stazione
            if let arr = stop.arrival, let dep = stop.departure {
                occupancies.append(OccupazioneTratta(
                    resId: "STATION_GLOBAL::\(stop.stationId)",
                    intervallo: arr...dep,
                    direzione: nil
                ))
            }
            
            // Occupazione Tratta
            if let prev = prevStop, let dep = prev.departure, let arr = stop.arrival {
                let s1 = prev.stationId
                let s2 = stop.stationId
                
                // Cerchiamo gli archi che collegano le due stazioni
                let pathEdges = network.edges.filter { 
                    ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1)
                }
                
                var currentTime = dep
                let totalDist = pathEdges.reduce(0.0) { $0 + $1.distance }
                let totalTime = arr.timeIntervalSince(dep)
                let avgSpeed = totalTime > 0 ? (totalDist / totalTime * 3600.0) : 0.0
                
                for edge in pathEdges {
                    let transitTime = avgSpeed > 0 ? (edge.distance / avgSpeed * 3600.0) : 0.0
                    let exitTime = currentTime.addingTimeInterval(transitTime)
                    let s1Id = edge.from < edge.to ? edge.from : edge.to
                    let s2Id = edge.from < edge.to ? edge.to : edge.from
                    
                    occupancies.append(OccupazioneTratta(
                        resId: "SEGMENT::\(s1Id)--\(s2Id)",
                        intervallo: currentTime...exitTime,
                        direzione: edge.to
                    ))
                    currentTime = exitTime
                }
            }
            prevStop = stop
        }
        return occupancies
    }
    
    /// Verifica se una tratta è libera in un determinato intervallo.
    func isTrattaLibera(edge: Edge, tInizio: Date, tFine: Date, verso: String) -> Bool {
        let s1 = edge.from < edge.to ? edge.from : edge.to
        let s2 = edge.from < edge.to ? edge.to : edge.from
        let segId = "SEGMENT::\(s1)--\(s2)"
        
        let intervalloRichiesto = tInizio.addingTimeInterval(-bufferSicurezza)...tFine.addingTimeInterval(bufferSicurezza)
        
        guard let matchingOccupancies = occupancyMap[segId] else { return true }
        
        for occ in matchingOccupancies {
            if occ.intervallo.overlaps(intervalloRichiesto) {
                if edge.trackType == .single || edge.trackType == .regional {
                    // Binario unico: conflitto sempre, indipendentemente dalla direzione
                    // (sia direzioni opposte che stessa direzione con overlap temporale)
                    return false
                } else {
                    // Binario doppio: conflitto solo se stessa direzione
                    if occ.direzione == verso {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    /// Algoritmo A* Spazio-Temporale. Supporta ricerca avanti o indietro (bidirezionale).
    func planAStar(
        train: Train,
        stationSequence: [String],
        startTime: Date,
        vincoliSvizzeri: [VincoloSvizzero] = [],
        isBackward: Bool = false
    ) -> [RelationStop]? {
        
        guard stationSequence.count >= 2 else { return nil }
        let goalStationId = stationSequence.last!
        
        // Mappa delle fermate originali per preservare binari, skip e minDwell
        let originalStopsMap = Dictionary(grouping: train.stops, by: { $0.stationId }).compactMapValues { $0.first }
        
        var openList: [SearchNode] = []
        
        let firstStId = stationSequence[0]
        let template0 = originalStopsMap[firstStId]
        
        let initialStop = isBackward ? 
            RelationStop(stationId: firstStId, minDwellTime: template0?.minDwellTime ?? 3, isSkipped: template0?.isSkipped ?? false, track: template0?.track, arrival: startTime, departure: nil) :
            RelationStop(stationId: firstStId, minDwellTime: template0?.minDwellTime ?? 3, isSkipped: template0?.isSkipped ?? false, track: template0?.track, arrival: nil, departure: startTime)

        let startNode = SearchNode(
            stazioneId: firstStId,
            tempoCorrente: startTime,
            percorsoEseguito: [initialStop],
            costoStimato: h(firstStId, goal: goalStationId)
        )
        openList.append(startNode)
        
        var nodesExpanded = 0
        let maxNodes = 10000
        
        while !openList.isEmpty && nodesExpanded < maxNodes {
            nodesExpanded += 1
            if isBackward {
                openList.sort { $0.tempoCorrente > $1.tempoCorrente } 
            } else {
                openList.sort()
            }
            let current = openList.removeFirst()
            
            if current.stazioneId == goalStationId {
                if !isBackward {
                    if let vincolo = vincoliSvizzeri.first(where: { $0.stazioneId == goalStationId }) {
                        if !vincolo.finestraArrivo.contains(current.tempoCorrente) { continue }
                    }
                }
                
                var finalStops = current.percorsoEseguito
                if let lastIdx = finalStops.indices.last {
                    if isBackward {
                        finalStops[lastIdx].departure = current.tempoCorrente
                        finalStops[lastIdx].arrival = nil
                    } else {
                        finalStops[lastIdx].arrival = current.tempoCorrente
                        finalStops[lastIdx].departure = nil
                    }
                }
                // Calcoliamo extraDwellTime per preservare le attese tattiche trovate da A*
                for i in 0..<finalStops.count {
                    if let arr = finalStops[i].arrival, let dep = finalStops[i].departure {
                        let totalDwell = dep.timeIntervalSince(arr) / 60.0
                        let extra = max(0, totalDwell - Double(finalStops[i].minDwellTime))
                        finalStops[i].extraDwellTime = extra
                    }
                }
                
                return finalStops
            }
            
            guard let seqIdx = stationSequence.firstIndex(of: current.stazioneId),
                  seqIdx + 1 < stationSequence.count else {
                continue
            }
            let nextInSequence = stationSequence[seqIdx + 1]
            let edges = network.edges.filter { 
                ($0.from == current.stazioneId && $0.to == nextInSequence) ||
                ($0.from == nextInSequence && $0.to == current.stazioneId)
            }
            
            for edge in edges {
                let vEffective = min(edge.maxSpeed, Int(train.maxSpeed))
                let travelTime = (edge.distance / Double(vEffective)) * 3600
                
                    let tTarget = isBackward ? current.tempoCorrente.addingTimeInterval(-travelTime) : current.tempoCorrente.addingTimeInterval(travelTime)
                
                // Vincoli Svizzeri intermedi
                if let vincolo = vincoliSvizzeri.first(where: { $0.stazioneId == nextInSequence }) {
                    if isBackward {
                        // Se andiamo indietro (verso l'origine), l'orario in cui 'lasciamo' la stazione precedente (partenza)
                        // deve essere compatibile con i vincoli di quella stazione.
                        if tTarget < vincolo.finestraPartenza.lowerBound { continue }
                    } else {
                        if tTarget > vincolo.finestraArrivo.upperBound { continue }
                    }
                }
                
                let tInizio = isBackward ? tTarget : current.tempoCorrente
                let tFine = isBackward ? current.tempoCorrente : tTarget
                
                if isTrattaLibera(edge: edge, tInizio: tInizio, tFine: tFine, verso: isBackward ? current.stazioneId : nextInSequence) {
                    var updatedStops = current.percorsoEseguito
                    if let lastIdx = updatedStops.indices.last {
                        if isBackward {
                            updatedStops[lastIdx].arrival = current.tempoCorrente
                        } else {
                            if let vincoloPartenza = vincoliSvizzeri.first(where: { $0.stazioneId == current.stazioneId }) {
                                if !vincoloPartenza.finestraPartenza.contains(current.tempoCorrente) { continue }
                            }
                            updatedStops[lastIdx].departure = current.tempoCorrente
                        }
                    }
                    
                    let template = originalStopsMap[nextInSequence]
                    let newStop = RelationStop(
                        stationId: nextInSequence,
                        minDwellTime: template?.minDwellTime ?? 3,
                        isSkipped: template?.isSkipped ?? false,
                        track: template?.track,
                        isManualTrack: template?.isManualTrack ?? false,
                        arrival: tTarget,
                        departure: tTarget
                    )
                    let heuristic = h(nextInSequence, goal: goalStationId)
                    
                    // COSTO: Per il backward usiamo la distanza temporale dall'ancora
                    let gCost = isBackward ? startTime.timeIntervalSince(tTarget) : tTarget.timeIntervalSince(startTime)
                    
                    let newNode = SearchNode(
                        stazioneId: nextInSequence,
                        tempoCorrente: tTarget,
                        percorsoEseguito: updatedStops + [newStop],
                        costoStimato: gCost + heuristic
                    )
                    openList.append(newNode)
                }
            }
            
            let tWait = isBackward ? current.tempoCorrente.addingTimeInterval(-60) : current.tempoCorrente.addingTimeInterval(60)
            if isStazioneLibera(stazioneId: current.stazioneId, at: tWait) {
                var canWait = true
                if let vincolo = vincoliSvizzeri.first(where: { $0.stazioneId == current.stazioneId }) {
                    if isBackward {
                        if tWait < vincolo.finestraPartenza.lowerBound { canWait = false }
                    } else {
                        if tWait > vincolo.finestraPartenza.upperBound { canWait = false }
                    }
                }
                if canWait {
                    let sostaNode = SearchNode(
                        stazioneId: current.stazioneId,
                        tempoCorrente: tWait,
                        percorsoEseguito: current.percorsoEseguito,
                        costoStimato: (isBackward ? 0 : tWait.timeIntervalSince(startTime)) + h(current.stazioneId, goal: goalStationId)
                    )
                    openList.append(sostaNode)
                }
            }
        }
        return nil
    }
    
    /// Pianifica un treno partendo da un'ancora Takt (Hub) e espandendo in entrambe le direzioni.
    func planTaktAnchored(
        train: Train,
        stationSequence: [String],
        anchorStationId: String,
        anchorArrivalTime: Date,
        anchorDepartureTime: Date,
        vincoliSvizzeri: [VincoloSvizzero]
    ) -> [RelationStop]? {
        
        guard let anchorIdx = stationSequence.firstIndex(of: anchorStationId) else { return nil }
        
        var forwardStops: [RelationStop]? = []
        var backwardStops: [RelationStop]? = []
        
        // 1. Parte Forward
        if anchorIdx < stationSequence.count - 1 {
            let forwardSeq = Array(stationSequence[anchorIdx..<stationSequence.count])
            forwardStops = planAStar(train: train, stationSequence: forwardSeq, startTime: anchorDepartureTime, vincoliSvizzeri: vincoliSvizzeri, isBackward: false)
        } else {
            forwardStops = [RelationStop(stationId: anchorStationId, arrival: anchorArrivalTime, departure: nil)]
        }
        
        // 2. Parte Backward
        if anchorIdx > 0 {
            let backwardSeq = Array(stationSequence[0...anchorIdx].reversed())
            backwardStops = planAStar(train: train, stationSequence: backwardSeq, startTime: anchorArrivalTime, vincoliSvizzeri: vincoliSvizzeri, isBackward: true)
        } else {
            backwardStops = [RelationStop(stationId: anchorStationId, arrival: nil, departure: anchorDepartureTime)]
        }
        
        guard let fStops = forwardStops, let bStops = backwardStops else { return nil }
        
        var merged: [RelationStop] = []
        if anchorIdx > 0 {
            let bStopsCorrected = Array(bStops.reversed())
            for i in 0..<(bStopsCorrected.count - 1) {
                merged.append(bStopsCorrected[i])
            }
        }
        
        let originalStopsMap = Dictionary(grouping: train.stops, by: { $0.stationId }).compactMapValues { $0.first }
        let template = originalStopsMap[anchorStationId]
        
        var anchorStop = RelationStop(
            stationId: anchorStationId,
            minDwellTime: template?.minDwellTime ?? 3,
            isSkipped: template?.isSkipped ?? false,
            track: template?.track,
            isManualTrack: template?.isManualTrack ?? false,
            arrival: anchorArrivalTime,
            departure: anchorDepartureTime
        )
        
        // Calcolo extraDwell per l'ancora
        let anchorTotalDwell = anchorDepartureTime.timeIntervalSince(anchorArrivalTime) / 60.0
        anchorStop.extraDwellTime = max(0, anchorTotalDwell - Double(anchorStop.minDwellTime))

        if anchorIdx == 0 { anchorStop.arrival = nil; anchorStop.extraDwellTime = 0 }
        if anchorIdx == stationSequence.count - 1 { anchorStop.departure = nil; anchorStop.extraDwellTime = 0 }
        merged.append(anchorStop)
        
        if anchorIdx < stationSequence.count - 1 {
            for i in 1..<fStops.count {
                merged.append(fStops[i])
            }
        }
        
        return merged
    }
    
    func isStazioneLibera(stazioneId: String, at time: Date) -> Bool {
        let resId = "STATION_GLOBAL::\(stazioneId)"
        guard let matchingOccupancies = occupancyMap[resId] else { return true }
        let capacity = network.nodes.first(where: { $0.id == stazioneId })?.platforms ?? 2
        let count = matchingOccupancies.filter { $0.intervallo.contains(time) }.count
        return count < capacity
    }
    
    static func estimateDistanceBetween(fromId: String, toId: String, network: NetworkModel) -> Double {
        guard let n1 = network.nodes.first(where: { $0.id == fromId }),
              let n2 = network.nodes.first(where: { $0.id == toId }) else { return 0 }
        let l1 = CLLocation(latitude: n1.latitude ?? 0, longitude: n1.longitude ?? 0)
        let l2 = CLLocation(latitude: n2.latitude ?? 0, longitude: n2.longitude ?? 0)
        return l1.distance(from: l2) / 1000.0
    }
    
    private func h(_ id: String, goal: String) -> TimeInterval {
        let dist = RailSchedulerCore.estimateDistanceBetween(fromId: id, toId: goal, network: network)
        return (dist / 160.0) * 3600
    }
}
