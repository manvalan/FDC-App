import Foundation
import Combine

@MainActor
final class TrainDatabaseManager: ObservableObject {
    static let shared = TrainDatabaseManager()

    @Published private(set) var trains: [TrainDatabaseEntry] = []
    @Published private(set) var isLoaded = false

    private init() {
        loadDatabase()
    }

    func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "TrainDatabase", withExtension: "json") else {
            print("⚠️ TrainDatabase.json not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            trains = try decoder.decode([TrainDatabaseEntry].self, from: data)
            isLoaded = true
            print("✅ Loaded \(trains.count) trains from database")
        } catch {
            print("❌ Error loading train database: \(error)")
        }
    }

    func getTrain(byName name: String) -> TrainDatabaseEntry? {
        trains.first { $0.nome.lowercased().contains(name.lowercased()) }
    }

    func getTrainsByManufacturer(_ manufacturer: String) -> [TrainDatabaseEntry] {
        trains.filter { $0.costruttore.lowercased() == manufacturer.lowercased() }
    }

    func getTrainsByType(_ type: String) -> [TrainDatabaseEntry] {
        trains.filter { $0.tipo.lowercased().contains(type.lowercased()) }
    }

    func createVehicle(from entry: TrainDatabaseEntry) -> RailwayVehicle {
        RailwayVehicle(
            name: entry.nome,
            model: entry.tipo,
            length: 200,
            maxSpeed: entry.specifiche.velocitaMaxKmh,
            acceleration: entry.fisica.accelerazioneMS2,
            deceleration: entry.fisica.frenaturaServizioMS2,
            imageName: entry.assetName
        )
    }
}
