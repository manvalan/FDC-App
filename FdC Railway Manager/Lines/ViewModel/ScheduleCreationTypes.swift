import Foundation

/// Modalità di generazione dell'orario: corsa singola, cadenzata o Taktfahrplan.
enum ScheduleMode: String, CaseIterable, Identifiable {
    case single = "single_trip"
    case cadenced = "cadenced_trip"
    case taktfahrplan = "taktfahrplan"
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .single:        return "single_trip".localized
        case .cadenced:      return "cadenced_trip".localized
        case .taktfahrplan:  return "Taktfahrplan"
        }
    }
}

/// Parità della numerazione treni: numeri pari o dispari.
enum NumberParity: String, CaseIterable, Identifiable {
    case even = "even"
    case odd  = "odd"
    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .even: return "even".localized
        case .odd:  return "odd".localized
        }
    }
}
