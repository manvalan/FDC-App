import SwiftUI

// MARK: - Train Model Data Structures

struct TrainModel: Codable, Identifiable {
    var id: String { nome }
    
    let costruttore: String
    let nome: String
    let tipo: String
    let specifiche: Specifiche
    let fisica: Fisica
    let file_immagine: String?
    let asset_name: String?
    
    struct Specifiche: Codable {
        let velocita_max_kmh: Int
        let massa_tonnellate: Double
        let potenza_kw: Int
    }
    
    struct Fisica: Codable {
        let accelerazione_m_s2: Double
        let frenatura_servizio_m_s2: Double
        let frenatura_emergenza_m_s2: Double
        let coefficiente_aderenza: Double
    }
    
    /// Converti TrainModel in Vehicle per l'uso nel sistema
    func toVehicle(name: String? = nil) -> Vehicle {
        Vehicle(
            name: name ?? self.nome,
            model: self.tipo,
            length: 200,  // Default length, potrebbe essere aggiunto al DB
            maxSpeed: Double(specifiche.velocita_max_kmh),
            acceleration: fisica.accelerazione_m_s2,
            deceleration: fisica.frenatura_servizio_m_s2,
            imageName: asset_name
        )
    }
}

// MARK: - Train Model Selector View

/// Vista avanzata per la selezione del modello di treno con suggerimenti intelligenti
struct TrainModelSelectorView: View {
    @Binding var selectedModel: TrainModel?
    let lineCharacteristics: LineCharacteristics
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedManufacturer: String?
    @State private var selectedType: TrainType?
    @State private var sortOrder: SortOrder = .recommendation
    
    private let trainDatabase: TrainDatabase
    
    enum SortOrder: String, CaseIterable {
        case recommendation = "Raccomandati"
        case speed = "Velocità"
        case acceleration = "Accelerazione"
        case name = "Nome"
    }
    
    init(selectedModel: Binding<TrainModel?>, lineCharacteristics: LineCharacteristics) {
        self._selectedModel = selectedModel
        self.lineCharacteristics = lineCharacteristics
        self.trainDatabase = TrainDatabase.shared
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Filters & Sort
            filtersSection
            
            Divider()
            
            // Models List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredAndSortedModels) { model in
                        TrainModelCard(
                            model: model,
                            score: trainDatabase.calculateSuitabilityScore(
                                model: model,
                                for: lineCharacteristics
                            ),
                            isSelected: selectedModel?.id == model.id,
                            onSelect: {
                                selectedModel = model
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Selezione Modello Treno")
                    .font(.title2.bold())
                Text("\(filteredAndSortedModels.count) modelli disponibili")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Chiudi") {
                dismiss()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
    }
    
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Cerca modello...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            // Filters Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Manufacturer filter
                    Menu {
                        Button("Tutti") {
                            selectedManufacturer = nil
                        }
                        ForEach(trainDatabase.manufacturers, id: \.self) { manufacturer in
                            Button(manufacturer) {
                                selectedManufacturer = manufacturer
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedManufacturer ?? "Costruttore")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedManufacturer != nil ? Color.blue : Color.secondary.opacity(0.2))
                        .foregroundColor(selectedManufacturer != nil ? .white : .primary)
                        .cornerRadius(16)
                    }
                    
                    // Type filter
                    Menu {
                        Button("Tutti") {
                            selectedType = nil
                        }
                        ForEach(TrainType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                selectedType = type
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedType?.rawValue ?? "Tipologia")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedType != nil ? Color.blue : Color.secondary.opacity(0.2))
                        .foregroundColor(selectedType != nil ? .white : .primary)
                        .cornerRadius(16)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // Sort order
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button(action: { sortOrder = order }) {
                            Text(order.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(sortOrder == order ? Color.blue : Color.clear)
                                .foregroundColor(sortOrder == order ? .white : .primary)
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
    }
    
    private var filteredAndSortedModels: [TrainModel] {
        var models = trainDatabase.allModels
        
        // Apply search
        if !searchText.isEmpty {
            models = models.filter {
                $0.nome.localizedCaseInsensitiveContains(searchText) ||
                $0.costruttore.localizedCaseInsensitiveContains(searchText) ||
                $0.tipo.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply manufacturer filter
        if let manufacturer = selectedManufacturer {
            models = models.filter { $0.costruttore == manufacturer }
        }
        
        // Apply type filter
        if let type = selectedType {
            models = models.filter { trainDatabase.inferTrainType(from: $0) == type }
        }
        
        // Apply sort
        switch sortOrder {
        case .recommendation:
            models = models.sorted { model1, model2 in
                let score1 = trainDatabase.calculateSuitabilityScore(model: model1, for: lineCharacteristics)
                let score2 = trainDatabase.calculateSuitabilityScore(model: model2, for: lineCharacteristics)
                return score1 > score2
            }
        case .speed:
            models = models.sorted { $0.specifiche.velocita_max_kmh > $1.specifiche.velocita_max_kmh }
        case .acceleration:
            models = models.sorted { $0.fisica.accelerazione_m_s2 > $1.fisica.accelerazione_m_s2 }
        case .name:
            models = models.sorted { $0.nome < $1.nome }
        }
        
        return models
    }
}

// MARK: - Train Model Card

struct TrainModelCard: View {
    let model: TrainModel
    let score: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Image
                Group {
                    if let assetName = model.asset_name,
                       !assetName.isEmpty,
                       let _ = UIImage(named: assetName) {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "train.side.front.car")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                }
                .frame(width: 80, height: 60)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .clipped()
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(model.nome)
                            .font(.headline)
                        
                        if score > 80 {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Text("\(model.costruttore) • \(model.tipo)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Label("\(model.specifiche.velocita_max_kmh) km/h", systemImage: "speedometer")
                            .font(.caption)
                        Label(String(format: "%.2f m/s²", model.fisica.accelerazione_m_s2), systemImage: "arrow.up.right")
                            .font(.caption)
                        Label("\(Int(model.specifiche.massa_tonnellate)) t", systemImage: "scalemass")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Recommendation Score
                VStack(spacing: 4) {
                    CircularProgressView(progress: score / 100, color: scoreColor)
                        .frame(width: 50, height: 50)
                    Text("\(Int(score))%")
                        .font(.caption.bold())
                        .foregroundColor(scoreColor)
                    Text("Match")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var scoreColor: Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Supporting Types

struct LineCharacteristics {
    let totalDistance: Double  // km
    let averageStopDistance: Double  // km
    let numberOfStops: Int
    let maxLineSpeed: Double  // km/h
    let serviceType: TrainCategory
    let frequency: Int?  // minutes
    
    var isFrequentStops: Bool {
        averageStopDistance < 10
    }
    
    var isLongDistance: Bool {
        totalDistance > 100
    }
}

enum TrainType: String, CaseIterable {
    case regional = "Regionale"
    case intercity = "Intercity"
    case highSpeed = "Alta Velocità"
    case suburban = "Suburbano"
}

// MARK: - Train Database Manager

class TrainDatabase {
    static let shared = TrainDatabase()
    
    private(set) var allModels: [TrainModel] = []
    
    init() {
        loadDatabase()
    }
    
    private func loadDatabase() {
        guard let url = Bundle.main.url(forResource: "TrainDatabase", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let models = try? JSONDecoder().decode([TrainModel].self, from: data) else {
            print("⚠️ Failed to load TrainDatabase.json")
            return
        }
        
        allModels = models
        print("✅ Loaded \(allModels.count) train models from database")
    }
    
    var manufacturers: [String] {
        Array(Set(allModels.map { $0.costruttore })).sorted()
    }
    
    func inferTrainType(from model: TrainModel) -> TrainType {
        let speed = model.specifiche.velocita_max_kmh
        if speed >= 250 { return .highSpeed }
        if speed >= 200 { return .intercity }
        if speed >= 140 { return .regional }
        return .suburban
    }
    
    /// Calcola uno score di idoneità del modello per le caratteristiche della linea
    func calculateSuitabilityScore(model: TrainModel, for line: LineCharacteristics) -> Double {
        var score = 0.0
        
        // 1. Speed match (40 points max)
        let speedDiff = abs(Double(model.specifiche.velocita_max_kmh) - line.maxLineSpeed)
        let speedScore = max(0, 40 - speedDiff / 5)
        score += speedScore
        
        // 2. Acceleration for frequent stops (30 points max)
        if line.isFrequentStops {
            // Più accelerazione è meglio per fermate frequenti
            let accelScore = min(30, model.fisica.accelerazione_m_s2 * 25)
            score += accelScore
        } else {
            // Per linee con poche fermate, l'accelerazione è meno importante
            score += 15
        }
        
        // 3. Service type compatibility (20 points max)
        let modelType = inferTrainType(from: model)
        let typeCompatibility: Double = {
            switch (line.serviceType, modelType) {
            case (.highSpeed, .highSpeed): return 20
            case (.direct, .intercity): return 20
            case (.direct, .regional): return 15
            case (.regional, .regional): return 20
            case (.regional, .suburban): return 18
            case (.freight, _): return 10  // Merci è speciale
            default: return 5
            }
        }()
        score += typeCompatibility
        
        // 4. Frequency suitability (10 points max)
        if let freq = line.frequency {
            if freq <= 15 && model.fisica.accelerazione_m_s2 > 0.9 {
                score += 10  // Alta frequenza richiede accelerazione rapida
            } else if freq >= 60 {
                score += 8   // Bassa frequenza, meno critico
            } else {
                score += 5
            }
        }
        
        return min(100, score)
    }
    
    /// Suggerisce i migliori N modelli per una linea
    func suggestModels(for line: LineCharacteristics, count: Int = 3) -> [TrainModel] {
        let scored = allModels.map { model in
            (model: model, score: calculateSuitabilityScore(model: model, for: line))
        }
        .sorted { $0.score > $1.score }
        
        return scored.prefix(count).map { $0.model }
    }
}
