import Foundation

// MARK: - Train Database Models

public struct TrainDatabaseEntry: Codable, Identifiable {
    public let costruttore: String
    public let nome: String
    public let tipo: String
    public let specifiche: TrainSpecifiche
    public let fisica: TrainFisica
    public let fileImmagine: String?
    public let assetName: String?

    public var id: String { nome }

    enum CodingKeys: String, CodingKey {
        case costruttore, nome, tipo, specifiche, fisica
        case fileImmagine = "file_immagine"
        case assetName = "asset_name"
    }
}

public struct TrainSpecifiche: Codable {
    public let velocitaMaxKmh: Double
    public let massaTonnellate: Double
    public let potenzaKw: Double

    enum CodingKeys: String, CodingKey {
        case velocitaMaxKmh = "velocita_max_kmh"
        case massaTonnellate = "massa_tonnellate"
        case potenzaKw = "potenza_kw"
    }
}

public struct TrainFisica: Codable {
    public let accelerazioneMS2: Double
    public let frenaturaServizioMS2: Double
    public let frenaturaEmergenzaMS2: Double
    public let coefficienteAderenza: Double

    enum CodingKeys: String, CodingKey {
        case accelerazioneMS2 = "accelerazione_m_s2"
        case frenaturaServizioMS2 = "frenatura_servizio_m_s2"
        case frenaturaEmergenzaMS2 = "frenatura_emergenza_m_s2"
        case coefficienteAderenza = "coefficiente_aderenza"
    }
}
