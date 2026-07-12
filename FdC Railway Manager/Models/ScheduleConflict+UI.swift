import Foundation

extension ScheduleConflict {
    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let start = formatter.string(from: timeStart)
        let end = formatter.string(from: timeEnd)

        if locationType == .routing {
            return "instradamento_non_consentito_fmt".localizedFormat(trainAName, locationName)
        }

        let typeStr: String = {
            if locationId.hasPrefix("STATION_GLOBAL") { return "Stazione (Totale Binari)" }
            if locationId.hasPrefix("TRACK") { return "Binario Specifico" }
            if locationId.hasPrefix("SEGMENT") { return "Tratta / Segmento" }
            return "Risorsa"
        }()

        return String(
            format: "conflitto_capacita_fmt".localized,
            trainAName, trainBName, locationName, typeStr, capacity, start, end
        )
    }
}
