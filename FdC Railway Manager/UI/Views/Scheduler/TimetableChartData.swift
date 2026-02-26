import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
import Charts

struct TimetableChartData: Identifiable {
    let id = UUID()
    let train: String
    let station: String
    let time: Double // minutes since midnight
    var date: Date {
        let start = Calendar.current.startOfDay(for: Date())
        return Date(timeInterval: time * 60.0, since: start)
    }
    // Parsing semplice da testo (adatta secondo il formato reale)
    static func parse(from result: String) -> [TimetableChartData] {
        var data: [TimetableChartData] = []
        let lines = result.components(separatedBy: "\n")
        for line in lines {
            // Esempio: "Treno: Frecciarossa 9600 | Stazione: Milano | Orario: 8.00"
            if line.contains("Treno:") && line.contains("Stazione:") && line.contains("Orario:") {
                let comps = line.components(separatedBy: "|")
                if comps.count == 3 {
                    let train = comps[0].replacingOccurrences(of: "Treno:", with: "").trimmingCharacters(in: .whitespaces)
                    let station = comps[1].replacingOccurrences(of: "Stazione:", with: "").trimmingCharacters(in: .whitespaces)
                    let timeStr = comps[2].replacingOccurrences(of: "Orario:", with: "").trimmingCharacters(in: .whitespaces)
                    if let norm = FDCParser.normalizeTimeString(timeStr) {
                        let parts = norm.split(separator: ":").map { Int($0) ?? 0 }
                        if parts.count == 2 {
                            let minutes = Double(parts[0] * 60 + parts[1])
                            data.append(TimetableChartData(train: train, station: station, time: minutes))
                        }
                    } else if let time = Double(timeStr.replacingOccurrences(of: ",", with: ".")) {
                        let hours = Int(floor(time))
                        let minutes = Int(((time - Double(hours)) * 60).rounded())
                        data.append(TimetableChartData(train: train, station: station, time: Double(hours * 60 + minutes)))
                    }
                }
            } else {
                // Fallback parsing
                let tokens = line.components(separatedBy: "|")
                var train = ""
                var station = ""
                var foundTimeToken: String? = nil
                for tok in tokens {
                    if tok.localizedCaseInsensitiveContains("treno") || tok.localizedCaseInsensitiveContains("train") {
                        train = tok.replacingOccurrences(of: "Treno:", with: "").replacingOccurrences(of: "Train:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if tok.localizedCaseInsensitiveContains("stazione") || tok.localizedCaseInsensitiveContains("station") {
                        station = tok.replacingOccurrences(of: "Stazione:", with: "").replacingOccurrences(of: "Station:", with: "").trimmingCharacters(in: .whitespaces)
                    } else if FDCParser.normalizeTimeString(tok) != nil {
                        foundTimeToken = tok.trimmingCharacters(in: .whitespaces)
                    }
                }
                if (train.isEmpty || station.isEmpty), tokens.count == 1 {
                    let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    if parts.count >= 3 {
                        train = parts.first ?? ""
                        station = parts.last ?? ""
                        for part in parts { if FDCParser.normalizeTimeString(part) != nil { foundTimeToken = part; break } }
                    }
                }
                if !train.isEmpty && !station.isEmpty, let ft = foundTimeToken, let tnorm = FDCParser.normalizeTimeString(ft) {
                    let parts = tnorm.split(separator: ":").map { Int($0) ?? 0 }
                    if parts.count == 2 {
                        let minutes = Double(parts[0] * 60 + parts[1])
                        data.append(TimetableChartData(train: train, station: station, time: minutes))
                    }
                }
            }
        }
        return data
    }
}
