import Foundation

/// Risultato diagnostico per il posizionamento Takt di un singolo treno.
struct TaktDiagnosticEntry: Identifiable {
    let id: UUID
    let trainName: String
    let trainNumber: Int?
    let isMainTrain: Bool
    
    /// Orario di arrivo all'hub Takt
    let hubArrival: Date?
    /// Orario di partenza dall'hub Takt
    let hubDeparture: Date?
    /// Minuto Takt configurato nell'hub (es. :00, :30)
    let taktMinute: Int
    /// Distanza in minuti dall'arrivo al minuto Takt
    let deltaFromTaktMinute: Double
    /// Nome della stazione hub
    let hubStationName: String
    
    /// Stato della verifica
    enum Status: String {
        case ok = "✅ OK"
        case warning = "⚠️ Marginale"
        case conflict = "❌ Conflitto"
        case noHub = "⏭️ No Hub"
    }
    let status: Status
    
    /// Descrizione del problema o suggerimento
    let suggestion: String?
    
    /// Indica se il treno si sovrappone con un treno principale all'hub
    let overlapsMainTrain: Bool
}

/// Motore dedicato alla logica di allineamento Taktfahrplan e diagnostica.
final class TaktEngine {
    private let network: RailwayNetwork
    private let kinematicCalculator: KinematicCalculator
    
    init(network: RailwayNetwork, kinematicCalculator: KinematicCalculator) {
        self.network = network
        self.kinematicCalculator = kinematicCalculator
    }
    
    // MARK: - Takt Alignment
    
    /// Calcola l'orario di partenza allineato al minuto Takt.
    func calculateAlignedStartTime(startTime: Date, stationSequence: [String], taktStationId: String, train: Train, isReturn: Bool) -> Date? {
        let sequence = isReturn ? Array(stationSequence.reversed()) : stationSequence
        guard sequence.count >= 2 else { return nil }
        
        let targetStation: (String, Int)?
        if !taktStationId.isEmpty, let node = network.nodes.first(where: { $0.id == taktStationId }), let takt = node.taktMinutes {
            targetStation = (taktStationId, takt)
        } else {
            targetStation = findFirstTaktStation(in: sequence)
        }
        
        guard let firstTakt = targetStation else { return nil }
        
        let travelMinutes = kinematicCalculator.travelMinutesToStation(firstTakt.0, in: sequence, train: train)
        
        // Applica l'allineamento
        let targetMinute = (Double(firstTakt.1) - travelMinutes + 3600.0)
        let alignedMinute = Int(targetMinute.rounded()) % 60
        
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: startTime)
        comps.minute = alignedMinute
        return Calendar.current.date(from: comps)
    }
    
    func findFirstTaktStation(in sequence: [String]) -> (String, Int)? {
        for sid in sequence {
            if let node = network.nodes.first(where: { $0.id == sid }),
               let takt = node.taktMinutes {
                return (sid, takt)
            }
        }
        return nil
    }
    
    /// Calcola i suggerimenti Takt per ogni stazione con minuto Takt configurato.
    func calculateTaktSuggestions(stationSequence: [String]) -> [(stationId: String, stationName: String, taktMinute: Int, suggestedArrival: String, suggestedDeparture: String)] {
        var suggestions: [(String, String, Int, String, String)] = []
        for stationId in stationSequence {
            guard let station = network.nodes.first(where: { $0.id == stationId }),
                  let taktMinute = station.taktMinutes else { continue }
            let arrS = (taktMinute - 15 + 60) % 60
            let arrE = (taktMinute - 5 + 60) % 60
            let depS = (taktMinute + 5) % 60
            let depE = (taktMinute + 15) % 60
            suggestions.append((stationId, station.name, taktMinute,
                                 String(format: ":%02d-:%02d", arrS, arrE),
                                 String(format: ":%02d-:%02d", depS, depE)))
        }
        return suggestions
    }
    
    // MARK: - Diagnostics
    
    /// Esegue la validazione del posizionamento Takt per un set di treni.
    func validateTaktPlacement(trains: [Train], taktStationId: String) -> [TaktDiagnosticEntry] {
        guard !trains.isEmpty else { return [] }
        
        let taktNodes = network.nodes.filter { $0.taktMinutes != nil }
        guard let hubNode = taktNodes.first(where: { $0.id == taktStationId }) ?? taktNodes.first else {
            return []
        }
        
        let hubName = hubNode.name ?? hubNode.id
        guard let taktMinute = hubNode.taktMinutes else { return [] }
        
        let calendar = Calendar.current
        let mainTrainWindows: [(arrival: Date, departure: Date, name: String)] = trains
            .filter { $0.isMainTrain }
            .compactMap { train in
                guard let hubStop = train.stops.first(where: { $0.stationId == hubNode.id }),
                      let arr = hubStop.arrival else { return nil }
                let dep = hubStop.departure ?? arr.addingTimeInterval(180)
                return (arr, dep, train.name)
            }
        
        var diagnostics: [TaktDiagnosticEntry] = []
        
        for train in trains {
            guard let hubStop = train.stops.first(where: { $0.stationId == hubNode.id }) else {
                diagnostics.append(TaktDiagnosticEntry(
                    id: train.id, trainName: train.name, trainNumber: train.number,
                    isMainTrain: train.isMainTrain, hubArrival: nil, hubDeparture: nil,
                    taktMinute: taktMinute, deltaFromTaktMinute: 0, hubStationName: hubName,
                    status: .noHub, suggestion: "Il treno non transita per l'hub Takt \(hubName)",
                    overlapsMainTrain: false))
                continue
            }
            
            let hubArr = hubStop.arrival
            let hubDep = hubStop.departure
            
            let delta: Double
            if let arr = hubArr {
                let arrMinute = calendar.component(.minute, from: arr)
                let rawDelta = Double(arrMinute - taktMinute)
                delta = rawDelta > 30 ? rawDelta - 60 : (rawDelta < -30 ? rawDelta + 60 : rawDelta)
            } else {
                delta = 0
            }
            
            var overlaps = false
            var overlapDetail: String? = nil
            if !train.isMainTrain, let arr = hubArr {
                let dep = hubDep ?? arr.addingTimeInterval(600)
                for mw in mainTrainWindows {
                    if arr < mw.departure && dep > mw.arrival {
                        overlaps = true
                        overlapDetail = "Sovrapposizione con \(mw.name) (\(formatTime(mw.arrival))-\(formatTime(mw.departure)))"
                        break
                    }
                }
            }
            
            let status: TaktDiagnosticEntry.Status
            let suggestion: String?
            
            if train.isMainTrain {
                if abs(delta) <= 3 { status = .ok; suggestion = nil }
                else if abs(delta) <= 5 { status = .warning; suggestion = "Arrivo a \(String(format: "%.0f", delta)) min dal Takt, ideale ≤3 min" }
                else { status = .conflict; suggestion = "Arrivo a \(String(format: "%.0f", delta)) min dal Takt! Verificare allineamento." }
            } else {
                if overlaps { status = .conflict; suggestion = overlapDetail }
                else if abs(delta) <= 8 { status = .warning; suggestion = "Treno secondario troppo vicino al minuto Takt (Δ=\(String(format: "%.0f", delta))min). Buffer consigliato ≥10 min." }
                else { status = .ok; suggestion = nil }
            }
            
            diagnostics.append(TaktDiagnosticEntry(
                id: train.id, trainName: train.name, trainNumber: train.number,
                isMainTrain: train.isMainTrain, hubArrival: hubArr, hubDeparture: hubDep,
                taktMinute: taktMinute, deltaFromTaktMinute: delta, hubStationName: hubName,
                status: status, suggestion: suggestion, overlapsMainTrain: overlaps))
        }
        
        return diagnostics
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}
