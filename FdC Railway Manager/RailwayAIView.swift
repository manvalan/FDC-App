import SwiftUI
import Combine

struct RailwayAIView: View {
    @EnvironmentObject var trainManager: LinesManager
    @EnvironmentObject var appState: AppState
    @ObservedObject var network: NetworkModel
    @ObservedObject var railroadService = RailroadService.shared
    
    @State private var aiResult: String = ""
    @State private var isLoading = false
    @State private var userPrompt: String = ""
    @State private var errorMessage: String? = nil
    
    // Proposer State
    @State private var proposedLines: [ProposedLine] = []
    @State private var schedulePreview: String = ""
    @State private var targetLines: Int = 6
    @State private var showLineProposalSheet = false
    
    // Solver State
    @State private var solutions: [AIScheduleSuggestion] = []
    @State private var resolutions: [RailwayAIResolution] = []
    @State private var optimizerStats: (delay: Double, conflicts: Int)? = nil
    
    @State private var showJSONInspector = false
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("ai_optimizer_fdc".localized)) {
                    Button(action: runStandardOptimization) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("solve_conflicts_json".localized)
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
                }

                Section(header: Text("advanced_optimizer_cpp".localized)) {
                    Button(action: runAdvancedOptimization) {
                        HStack {
                            Image(systemName: "cpu.fill")
                            Text("global_optimization_pignolo".localized)
                        }
                    }
                    .disabled(isLoading || trainManager.trains.isEmpty)
                    
                    if let stats = optimizerStats {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "conflicts_detected_fmt".localized, stats.conflicts))
                            Text(String(format: "total_delay_fmt".localized, stats.delay))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("planning_assistant_fast".localized)) {
                    Stepper(String(format: "target_lines_fmt".localized, targetLines), value: $targetLines, in: 1...20)
                    
                    Button(action: runFastProposer) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("generate_schedule_proposal".localized)
                        }
                    }
                    .disabled(isLoading || network.nodes.count < 2)
                    
                    if !proposedLines.isEmpty {
                        Button(String(format: "review_proposals_fmt".localized, proposedLines.count)) {
                            showLineProposalSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
                
                if !resolutions.isEmpty {
                    Section(header: Text("optimized_solutions".localized)) {
                        ForEach(resolutions, id: \.train_id) { res in
                            if let uuid = RailwayAIService.shared.getTrainUUID(optimizerId: res.train_id),
                               let train = trainManager.trains.first(where: { $0.id == uuid }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(train.name).font(.headline)
                                    HStack {
                                        let sign = res.time_adjustment_min > 0 ? "+" : ""
                                        Text(String(format: "departure_adj_fmt".localized, sign, res.time_adjustment_min))
                                        
                                        if let dwells = res.dwell_delays, !dwells.isEmpty {
                                            Divider().frame(height: 10)
                                            Text(String(format: "dwells_extended_fmt".localized, dwells.count))
                                        }
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        
                        Button(action: {
                            trainManager.applyResolutions(resolutions, network: network, trainMapping: RailwayAIService.shared.getTrainMapping())
                            resolutions = []
                            aiResult = "schedules_updated_success".localized
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("apply_schedule_change".localized)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                if !aiResult.isEmpty {
                    Section(header: Text("last_operation_result".localized)) {
                        Text(aiResult).font(.body).foregroundColor(.blue)
                        
                        Button(action: { showJSONInspector = true }) {
                            Label("json_inspection_request".localized, systemImage: "doc.text.magnifyingglass")
                        }
                        .font(.caption)
                        .padding(.top, 4)
                    }
                }
                
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("optimization_in_progress".localized)
                        Spacer()
                    }
                }
                
                if let error = errorMessage {
                    Section(header: Text("encountered_error".localized)) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Railway AI")
            .sheet(isPresented: $showJSONInspector) {
                NavigationStack {
                    VStack {
                        Text("json_debug_description".localized)
                            .font(.caption)
                            .padding()
                        
                        TextEditor(text: .constant(RailwayAIService.shared.lastRequestJSON))
                            .font(.system(.caption, design: .monospaced))
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                            .padding()
                    }
                    .navigationTitle("json_detail".localized)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("close".localized) { showJSONInspector = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showLineProposalSheet) {
                LineProposalView(
                    network: network,
                    proposals: proposedLines,
                    onApply: { selectedProposals, createTrains in
                        applySelectedProposals(selectedProposals, createTrains: createTrains)
                    }
                )
                .environmentObject(trainManager)
            }
        }
    }
    
    private func runAdvancedOptimization() {
        let trimmedEndpoint = appState.aiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = appState.aiUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = appState.aiPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        appState.aiEndpoint = trimmedEndpoint
        appState.aiUsername = trimmedUsername
        appState.aiPassword = trimmedPassword
        
        isLoading = true
        resolutions = []
        optimizerStats = nil
        errorMessage = nil
        
        RailwayAIService.shared.syncCredentials(
            endpoint: trimmedEndpoint,
            apiKey: appState.aiApiKey,
            token: appState.aiToken
        )
        
        if trimmedPassword.isEmpty && appState.aiApiKey.isEmpty {
            isLoading = false
            errorMessage = "Errore: Inserisci la PASSWORD o una API KEY nelle impostazioni."
            return
        }
        
        if RailwayAIService.shared.token == nil && RailwayAIService.shared.apiKey == nil {
            aiResult = "Autenticazione in corso..."
            RailwayAIService.shared.login(username: trimmedUsername, password: trimmedPassword)
                .sink { completion in
                    if case .failure(let error) = completion {
                        isLoading = false
                        errorMessage = "Login fallito: \(error.localizedDescription)"
                    }
                } receiveValue: { token in
                    appState.aiToken = token
                    self.performOptimizationCall()
                }
                .store(in: &cancellables)
        } else {
            self.performOptimizationCall()
        }
    }

    private func runStandardOptimization() {
        isLoading = true
        aiResult = "Analisi conflitti in corso..."
        errorMessage = nil
        
        let reporter = trainManager.conflictManager
        let request = RailwayAIService.shared.createRequest(
            nodes: network.nodes,
            edges: network.edges,
            trains: trainManager.trains,
            conflicts: reporter.conflicts
        )
        
        RailwayAIService.shared.optimize(request: request)
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Optimizer Error: \(error.localizedDescription)"
                }
            } receiveValue: { response in
                if response.success {
                    self.resolutions = response.resolutions ?? []
                    self.optimizerStats = (response.total_delay_minutes ?? 0, response.conflicts_detected ?? 0)
                    self.aiResult = "Analisi completata! \(response.resolutions?.count ?? 0) modifiche proposte."
                } else {
                    errorMessage = response.error_message ?? "L'AI ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
    }

    private func performOptimizationCall() {
        aiResult = "Ottimizzazione matematica in corso..."
        
        RailwayAIService.shared.optimize(request: RailwayAIService.shared.createRequest(nodes: network.nodes, edges: network.edges, trains: trainManager.trains, conflicts: []))
            .sink { completion in
                isLoading = false
                if case .failure(let error) = completion {
                    errorMessage = "Optimizer Error: \(error.localizedDescription)"
                }
            } receiveValue: { response in
                if response.success {
                    self.resolutions = response.resolutions ?? []
                    self.optimizerStats = (response.total_delay_minutes ?? 0, response.conflicts_detected ?? 0)
                    
                    if (response.resolutions ?? []).isEmpty {
                        self.aiResult = "Nessuna soluzione trovata dall'AI."
                    } else {
                        self.aiResult = "Ottimizzazione completata! \(response.resolutions?.count ?? 0) modifiche proposte."
                    }
                } else {
                    errorMessage = "L'ottimizzatore ha riportato un fallimento."
                }
            }
            .store(in: &cancellables)
    }

    private func runFastProposer() {
        isLoading = true
        errorMessage = nil
        proposedLines = []
        schedulePreview = ""
        
        RailwayAIService.shared.syncCredentials(
            endpoint: appState.aiEndpoint,
            apiKey: appState.aiApiKey,
            token: appState.aiToken
        )
        
        let graph = RailwayGraphManager.shared
        ScheduleProposer.shared.requestProposal(using: graph, network: network, targetLines: targetLines) { result in
            isLoading = false
            switch result {
            case .success(let proposal):
                self.proposedLines = proposal.proposedLines
                self.aiResult = "L'IA ha proposto \(proposal.proposedLines.count) nuove linee!"
            case .failure(let error):
                self.errorMessage = "Errore Proposta: \(error.localizedDescription)"
            }
        }
    }
    
    private func applySelectedProposals(_ selectedProposals: [ProposedLine], createTrains: Bool) {
        for pline in selectedProposals {
            let lineId = UUID().uuidString
            let stops = pline.stationSequence.map { sid -> RelationStop in
                let node = network.nodes.first(where: { $0.id == sid })
                let dwell = (node?.type == .interchange) ? 5 : 3
                return RelationStop(stationId: sid, minDwellTime: dwell)
            }
            
            let newLine = RailwayLine(
                id: lineId,
                name: pline.name,
                color: pline.color ?? "#007AFF",
                originId: pline.stationSequence.first ?? "",
                destinationId: pline.stationSequence.last ?? "",
                stops: stops
            )
            trainManager.lines.append(newLine)
            
            if createTrains {
                let freq = pline.frequencyMinutes > 0 ? pline.frequencyMinutes : 60
                let startHour = 6
                let endHour = 22
                
                let calendar = Calendar.current
                let baseDate = calendar.startOfDay(for: Date())
                
                for hour in stride(from: startHour, to: endHour, by: 1) {
                    for min in stride(from: 0, to: 60, by: freq) {
                        let departureTime = calendar.date(bySettingHour: hour, minute: min, second: 0, of: baseDate)
                        let trainNum = 1000 + trainManager.lines.count * 100 + (hour * 10) + (min / 10)
                        
                        let newTrain = Train(
                            id: UUID(),
                            number: trainNum,
                            name: "\(pline.name) - \(trainNum)",
                            type: "Regionale",
                            lineId: lineId,
                            departureTime: departureTime,
                            stops: stops,
                            vehicleId: nil,
                            maxSpeed: 120,
                            acceleration: 0.5,
                            deceleration: 0.5,
                            priority: 5
                        )
                        trainManager.trains.append(newTrain)
                    }
                }
            }
        }
        
        proposedLines = []
        let trainsMsg = createTrains ? " con treni di esempio" : ""
        aiResult = "Creazione completata: \(selectedProposals.count) linee aggiunte\(trainsMsg)."
        trainManager.validateSchedules()
    }
}
