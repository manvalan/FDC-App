import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LineCreationInspectorView: View {
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var trainManager: TrainManager

    @State private var lineName: String = ""
    @State private var codePrefix: String = ""
    @State private var numberPrefix: Int = 0
    @State private var cadenceFrequency: Double = 60.0
    @State private var lineColor: Color = .blue

    @State private var errorMessage: String? = nil
    @State private var showingConfirmation: Bool = false

    @StateObject private var cadenceOptimizer = CadenceOptimizer()
    @State private var proposedOffset: Double? = nil

    var body: some View {
        VStack(spacing: 0) {
            if appState.lineDraftStations.isEmpty {
                emptyStateView
            } else if !showingConfirmation {
                stationSelectionView
            } else {
                detailsFormView
            }
        }
        .onAppear {
            suggestColorForLine()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.3))

            Text("Tocca le stazioni sulla mappa")
                .font(.headline)

            Text("Seleziona le stazioni una dopo l'altra per creare il percorso della linea")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Hide panel button if stations are covered
            Button(action: {
                appState.showPanel(.none)
            }) {
                HStack {
                    Image(systemName: "eye.slash")
                    Text("Nascondi pannello")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var stationSelectionView: some View {
        VStack(spacing: 0) {
            // Header info
            VStack(spacing: 8) {
                HStack {
                    Text("\(appState.lineDraftStations.count) stazioni")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(String(format: "%.1f km", totalDistance))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Hide panel button to access covered stations
                Button(action: {
                    appState.showPanel(.none)
                }) {
                    HStack {
                        Image(systemName: "eye.slash")
                        Text("Nascondi per selezionare stazioni")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding()

            Divider()

            // Stations list
            List {
                ForEach(Array(appState.lineDraftStations.enumerated()), id: \.offset) { index, stationId in
                    stationRow(index: index, stationId: stationId)
                }
                .onDelete(perform: deleteStation)
            }
            .listStyle(.plain)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
            }

            // Finish button
            Button(action: { showingConfirmation = true }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Conferma Percorso")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(appState.lineDraftStations.count < 2)
            .padding()
        }
    }

    private func stationRow(index: Int, stationId: String) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            VStack(alignment: .leading, spacing: 2) {
                Text(stationName(for: stationId))
                    .font(.subheadline.bold())

                if index == 0 {
                    Text("Partenza")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if index == appState.lineDraftStations.count - 1 {
                    Text("Arrivo")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if index < appState.lineDraftStations.count - 1 {
                Image(systemName: "arrow.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var detailsFormView: some View {
        ScrollView {
            VStack(spacing: 24) {
                InspectorSection(title: "Dettagli Linea", icon: "pencil", iconColor: .blue) {
                    InspectorTextField(label: "Nome linea", text: $lineName, placeholder: "es. Milano-Roma")
                    
                    InspectorTextField(label: "Prefisso codice", text: $codePrefix, placeholder: "es. IC")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Numero linea")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("es. 600", value: $numberPrefix, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                    
                    ColorPicker("Colore linea", selection: $lineColor)
                        .padding(.vertical, 4)
                }
                
                InspectorSection(title: "Percorso", icon: "map", iconColor: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(appState.lineDraftStations.count) stazioni")
                            .font(.headline)
                        Text(String(format: "%.1f km", totalDistance))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Divider()
                        
                        if let start = appState.lineDraftStations.first,
                           let end = appState.lineDraftStations.last {
                            HStack {
                                Text(stationName(for: start))
                                Image(systemName: "arrow.right")
                                Text(stationName(for: end))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let error = errorMessage {
                    InspectorInfoBanner(type: .error, title: "Errore", message: error)
                }
                
                VStack(spacing: 12) {
                        Button(action: saveLine) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Salva Linea")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(lineName.isEmpty || appState.lineDraftStations.count < 2)
                    
                    Button(action: { showingConfirmation = false }) {
                        Text("Torna al Percorso")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
            }
            .padding()
        }
        .onAppear {
            suggestColorForLine()
        }
    }

    private var totalDistance: Double {
        return network.calculatePathDistance(path: appState.lineDraftStations)
    }

    private func stationName(for stationId: String) -> String {
        network.nodes.first { $0.id == stationId }?.name ?? stationId
    }

    private func deleteStation(at offsets: IndexSet) {
        withAnimation {
            appState.lineDraftStations.remove(atOffsets: offsets)
        }
    }


    private func suggestColorForLine() {
        // Analizza le stazioni coinvolte per trovare linee simili
        let firstStation = appState.lineDraftStations.first ?? ""
        let lastStation = appState.lineDraftStations.last ?? ""
        
        // Trova linee che condividono stazioni simili
        let similarLines = trainManager.lines.filter { line in
            let hasCommonOrigin = line.originId == firstStation || line.destinationId == firstStation
            let hasCommonDestination = line.originId == lastStation || line.destinationId == lastStation
            let sharesStations = line.stops.contains { appState.lineDraftStations.contains($0.stationId) }
            return hasCommonOrigin || hasCommonDestination || sharesStations
        }
        
        if let mostSimilarLine = similarLines.first,
           let hexColor = mostSimilarLine.color,
           let baseColor = Color(hex: hexColor) {
            // Genera una variazione del colore
            lineColor = generateSimilarColor(from: baseColor)
        } else {
            // Colore casuale ma piacevole
            lineColor = generateDistinctColor()
        }
    }
    
    private func generateSimilarColor(from baseColor: Color) -> Color {
        let uiColor = UIColor(baseColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Varia leggermente la tonalità (±15 gradi)
        let hueVariation = CGFloat.random(in: -0.04...0.04)
        let newHue = (hue + hueVariation).truncatingRemainder(dividingBy: 1.0)
        
        // Varia leggermente saturazione e luminosità
        let newSaturation = min(1.0, max(0.3, saturation + CGFloat.random(in: -0.15...0.15)))
        let newBrightness = min(1.0, max(0.3, brightness + CGFloat.random(in: -0.15...0.15)))
        
        return Color(UIColor(hue: newHue, saturation: newSaturation, brightness: newBrightness, alpha: 1.0))
    }
    
    private func generateDistinctColor() -> Color {
        // Genera un colore distinto dalle linee esistenti
        let existingColors = trainManager.lines.compactMap { $0.color }.compactMap { Color(hex: $0) }
        
        // Palette di colori base ben distinti
        let baseHues: [CGFloat] = [
            0.0,    // Rosso
            0.03,   // Arancione
            0.14,   // Giallo
            0.33,   // Verde
            0.55,   // Blu
            0.65,   // Azzurro
            0.75,   // Indaco
            0.83    // Viola
        ]
        
        // Trova la tonalità meno usata
        var bestHue = baseHues.randomElement() ?? 0.55
        var maxDistance: CGFloat = 0
        
        for hue in baseHues {
            var minDistanceToExisting: CGFloat = 1.0
            
            for existingColor in existingColors {
                let existingUIColor = UIColor(existingColor)
                var existingHue: CGFloat = 0
                var s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                existingUIColor.getHue(&existingHue, saturation: &s, brightness: &b, alpha: &a)
                
                let distance = min(abs(hue - existingHue), 1.0 - abs(hue - existingHue))
                minDistanceToExisting = min(minDistanceToExisting, distance)
            }
            
            if minDistanceToExisting > maxDistance {
                maxDistance = minDistanceToExisting
                bestHue = hue
            }
        }
        
        return Color(UIColor(hue: bestHue, saturation: 0.7, brightness: 0.8, alpha: 1.0))
    }

    private func saveLine() {
        print("💾 [saveLine] Starting to save line")
        print("   Draft stations count: \(appState.lineDraftStations.count)")
        print("   Draft stations: \(appState.lineDraftStations)")
        
        let hexColor = lineColor.toHex()
        let stops = appState.lineDraftStations.map { sid -> RelationStop in
            let node = network.nodes.first(where: { $0.id == sid })
            let defaultDwell = (node?.type == .interchange) ? 5 : 3
            return RelationStop(stationId: sid, minDwellTime: defaultDwell)
        }
        
        print("   Created \(stops.count) stops")

        let newLine = RailwayLine(
            id: UUID().uuidString,
            name: lineName,
            color: hexColor,
            originId: appState.lineDraftStations.first ?? "",
            destinationId: appState.lineDraftStations.last ?? "",
            stops: stops,
            codePrefix: codePrefix.isEmpty ? nil : codePrefix,
            numberPrefix: numberPrefix == 0 ? nil : numberPrefix,
            cadenceFrequency: cadenceFrequency
        )
        
        print("   Line '\(newLine.name)' created with \(newLine.stops.count) stops")
        print("   Origin: \(newLine.originId), Destination: \(newLine.destinationId)")

        trainManager.lines.append(newLine)
        print("   Line added to trainManager, total lines: \(trainManager.lines.count)")

        // Cleanup
        appState.isCreatingLine = false
        appState.lineDraftStations.removeAll()
    }
}
