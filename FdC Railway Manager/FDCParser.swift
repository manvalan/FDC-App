import Foundation

// Simple FDC parser adapted for common formats produced by FDC_SCHEDULER.
// The parser is defensive: it first tries JSON decoding into RailwayNetworkData-like structure,
// otherwise it falls back to a line-based text parser extracting stations, edges, trains and a minimal timetable.

struct FDCStation: Codable, Hashable {
    var id: String
    var name: String
}

struct FDCEdge: Codable, Hashable {
    var from: String
    var to: String
    var distance: Double?
}

struct FDCTrain: Codable, Hashable {
    var id: String
    var name: String
    var type: String?
    var maxSpeed: Int?
}

struct FDCTimetableEntry: Codable, Hashable {
    var trainId: String
    var stationId: String
    var time: String
}

struct FDCNetworkParsed {
    var name: String
    var stations: [FDCStation]
    var edges: [FDCEdge]
    var trains: [FDCTrain]
    var timetable: [FDCTimetableEntry]
}

enum FDCParserError: Error {
    case invalidData
    case empty
}

class FDCParser {
    /// Normalize many common time formats into "HH:MM" (24h) or return nil.
    /// Accepts: "08:30", "8:30", "8.30", "8,30", "0830", "830", "8", "8.5" (-> 8:30), "8.25" (-> 8:15), etc.
    static func normalizeTimeString(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        // Remove any non-digit and non separators except : . ,
        // But keep possible AM/PM (not implemented) - ignore letters
        // Find first token that looks like time
        // If contains letters like "Orario: 8.30" remove non relevant prefixes
        if let idx = s.lastIndex(of: ":") {
            // if there's a preceding label like "Orario: 8:30" try to take after last ':' only if there are digits after it
            let after = s[s.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if after.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil {
                // shorten to substring containing last two tokens around ':'
                s = String(s[s.index(after: idx)...])
            }
        }
        // Remove non-digit, non dot/comma/colon characters
        let allowed = CharacterSet(charactersIn: "0123456789:.,")
        s = s.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        if s.isEmpty { return nil }
        // If contains ':' treat as H:M
        if s.contains(":") {
            let parts = s.components(separatedBy: ":")
            if parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                if h >= 0 && h < 24 && m >= 0 && m < 60 {
                    return String(format: "%02d:%02d", h, m)
                }
            }
            return nil
        }
        // If contains '.' or ',' treat as decimal or separator
        if s.contains(".") || s.contains(",") {
            let sep = s.contains(".") ? "." : ","
            let comps = s.components(separatedBy: sep)
            if comps.count >= 2 {
                if let h = Int(comps[0]) {
                    // fractional or minutes
                    let fracPart = comps[1]
                    // If frac has 2 digits, treat as minutes
                    if fracPart.count == 2, let m = Int(fracPart), m >= 0 && m < 60 {
                        if h >= 0 && h < 24 { return String(format: "%02d:%02d", h, m) }
                    }
                    // else treat as fractional hours
                    if let frac = Double("0.") { /*noop*/ }
                    if let whole = Double(s.replacingOccurrences(of: ",", with: ".")) {
                        let hours = Int(floor(whole))
                        let minutes = Int(((whole - Double(hours)) * 60).rounded())
                        if hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60 {
                            return String(format: "%02d:%02d", hours, minutes)
                        }
                    }
                }
            }
        }
        // If only digits: interpret length
        let digits = s.filter { "0"..."9" ~= $0 }
        if digits.count >= 3 {
            // last two digits are minutes
            let minutesStr = String(digits.suffix(2))
            let hoursStr = String(digits.prefix(digits.count - 2))
            if let h = Int(hoursStr), let m = Int(minutesStr), h >= 0 && h < 24 && m >= 0 && m < 60 {
                return String(format: "%02d:%02d", h, m)
            }
        } else if digits.count > 0 {
            if let h = Int(digits), h >= 0 && h < 24 {
                return String(format: "%02d:00", h)
            }
        }
        // As last resort, try parse as Double hours
        if let d = Double(s.replacingOccurrences(of: ",", with: ".")) {
            let hours = Int(floor(d))
            let minutes = Int(((d - Double(hours)) * 60).rounded())
            if hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60 {
                return String(format: "%02d:%02d", hours, minutes)
            }
        }
        return nil
    }

    static func parse(data: Data) throws -> FDCNetworkParsed {
        // Try JSON decode to flexible containers
        let decoder = JSONDecoder()
        if let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []) {
            if let dict = jsonObj as? [String: Any] {
                // Try common keys
                let name = dict["name"] as? String ?? dict["networkName"] as? String ?? "Imported FDC"
                var stations: [FDCStation] = []
                var edges: [FDCEdge] = []
                var trains: [FDCTrain] = []
                var timetable: [FDCTimetableEntry] = []
                if let nodes = dict["nodes"] as? [[String: Any]] {
                    for n in nodes {
                        if let id = n["id"] as? String ?? n["name"] as? String {
                            let name = n["name"] as? String ?? id
                            stations.append(FDCStation(id: id.replacingOccurrences(of: " ", with: "_"), name: name))
                        }
                    }
                }
                if let edgesArr = dict["edges"] as? [[String: Any]] {
                    for e in edgesArr {
                        if let from = e["from"] as? String, let to = e["to"] as? String {
                            let dist = e["distance"] as? Double
                            edges.append(FDCEdge(from: from.replacingOccurrences(of: " ", with: "_"), to: to.replacingOccurrences(of: " ", with: "_"), distance: dist))
                        }
                    }
                }
                if let trainsArr = dict["trains"] as? [[String: Any]] {
                    for t in trainsArr {
                        let id = t["id"] as? String ?? t["name"] as? String ?? UUID().uuidString
                        let name = t["name"] as? String ?? id
                        let type = t["type"] as? String
                        let maxSpeed = t["maxSpeed"] as? Int
                        trains.append(FDCTrain(id: id, name: name, type: type, maxSpeed: maxSpeed))
                    }
                }
                if let timetableArr = dict["timetable"] as? [[String: Any]] {
                    for e in timetableArr {
                        if let train = e["train"] as? String, let station = e["station"] as? String, let time = e["time"] as? String {
                            timetable.append(FDCTimetableEntry(trainId: train, stationId: station, time: time))
                        }
                    }
                }
                // If nothing found, fall back to text parsing
                if stations.isEmpty && edges.isEmpty {
                    // fallthrough to text parsing
                } else {
                    return FDCNetworkParsed(name: name, stations: stations, edges: edges, trains: trains, timetable: timetable)
                }
            }
        }
        // Fallback text parsing
        guard let text = String(data: data, encoding: .utf8) else { throw FDCParserError.invalidData }
        let lines = text.components(separatedBy: CharacterSet.newlines)
        var stations: [FDCStation] = []
        var edges: [FDCEdge] = []
        var trains: [FDCTrain] = []
        var timetable: [FDCTimetableEntry] = []
        var seenStationIds = Set<String>()
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            // Station lines like: STN: Milano Centrale or Stazione: Milano
            if trimmed.lowercased().contains("stazione") || trimmed.lowercased().contains("station") || trimmed.lowercased().hasPrefix("stn") {
                // extract after ':'
                if let idx = trimmed.firstIndex(of: ":") {
                    let name = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
                    let id = name.replacingOccurrences(of: " ", with: "_")
                    if !seenStationIds.contains(id) {
                        seenStationIds.insert(id)
                        stations.append(FDCStation(id: id, name: name))
                    }
                }
            }
            // Edge like: A -> B
            if trimmed.contains("->") || trimmed.contains("→") || trimmed.contains(" - ") {
                let separators = ["->","→"," - ","—","–"]
                for sep in separators {
                    if trimmed.contains(sep) {
                        let parts = trimmed.components(separatedBy: sep)
                        if parts.count >= 2 {
                            let from = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                            let to = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                            let fid = from.replacingOccurrences(of: " ", with: "_")
                            let tid = to.replacingOccurrences(of: " ", with: "_")
                            if !seenStationIds.contains(fid) { seenStationIds.insert(fid); stations.append(FDCStation(id: fid, name: from)) }
                            if !seenStationIds.contains(tid) { seenStationIds.insert(tid); stations.append(FDCStation(id: tid, name: to)) }
                            edges.append(FDCEdge(from: fid, to: tid, distance: nil))
                        }
                        break
                    }
                }
            }
            // Train line heuristic: "Treno:" or "Train:" or lines starting with TID
            if trimmed.lowercased().contains("treno") || trimmed.lowercased().contains("train") {
                // naive split
                let comps = trimmed.components(separatedBy: CharacterSet(charactersIn: ":|-") )
                if comps.count >= 2 {
                    let name = comps[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let id = name.replacingOccurrences(of: " ", with: "_")
                    trains.append(FDCTrain(id: id, name: name, type: nil, maxSpeed: nil))
                }
            }
            // Timetable heuristic: contains "Orario" or "Time"
            if trimmed.lowercased().contains("orario") || trimmed.lowercased().contains("time") {
                // try parse pattern: Treno: NAME | Stazione: NAME | Orario: HH.MM
                let comps = trimmed.components(separatedBy: "|")
                if comps.count >= 3 {
                    let trainPart = comps[0]; let stationPart = comps[1]; let timePart = comps[2]
                    let train = trainPart.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    let station = stationPart.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    let time = timePart.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                    let tid = train.replacingOccurrences(of: " ", with: "_")
                    let sid = station.replacingOccurrences(of: " ", with: "_")
                    timetable.append(FDCTimetableEntry(trainId: tid, stationId: sid, time: time))
                }
            }
        }
        if stations.isEmpty && edges.isEmpty && trains.isEmpty {
            throw FDCParserError.empty
        }
        return FDCNetworkParsed(name: "Imported FDC", stations: stations, edges: edges, trains: trains, timetable: timetable)
    }
}
