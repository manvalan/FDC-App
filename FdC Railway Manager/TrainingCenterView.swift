import SwiftUI
import Charts
import Combine

struct TrainingCenterView: View {
    @StateObject private var service = RailwayAIService.shared
    @State private var area = "Toscana"
    @State private var status = "Pronto"
    @State private var isLoading = false
    @State private var scenarioPath: String? = nil
    @State private var errorMessage: String?
    
    // Monitoring State
    @State private var trainingUpdates: [TrainingUpdate] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Control Panel
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Orchestrazione")
                                .font(.headline)
                            Text(status)
                                .font(.subheadline)
                                .foregroundColor(statusColor)
                        }
                        Spacer()
                        
                        if isLoading {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    HStack {
                        TextField("Area", text: $area)
                            .textFieldStyle(.roundedBorder)
                        
                        Button {
                            startScenarioGeneration()
                        } label: {
                            Text("Genera")
                        }
                        .disabled(isLoading || area.isEmpty)
                        
                        Button {
                            startTraining()
                        } label: {
                            Text("Train")
                        }
                        .disabled(isLoading || scenarioPath == nil)
                        .foregroundColor(.green)
                        
                        Button {
                            startOptimization()
                        } label: {
                            Text("Optimize")
                        }
                        .disabled(isLoading || scenarioPath == nil)
                        .foregroundColor(.purple)
                    }
                }
                .padding()
                
                Divider()
                
                // Real-time Data
                ScrollView {
                    VStack(spacing: 20) {
                        if !trainingUpdates.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Performance Training")
                                    .font(.headline)
                                    .padding(.horizontal)
                                
                                Chart {
                                    ForEach(trainingUpdates, id: \.episode) { update in
                                        LineMark(
                                            x: .value("Episode", update.episode),
                                            y: .value("Reward", update.reward)
                                        )
                                        .foregroundStyle(by: .value("Metric", "Reward"))
                                        
                                        LineMark(
                                            x: .value("Episode", update.episode),
                                            y: .value("Conflicts", Double(update.conflicts))
                                        )
                                        .foregroundStyle(by: .value("Metric", "Conflicts"))
                                    }
                                }
                                .frame(height: 200)
                                .padding()
                            }
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Log Console
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Console Log")
                                    .font(.headline)
                                Spacer()
                                Button("Pulisci") {
                                    service.wsMessages.removeAll()
                                }
                                .font(.caption)
                            }
                            
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(service.wsMessages.indices, id: \.self) { index in
                                            let msg = service.wsMessages[index]
                                            logRow(msg)
                                                .id(index)
                                        }
                                    }
                                }
                                .frame(minHeight: 200, maxHeight: 400)
                                .onChange(of: service.wsMessages.count) { _ in
                                    withAnimation {
                                        proxy.scrollTo(service.wsMessages.count - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Training Center")
            .onAppear {
                service.connectMonitoring()
                setupWSHandlers()
            }
            .onDisappear {
                service.disconnectMonitoring()
            }
            .alert("Errore", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var statusColor: Color {
        if isLoading { return .orange }
        if scenarioPath != nil { return .green }
        return .secondary
    }
    
    private func logRow(_ msg: WSMessage) -> some View {
        HStack(alignment: .top) {
            Text(msg.level?.uppercased() ?? "INFO")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(levelColor(msg.level))
                .frame(width: 60, alignment: .leading)
            
            Text(msg.message ?? (msg.type == "training_update" ? "Training Update" : "Messaggio ricevuto"))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func levelColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "success": return .green
        case "warning": return .orange
        case "error": return .red
        default: return .blue
        }
    }
    
    private func setupWSHandlers() {
        // Monitor scenario_path readiness
        service.$wsMessages
            .receive(on: DispatchQueue.main)
            .sink { messages in
                if let last = messages.last {
                    if last.type == "log" && last.level == "success", let path = last.scenario_path {
                        self.scenarioPath = path
                        self.status = "Scenario pronto"
                        self.isLoading = false
                    }
                    
                    if last.type == "training_update" {
                        // Support both nested and flattened DTOs
                        if let update = last.training_update {
                            self.trainingUpdates.append(update)
                        } else if let ep = last.episode, let rew = last.reward, let conf = last.conflicts {
                            self.trainingUpdates.append(TrainingUpdate(episode: ep, reward: rew, conflicts: conf))
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func startScenarioGeneration() {
        isLoading = true
        status = "Generazione scenario..."
        service.generateScenario(area: area)
            .sink { completion in
                if case .failure(let error) = completion {
                    isLoading = false
                    status = "Errore generazione"
                    errorMessage = error.localizedDescription
                }
            } receiveValue: { _ in
                // Attesa feedback via WS
            }
            .store(in: &cancellables)
    }
    
    private func startTraining() {
        guard let path = scenarioPath else { return }
        isLoading = true
        status = "Inizio training..."
        service.train(scenarioPath: path)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    status = "Errore training"
                    errorMessage = error.localizedDescription
                } else {
                    status = "Training in corso"
                    trainingUpdates = [] // Reset charts
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    private func startOptimization() {
        guard let path = scenarioPath else { return }
        isLoading = true
        status = "Avvio ottimizzazione..."
        service.optimizeWithScenario(scenarioPath: path)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    status = "Errore ottimizzazione"
                    errorMessage = error.localizedDescription
                } else {
                    status = "Ottimizzazione completata"
                }
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}
