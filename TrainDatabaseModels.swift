import Foundation
import SwiftUI
import Combine

// MARK: - Train Database Models

struct TrainDatabaseEntry: Codable, Identifiable {
    let costruttore: String
    let nome: String
    let tipo: String
    let specifiche: TrainSpecifiche
    let fisica: TrainFisica
    let fileImmagine: String?
    let assetName: String?
    
    var id: String { nome }
    
    enum CodingKeys: String, CodingKey {
        case costruttore, nome, tipo, specifiche, fisica
        case fileImmagine = "file_immagine"
        case assetName = "asset_name"
    }
}

struct TrainSpecifiche: Codable {
    let velocitaMaxKmh: Double
    let massaTonnellate: Double
    let potenzaKw: Double
    
    enum CodingKeys: String, CodingKey {
        case velocitaMaxKmh = "velocita_max_kmh"
        case massaTonnellate = "massa_tonnellate"
        case potenzaKw = "potenza_kw"
    }
}

struct TrainFisica: Codable {
    let accelerazioneMS2: Double
    let frenaturaServizioMS2: Double
    let frenaturaEmergenzaMS2: Double
    let coefficienteAderenza: Double
    
    enum CodingKeys: String, CodingKey {
        case accelerazioneMS2 = "accelerazione_m_s2"
        case frenaturaServizioMS2 = "frenatura_servizio_m_s2"
        case frenaturaEmergenzaMS2 = "frenatura_emergenza_m_s2"
        case coefficienteAderenza = "coefficiente_aderenza"
    }
}

// MARK: - Train Database Manager

@MainActor
class TrainDatabaseManager: ObservableObject {
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
    
    /// Crea un Vehicle dall'entry del database
    func createVehicle(from entry: TrainDatabaseEntry) -> Vehicle {
        Vehicle(
            name: entry.nome,
            model: entry.tipo,
            length: 200, // Default, può essere calcolato dalla massa
            maxSpeed: entry.specifiche.velocitaMaxKmh,
            acceleration: entry.fisica.accelerazioneMS2,
            deceleration: entry.fisica.frenaturaServizioMS2,
            imageName: entry.assetName
        )
    }
}

// MARK: - Train Database Picker View

struct TrainDatabasePickerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var database = TrainDatabaseManager.shared
    @Environment(\.dismiss) var dismiss
    
    let onSelect: (TrainDatabaseEntry) -> Void
    
    @State private var searchText = ""
    @State private var selectedManufacturer: String?
    
    private var manufacturers: [String] {
        Array(Set(database.trains.map { $0.costruttore })).sorted()
    }
    
    private var filteredTrains: [TrainDatabaseEntry] {
        var result = database.trains
        
        if let manufacturer = selectedManufacturer {
            result = result.filter { $0.costruttore == manufacturer }
        }
        
        if !searchText.isEmpty {
            result = result.filter { train in
                train.nome.lowercased().contains(searchText.lowercased()) ||
                train.tipo.lowercased().contains(searchText.lowercased())
            }
        }
        
        return result.sorted { $0.nome < $1.nome }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(appState.theme.medium)
                    TextField("Cerca treno...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(appState.theme.backgroundSecondary)
                
                // Manufacturer Filter
                if !manufacturers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterButton(title: "Tutti", manufacturer: nil)
                            
                            ForEach(manufacturers, id: \.self) { manufacturer in
                                filterButton(title: manufacturer, manufacturer: manufacturer)
                            }
                        }
                        .padding()
                    }
                    .background(appState.theme.surface)
                }
                
                Divider()
                
                // Train List
                if filteredTrains.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 60))
                            .foregroundColor(appState.theme.medium.opacity(0.3))
                        Text("Nessun treno trovato")
                            .font(.headline)
                            .foregroundColor(appState.theme.medium)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTrains) { train in
                                TrainDatabaseCard(train: train) {
                                    onSelect(train)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(appState.theme.background)
            .navigationTitle("Database Treni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
    
    private func filterButton(title: String, manufacturer: String?) -> some View {
        Button(action: {
            selectedManufacturer = manufacturer
        }) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedManufacturer == manufacturer ? appState.theme.accent : appState.theme.backgroundSecondary)
                .foregroundColor(selectedManufacturer == manufacturer ? .white : appState.theme.dark)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Train Database Card

struct TrainDatabaseCard: View {
    @EnvironmentObject var appState: AppState
    let train: TrainDatabaseEntry
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Image
                if let assetName = train.assetName, let _ = UIImage(named: assetName) {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "tram.fill")
                        .font(.largeTitle)
                        .foregroundColor(appState.theme.accent)
                        .frame(width: 100, height: 70)
                        .background(appState.theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(train.nome)
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    
                    Text(train.tipo)
                        .font(.subheadline)
                        .foregroundColor(appState.theme.medium)
                    
                    HStack(spacing: 12) {
                        Label("\(Int(train.specifiche.velocitaMaxKmh)) km/h", systemImage: "speedometer")
                        Label("\(String(format: "%.2f", train.fisica.accelerazioneMS2)) m/s²", systemImage: "arrow.up.right")
                    }
                    .font(.caption)
                    .foregroundColor(appState.theme.accent)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(appState.theme.medium)
            }
            .padding()
            .background(appState.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
