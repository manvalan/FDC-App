import SwiftUI
import Charts
import UniformTypeIdentifiers
import Combine

struct RailwayAISchedulerView: View {
    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    
    @StateObject private var service = RailwayAIService.shared
    @State private var optimizationResponse: RailwayAIResponse?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @State private var selectedTab: Int = 0
    @State private var showExport = false
    @State private var showChart = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                headerView
                
                ScrollView {
                    VStack(spacing: 20) {
                        statusCard
                        
                        if let response = optimizationResponse {
                            modificationsSection(response: response)
                            analysisCard(response: response)
                        } else if !isLoading {
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            
            if isLoading {
                loadingOverlay
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showChart) {
             if let _ = optimizationResponse {
                 // Reuse existing chart logic or implement new one
                 TimetableChartView(schedulerResult: "Mock Chart Data") // Simplified for now
             }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("RailwayAI")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("Smart Scheduling Intelligence")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button {
                runOptimization()
            } label: {
                HStack {
                    Image(systemName: "cpu")
                    Text("Ottimizza")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .disabled(isLoading || trainManager.trains.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Stato Sistema", systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                if trainManager.trains.isEmpty {
                    Text("Nessun treno")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                } else {
                    Text("\(trainManager.trains.count) Treni")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                summaryItem(icon: "map.fill", title: "Stazioni", value: "\(network.nodes.count)")
                summaryItem(icon: "road.lanes", title: "Tratte", value: "\(network.edges.count)")
                summaryItem(icon: "clock.fill", title: "Status", value: optimizationResponse == nil ? "In attesa" : "Ottimizzato")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
    
    private func summaryItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func modificationsSection(response: RailwayAIResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Modifiche Proposte")
                    .font(.title3.bold())
                Spacer()
                if let confidence = response.ml_confidence {
                    Text("AI Confidence: \(Int(confidence * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            
            if let mods = response.modifications, !mods.isEmpty {
                ForEach(mods) { mod in
                    modificationRow(mod: mod)
                }
            } else {
                Text("Nessuna modifica necessaria. Orario ottimale.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
            }
        }
    }
    
    private func modificationRow(mod: RailwayAIModification) -> some View {
        HStack(spacing: 16) {
            Circle()
                .fill(modificationColor(type: mod.modification_type))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: modificationIcon(type: mod.modification_type))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mod.train_id)
                    .font(.headline)
                Text(mod.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let station = mod.section.station {
                    Text("📍 \(station)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(modificationValue(mod: mod))
                    .font(.subheadline.bold())
                Text("Impatto: \(mod.impact.time_increase_seconds)s")
                    .font(.caption2)
                    .foregroundColor(mod.impact.time_increase_seconds == 0 ? .green : .orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.6))
        .cornerRadius(16)
    }
    
    private func analysisCard(response: RailwayAIResponse) -> some View {
        VStack(spacing: 16) {
            Text("Analisi Ottimizzazione")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                analysisItem(title: "Controllati", value: "\(response.conflict_analysis?.original_conflicts ?? 0)", color: .blue)
                analysisItem(title: "Risolti", value: "\(response.conflict_analysis?.resolved_conflicts ?? 0)", color: .green)
                analysisItem(title: "Rimasti", value: "\(response.conflict_analysis?.remaining_conflicts ?? 0)", color: .red)
            }
            
            if let saved = response.total_impact_minutes {
                Divider()
                HStack {
                    Text("Tempo Totale Ottimizzato")
                        .font(.subheadline)
                    Spacer()
                    Text("\(String(format: "%.1f", saved)) m")
                        .font(.headline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    private func analysisItem(title: String, value: String, color: Color) -> some View {
        VStack {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.blue.opacity(0.3))
            
            Text("Pronto per l'ottimizzazione")
                .font(.headline)
            
            Text("Carica i treni e clicca su Ottimizza per usare RailwayAI e risolvere tutti i conflitti della rete.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Analisi AI in corso...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
        }
    }
    
    // MARK: - Helpers
    
    private func runOptimization() {
        isLoading = true
        let request = service.createRequest(network: network, trains: trainManager.trains, conflicts: trainManager.conflictManager.conflicts)
        
        // Simulating some network delay for the UX feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            service.optimize(request: request)
                .sink { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                } receiveValue: { response in
                    withAnimation(.spring()) {
                        optimizationResponse = response
                    }
                }
                .store(in: &cancellables) // Need to add cancellables set
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private func modificationColor(type: String) -> Color {
        switch type {
        case "platform_change": return .green
        case "speed_reduction": return .orange
        case "departure_delay": return .red
        default: return .blue
        }
    }
    
    private func modificationIcon(type: String) -> String {
        switch type {
        case "platform_change": return "arrow.left.and.right.circle.fill"
        case "speed_reduction": return "gauge.medium"
        case "departure_delay": return "clock.badge.exclamationmark"
        default: return "gear"
        }
    }
    
    private func modificationValue(mod: RailwayAIModification) -> String {
        switch mod.modification_type {
        case "platform_change":
            let p = mod.parameters["new_platform"]?.value as? Int ?? 0
            return "Binario \(p)"
        case "speed_reduction":
            let s = mod.parameters["new_speed_kmh"]?.value as? Double ?? 0.0
            return "\(Int(s)) km/h"
        case "departure_delay":
            let d = mod.parameters["delay_seconds"]?.value as? Int ?? 0
            return "+\(d/60) m"
        default:
            return "Modifica"
        }
    }
}
