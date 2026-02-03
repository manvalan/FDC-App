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
                Text("smart_scheduling_intel".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Button {
                runOptimization()
            } label: {
                HStack {
                    Image(systemName: "cpu")
                    Text("optimize_button".localized)
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
                Label("system_status".localized, systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                if trainManager.trains.isEmpty {
                    Text("no_trains".localized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .clipShape(Capsule())
                } else {
                    Text(String(format: "trains_count".localized, trainManager.trains.count))
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
                summaryItem(icon: "map.fill", title: "stations_label".localized, value: "\(network.nodes.count)")
                summaryItem(icon: "road.lanes", title: "segments_label".localized, value: "\(network.edges.count)")
                summaryItem(icon: "clock.fill", title: "status_label".localized, value: optimizationResponse == nil ? "waiting_status".localized : "optimized_status".localized)
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
                Text("proposed_modifications".localized)
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
                Text("no_modifications_needed".localized)
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
                Text(String(format: "impact_label".localized, mod.impact.time_increase_seconds))
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
            Text("optimization_analysis".localized)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 20) {
                analysisItem(title: "detected_label".localized, value: "\(response.conflicts_detected ?? 0)", color: .blue)
                analysisItem(title: "resolved_label".localized, value: "\(response.conflicts_resolved ?? 0)", color: .green)
                let remaining = (response.conflicts_detected ?? 0) - (response.conflicts_resolved ?? 0)
                analysisItem(title: "remaining_label".localized, value: "\(max(0, remaining))", color: .red)
            }
            
            if !trainManager.conflictManager.conflicts.isEmpty {
                let conflicts = trainManager.conflictManager.conflicts
                Divider()
                Text("residual_conflicts_detail".localized)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ConflictDashboardView(
                    conflicts: conflicts,
                    network: network,
                    onFocusConflict: { conflict in
                        // Future: Map highlighting integration
                    }
                )
            }
            
            if let saved = response.total_impact_minutes {
                Divider()
                HStack {
                    Text("total_optimized_time".localized)
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
            
            Text("ready_for_optimization".localized)
                .font(.headline)
            
            Text("ai_welcome_desc".localized)
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
                Text("ai_analyzing".localized)
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
        guard let request = try? service.createRequest(network: network, trains: trainManager.trains, conflicts: trainManager.conflictManager.conflicts) else {
            errorMessage = "Errore creazione richiesta"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // PIGNOLO PROTOCOL: Direct execution, no artificial delay.
        service.optimize(request: request)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                    print("❌ AI Optimization Error: \(error)")
                }
            } receiveValue: { response in
                print("🌐🌐🌐 [AI AUDIT] Analisi Risultati:")
                print("   📊 Conflitti Rilevati: \(response.conflicts_detected ?? 0)")
                print("   📊 Risoluzioni Proposte: \(response.resolutions?.count ?? 0)")
                
                withAnimation(.spring()) {
                    self.optimizationResponse = response
                }
            }
            .store(in: &cancellables)
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
            return String(format: "platform_at".localized, p)
        case "speed_reduction":
            let s = mod.parameters["new_speed_kmh"]?.value as? Double ?? 0.0
            return "\(Int(s)) km/h"
        case "departure_delay":
            let d = mod.parameters["delay_seconds"]?.value as? Int ?? 0
            return "+\(d/60) m"
        default:
            return "modification".localized
        }
    }
}
