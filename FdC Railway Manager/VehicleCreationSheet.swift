import SwiftUI
import UIKit

struct VehicleCreationSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var linesManager: LinesManager
    @EnvironmentObject var appState: AppState
    @StateObject private var wikiImageService = WikiImageService()
    
    @AppStorage("lastSelectedVehicleTemplateId") private var selectedTemplateId: String = VehicleTemplate.all[0].id
    @State private var customName: String = ""
    @AppStorage("useManualVehicleName") private var useManualName: Bool = false
    
    // Auto-numbering
    @State private var nextNumber: Int = 1
    
    var selectedTemplate: VehicleTemplate {
        VehicleTemplate.all.first(where: { $0.id == selectedTemplateId }) ?? VehicleTemplate.all[0]
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        // 1. Try Local Asset: If `imageName` is valid and exists in bundle
                        if let imageName = selectedTemplate.imageName, let _ = UIImage(named: imageName) {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                .accessibilityLabel("Immagine locale del mezzo")
                        
                        // 2. Try Remote Image: If local fails, use Wikimedia fetcher
                        } else if let remoteURL = wikiImageService.currentImageURL {
                            AsyncImage(url: remoteURL) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(height: 60)
                                case .success(let image):
                                    image.resizable()
                                         .scaledToFit()
                                         .frame(height: 150)
                                         .cornerRadius(8)
                                case .failure(_):
                                    fallbackView
                                @unknown default:
                                    fallbackView
                                }
                            }
                        } else {
                            // 3. Fallback / Loading State
                            if wikiImageService.isLoading {
                                ProgressView("Cercando immagine...")
                                    .padding()
                            } else {
                                fallbackView
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                Section("Modello Mezzo") {
                    Picker("Modello", selection: $selectedTemplateId) {
                        ForEach(VehicleTemplate.all) { template in
                            Text(template.name).tag(template.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .pickerStyle(.navigationLink)
                    .onChange(of: selectedTemplateId) { newValue in
                        recalculateNextNumber()
                        
                        // Trigger remote search whenever template changes
                        // Use base name "ETR 500" from "ETR 500 (Frecciarossa)"
                        let baseName = VehicleTemplate.all.first(where: { $0.id == newValue })?.name ?? ""
                        wikiImageService.searchImage(for: baseName)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Specifiche")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(selectedTemplate.length))m • \(Int(selectedTemplate.maxSpeed)) km/h")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Section("Identificazione") {
                    if !useManualName {
                        HStack {
                            Text("Matricola Proposta")
                            Spacer()
                            Text(proposedName)
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundColor(.blue)
                        }
                    } else {
                        TextField("Nome / Matricola", text: $customName)
                    }
                    
                    Toggle("Inserimento Manuale", isOn: $useManualName)
                }
                
                Section {
                    Button(action: createVehicle) {
                        HStack {
                            Spacer()
                            Text("Aggiungi alla Flotta")
                                .bold()
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Nuovo Mezzo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
            .onAppear {
                recalculateNextNumber()
                // Initial search
                let baseName = selectedTemplate.name
                wikiImageService.searchImage(for: baseName)
            }
        }
    }
    
    private var fallbackView: some View {
        VStack(spacing: 8) {
            Image(systemName: "tram.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Nessuna immagine disponibile")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var proposedName: String {
        // Extract base code (e.g. ETR 104) from template name
        let components = selectedTemplate.name.components(separatedBy: "(")
        let baseCode = components.first?.trimmingCharacters(in: .whitespaces) ?? "MEZZO"
        
        // Format: ETR 104.001
        return "\(baseCode).\(String(format: "%03d", nextNumber))"
    }
    
    private func recalculateNextNumber() {
        // Find all vehicles that match the current template base name
        let components = selectedTemplate.name.components(separatedBy: "(")
        let baseCode = components.first?.trimmingCharacters(in: .whitespaces) ?? ""
        
        let existing = linesManager.vehicles.filter { $0.name.starts(with: baseCode) }
        
        // Extract numbers
        var maxNum = 0
        for v in existing {
            let parts = v.name.components(separatedBy: ".")
            if parts.count > 1, let num = Int(parts.last ?? "0") {
                maxNum = max(maxNum, num)
            }
        }
        
        nextNumber = maxNum + 1
    }
    
    private func createVehicle() {
        let finalName = useManualName ? customName : proposedName
        let newVehicle = Vehicle(
            name: finalName,
            model: selectedTemplate.model,
            length: selectedTemplate.length,
            maxSpeed: selectedTemplate.maxSpeed,
            acceleration: selectedTemplate.acceleration,
            deceleration: selectedTemplate.deceleration,
            mass: selectedTemplate.mass,
            power: selectedTemplate.power,
            isElectric: selectedTemplate.isElectric, // Pass electric status
            imageName: selectedTemplate.imageName
        )
        
        linesManager.vehicles.append(newVehicle)
        
        // Update defaults for next time (legacy support, though we use template now)
        appState.lastVehicleName = finalName
        appState.lastVehicleModel = selectedTemplate.model
        appState.lastVehicleLength = selectedTemplate.length
        appState.lastVehicleMaxSpeed = selectedTemplate.maxSpeed
        
        dismiss()
    }
}
