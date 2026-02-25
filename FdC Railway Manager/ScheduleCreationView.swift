import SwiftUI
import Combine

struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: RailwayNetwork
    @EnvironmentObject var manager: TrainManager
    @EnvironmentObject var appState: AppState

    @StateObject private var vm: ScheduleCreationViewModel

    // UI-only state (not business logic)
    @State private var showModelSelector = false
    @State private var showOptimizedTimesPreview = false

    let line: RailwayLine

    init(line: RailwayLine, initialMode: ScheduleMode = .single) {
        self.line = line
        self._vm = StateObject(wrappedValue: ScheduleCreationViewModel(line: line, initialMode: initialMode))
    }

    // MARK: - Body

    var body: some View {
        bodyContent
            .onAppear {
                vm.injectDependencies(network: network, manager: manager, appState: appState)
                vm.handleOnAppear()
            }
            .modifier(ScheduleChangeModifiersA(vm: vm, appState: appState,
                                                  handleOptimizedTimesConfirmed: handleOptimizedTimesConfirmed,
                                                  handleStationChange: handleStationChange))
            .modifier(ScheduleChangeModifiersB(vm: vm, appState: appState))
    }

    private var bodyContent: some View {
        ZStack {
            ScrollView {
                formScrollContent
                    .padding(.top, 10)
            }
            if vm.cadenceOptimizer.isRunning {
                optimizationOverlay
            }
        }
    }
}

// MARK: - Event Handlers (≤10 lines each)

private extension ScheduleCreationView {

    func handleOptimizedTimesConfirmed(_ confirmed: Bool) {
        guard confirmed, let data = appState.optimizedTimesPreviewData else { return }
        vm.startTime = data.proposedOutboundTime
        vm.endTime = data.proposedReturnTime ?? vm.endTime
        vm.intervalMinutes = data.proposedInterval ?? vm.intervalMinutes
        appState.optimizedTimesPreviewData = nil
        appState.optimizedTimesConfirmed = false
        vm.aiTask = Task { await vm.generateSchedule() }
    }

    func handleStationChange() {
        guard !vm.isInitializing else { return }
        withAnimation {
            vm.updateStationSequenceFromSelection()
            vm.updatePathCalculations()
            vm.updatePreview()
            vm.skippedStopIds.removeAll()
        }
    }
}

// MARK: - Form Layout

private extension ScheduleCreationView {

    var formScrollContent: some View {
        VStack(spacing: 24) {
            headerSection
            stationSelectSection
            pathInfoRow
            stopPatternSection
            if vm.mode == .taktfahrplan { taktfahrplanSection }
            generateReturnToggle
            cadenceSelectionSection
            previewSection
            actionButtonsSection
        }
        .padding(.bottom, 40)
    }
}

// MARK: - Header

private extension ScheduleCreationView {

    var headerSection: some View {
        HStack {
            Text(String(format: "schedule_gen_line_fmt".localized, line.name))
                .font(.headline)
            Spacer()
            Picker("mode".localized, selection: $vm.mode) {
                ForEach(ScheduleMode.allCases) { m in
                    Text(m.localizedName).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.horizontal)
    }
}

// MARK: - Station Select

private extension ScheduleCreationView {

    var stationSelectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERCORSO DI LINEA")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    stationPickerRow(title: "Partenza", selection: $vm.startStationId)
                    HStack {
                        Image(systemName: "arrow.down")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.leading, 12)
                        Spacer()
                    }
                    stationPickerRow(title: "Arrivo", selection: $vm.endStationId)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    func stationPickerRow(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Picker(title, selection: selection) {
                ForEach(line.stations, id: \.self) { stationId in
                    HStack(spacing: 8) {
                        stationSymbol(for: stationId, size: 14)
                        Text(vm.stationName(stationId))
                    }
                    .tag(stationId)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.15))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue.opacity(0.3), lineWidth: 1))
        }
    }

    @ViewBuilder
    func stationSymbol(for stationId: String, size: CGFloat = 16) -> some View {
        if let station = network.nodes.first(where: { $0.id == stationId }) {
            if station.type == .interchange {
                interchangeSymbol(size: size)
            } else {
                regularStationSymbol(station: station, size: size)
            }
        } else {
            Circle().fill(Color.gray).frame(width: size, height: size)
        }
    }

    func interchangeSymbol(size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(Color.red, lineWidth: 2).frame(width: size, height: size)
            Circle().stroke(Color.red, lineWidth: 2).frame(width: size * 0.6, height: size * 0.6)
        }
    }

    @ViewBuilder
    func regularStationSymbol(station: RailwayNode, size: CGFloat) -> some View {
        let color = station.customColor.flatMap { Color(hex: $0) } ?? .blue
        switch station.visualType ?? .filledCircle {
        case .filledCircle:
            Circle().fill(color).frame(width: size, height: size)
        case .emptyCircle:
            Circle().stroke(color, lineWidth: 2).frame(width: size, height: size)
        case .filledSquare:
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: size, height: size)
        case .emptySquare:
            RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 2).frame(width: size, height: size)
        case .filledStar:
            Image(systemName: "star.fill").foregroundColor(color).font(.system(size: size))
        }
    }
}

// MARK: - Path Info

private extension ScheduleCreationView {

    var pathInfoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETTAGLI SERVIZIO")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                metricsRow
                trainTypePicker
                vehicleSection
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    var metricsRow: some View {
        HStack(spacing: 12) {
            MetricView(label: "Stazioni", value: "\(vm.stationSequence.count)")
            MetricView(label: "Distanza", value: String(format: "%.1fkm", vm.estimatedDistance))
            MetricView(label: "Durata St.", value: "\(vm.estimatedTravelTime)m")
            Spacer()
        }
    }

    var trainTypePicker: some View {
        HStack {
            Image(systemName: "train.side.front.car").foregroundColor(.blue)
            Text("Tipologia Treno").font(.subheadline)
            Spacer()
            Picker("train_type".localized, selection: $vm.selectedTrainType) {
                ForEach(TrainCategory.allCases) { cat in
                    Text(cat.localizedName).tag(cat)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    var vehicleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bus.doubledecker.fill").foregroundColor(.orange)
                Text("Materiale Rotabile").font(.subheadline.bold())
                if vm.selectedVehicle != nil {
                    Spacer()
                    Text("✓").foregroundColor(.green)
                }
            }
            vehicleSelectionMenu
        }
    }

    var vehicleSelectionMenu: some View {
        Button(action: { showModelSelector = true }) {
            vehicleMenuContent
        }
        .sheet(isPresented: $showModelSelector) {
            TrainModelSelectorView(
                selectedModel: $vm.selectedModel,
                lineCharacteristics: vm.calculateLineCharacteristics()
            )
        }
    }

    var vehicleMenuContent: some View {
        HStack {
            if let model = vm.selectedModel {
                vehicleModelThumbnail(model: model)
                vehicleModelInfo(model: model)
            } else {
                Text("Seleziona modello treno...")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
    }

    @ViewBuilder
    func vehicleModelThumbnail(model: TrainModel) -> some View {
        Group {
            if let imageName = model.asset_name, !imageName.isEmpty,
               let _ = UIImage(named: imageName) {
                Image(imageName).resizable().scaledToFill()
            } else {
                Image(systemName: "train.side.front.car")
                    .font(.title3).foregroundColor(.orange)
            }
        }
        .frame(width: 40, height: 40)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8).clipped()
    }

    func vehicleModelInfo(model: TrainModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.nome).font(.subheadline.bold())
            Text("\(model.costruttore) • \(model.specifiche.velocita_max_kmh)km/h • \(String(format: "%.1f", model.fisica.accelerazione_m_s2))m/s²")
                .font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Stop Pattern

private extension ScheduleCreationView {

    var stopPatternSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            stopPatternHeader
            if vm.stationSequence.count >= 2 {
                stopPatternList
            } else {
                emptyStopPatternMessage
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal)
    }

    var stopPatternHeader: some View {
        HStack {
            Text("SCHEMA FERMATE")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            Spacer()
            localeButton
            intercityButton
            direttoButton
        }
    }

    var localeButton: some View {
        Button(action: { vm.skippedStopIds.removeAll() }) {
            Text("Locale")
                .font(.caption2.bold())
                .foregroundColor(vm.skippedStopIds.isEmpty ? .white : .blue)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(vm.skippedStopIds.isEmpty ? Color.blue : Color.blue.opacity(0.2))
                .cornerRadius(6)
        }
    }

    var intercityButton: some View {
        Button(action: { applyIntercityPattern() }) {
            Text("Intercity")
                .font(.caption2.bold())
                .foregroundColor(.purple)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
        }
    }

    var direttoButton: some View {
        let allSkipped = vm.skippedStopIds.count == max(0, vm.stationSequence.count - 2)
        return Button(action: { applyExpressPattern() }) {
            Text("Diretto")
                .font(.caption2.bold())
                .foregroundColor(allSkipped ? .white : .orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(allSkipped ? Color.orange : Color.orange.opacity(0.2))
                .cornerRadius(6)
        }
    }

    func applyIntercityPattern() {
        vm.skippedStopIds.removeAll()
        guard vm.stationSequence.count > 2 else { return }
        for i in 1..<(vm.stationSequence.count - 1) {
            let sid = vm.stationSequence[i]
            if let station = network.nodes.first(where: { $0.id == sid }),
               station.visualType != .filledSquare && station.visualType != .emptySquare {
                vm.skippedStopIds.insert(sid)
            }
        }
    }

    func applyExpressPattern() {
        vm.skippedStopIds.removeAll()
        guard vm.stationSequence.count > 2 else { return }
        for i in 1..<(vm.stationSequence.count - 1) {
            vm.skippedStopIds.insert(vm.stationSequence[i])
        }
    }

    var stopPatternList: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.stationSequence.enumerated()), id: \.offset) { index, stationId in
                stopPatternRow(index: index, stationId: stationId)
            }
        }
    }

    func stopPatternRow(index: Int, stationId: String) -> some View {
        let isFirst = index == 0
        let isLast = index == vm.stationSequence.count - 1
        let isSkipped = vm.skippedStopIds.contains(stationId)

        return HStack(spacing: 12) {
            stopIndicator(isSkipped: isSkipped)
            stopLabel(stationId: stationId, isFirst: isFirst, isLast: isLast, isSkipped: isSkipped)
            Spacer()
            if !isFirst && !isLast {
                skipToggleButton(stationId: stationId, isSkipped: isSkipped)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(isSkipped ? Color.gray.opacity(0.05) : Color.blue.opacity(0.05))
        .cornerRadius(10)
    }

    func stopIndicator(isSkipped: Bool) -> some View {
        ZStack {
            Circle().fill(isSkipped ? Color.gray.opacity(0.3) : Color.blue)
                .frame(width: 16, height: 16)
            if !isSkipped {
                Circle().fill(Color.white).frame(width: 6, height: 6)
            }
        }
    }

    func stopLabel(stationId: String, isFirst: Bool, isLast: Bool, isSkipped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(vm.stationName(stationId))
                .font(.subheadline)
                .foregroundColor(isSkipped ? .secondary : .primary)
            if isFirst {
                Text("Partenza").font(.caption2).foregroundColor(.secondary)
            } else if isLast {
                Text("Arrivo").font(.caption2).foregroundColor(.secondary)
            } else if isSkipped {
                Text("Transito senza fermata").font(.caption2).foregroundColor(.orange)
            }
        }
    }

    func skipToggleButton(stationId: String, isSkipped: Bool) -> some View {
        Button(action: {
            if isSkipped { vm.skippedStopIds.remove(stationId) }
            else { vm.skippedStopIds.insert(stationId) }
        }) {
            Image(systemName: isSkipped ? "circle" : "checkmark.circle.fill")
                .foregroundColor(isSkipped ? .gray : .green)
                .font(.title3)
        }
        .buttonStyle(.plain)
    }

    var emptyStopPatternMessage: some View {
        Text("Aggiungi almeno 2 stazioni per configurare lo schema fermate")
            .font(.caption).foregroundColor(.secondary).italic().padding()
    }
}

// MARK: - Taktfahrplan Section

private extension ScheduleCreationView {

    var taktfahrplanSection: some View {
        let suggestions = vm.calculateTaktSuggestions()
        let sequenceWithTakt = vm.stationSequence.filter { sid in
            network.nodes.first(where: { $0.id == sid })?.taktMinutes != nil
        }

        return VStack(alignment: .leading, spacing: 12) {
            taktHeader
            if !sequenceWithTakt.isEmpty {
                taktStationPicker(stations: sequenceWithTakt)
                if let suggestion = suggestions.first(where: { $0.stationId == vm.taktStationId }) {
                    taktSuggestionCard(suggestion: suggestion)
                }
            } else {
                taktEmptyMessage
            }
            taktInfoMessage
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.2), lineWidth: 1))
        .padding(.horizontal).padding(.top, 8)
    }

    var taktHeader: some View {
        HStack {
            Image(systemName: "clock.badge.checkmark").font(.caption).foregroundColor(.orange)
            Text("TAKTFAHRPLAN (CADENZAMENTO SVIZZERO)")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    func taktStationPicker(stations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hub di Convergenza (Nodi Takt)")
                .font(.caption2.bold()).foregroundColor(.secondary)
            Picker("Stazione Takt", selection: $vm.taktStationId) {
                Text("Nessun Hub specifico").tag("")
                ForEach(stations, id: \.self) { sid in
                    Text(vm.stationName(sid)).tag(sid)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.orange.opacity(0.1)).cornerRadius(8)
        }
    }

    func taktSuggestionCard(suggestion: (stationId: String, stationName: String,
                                          taktMinute: Int, suggestedArrival: String,
                                          suggestedDeparture: String)) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(suggestion.stationName).font(.subheadline.bold())
                Spacer()
                Text("Minuto :\(String(format: "%02d", suggestion.taktMinute))")
                    .font(.caption.bold()).foregroundColor(.orange)
            }
            HStack(spacing: 12) {
                taktTimeWindow(title: "Finestra Arrivi", value: suggestion.suggestedArrival,
                               color: .green)
                taktTimeWindow(title: "Finestra Partenze", value: suggestion.suggestedDeparture,
                               color: .blue)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.05)).cornerRadius(10)
    }

    func taktTimeWindow(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption.bold()).foregroundColor(color)
        }
        .padding(8)
        .background(color.opacity(0.08)).cornerRadius(8)
    }

    var taktEmptyMessage: some View {
        Text("Nessuna stazione nel percorso ha un minuto Takt configurato.")
            .font(.caption2).foregroundColor(.secondary).italic()
    }

    var taktInfoMessage: some View {
        Text("ℹ️ L'algoritmo cercherà di far convergere i treni tra -15/-5 minuti e ripartire tra +5/+15 minuti rispetto al minuto Takt.")
            .font(.caption2).foregroundColor(.secondary).italic()
    }
}

// MARK: - Cadence Selection

private extension ScheduleCreationView {

    var cadenceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROGRAMMAZIONE E FINESTRA DI SERVIZIO")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                if vm.mode != .taktfahrplan { geneticOptimizerToggle; Divider() }
                mainLineToggle; Divider()
                serviceTimeControls
                parityAndNumberControls
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    var geneticOptimizerToggle: some View {
        Toggle(isOn: $vm.useDepartureOptimizer) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile").foregroundColor(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ottimizzatore Genetico").font(.subheadline.bold())
                    Text(vm.mode == .single ?
                         "Trova automaticamente gli orari di partenza ottimali" :
                         "Ottimizza orari iniziali e intervalli tra i treni")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
    }

    var mainLineToggle: some View {
        Toggle(isOn: $vm.isMainLine) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Linea Principale (Takt)").font(.subheadline.bold())
                    Text("I treni di questa linea hanno la priorità negli hub")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
    }

    var serviceTimeControls: some View {
        VStack(spacing: 12) {
            startTimeRow
            if vm.mode == .cadenced || vm.mode == .taktfahrplan {
                endTimeRow
                frequencyRow
            }
            Divider().padding(.vertical, 4)
            returnToggle
        }
    }

    var startTimeRow: some View {
        HStack {
            Image(systemName: "clock").foregroundColor(.blue)
            Text("Inizio Servizio").font(.subheadline)
            Spacer()
            DatePicker("", selection: $vm.startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    var endTimeRow: some View {
        HStack {
            Image(systemName: "clock.fill").foregroundColor(.red)
            Text("Fine Servizio").font(.subheadline)
            Spacer()
            DatePicker("", selection: $vm.endTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    var frequencyRow: some View {
        HStack {
            Image(systemName: "repeat").foregroundColor(.green)
            Text("Frequenza").font(.subheadline)
            Spacer()
            if vm.mode == .taktfahrplan {
                Picker("", selection: $vm.intervalMinutes) {
                    Text("60 min").tag(60)
                    Text("120 min").tag(120)
                }
                .pickerStyle(.segmented).frame(width: 180)
            } else {
                Stepper("\(vm.intervalMinutes)m", value: $vm.intervalMinutes, in: 5...360, step: 5)
                    .font(.subheadline.bold())
            }
        }
    }

    var returnToggle: some View {
        Toggle(isOn: $vm.scheduleReturn) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                Text("Pianifica anche il ritorno").font(.subheadline.bold())
            }
        }
    }

    var parityAndNumberControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Parità Numerazione").font(.caption).foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $vm.preferredParity) {
                    ForEach(NumberParity.allCases) { p in Text(p.localizedName).tag(p) }
                }
                .pickerStyle(.segmented).frame(width: 120)
            }
            HStack {
                Text("N. Partenza").font(.caption).foregroundColor(.secondary)
                Spacer()
                TextField("", value: $vm.startNumber, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .font(.subheadline.bold())
                    .frame(width: 80).padding(4)
                    .background(Color.secondary.opacity(0.1)).cornerRadius(6)
            }
        }
    }
}

// MARK: - Generate Return Toggle & Preview

private extension ScheduleCreationView {

    var generateReturnToggle: some View {
        Toggle(isOn: $vm.scheduleReturn) {
            Label {
                Text("generate_return_trips".localized).font(.headline)
            } icon: {
                Image(systemName: "arrow.left.arrow.right").foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    var previewSection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .center) {
                    Text("CORSE").font(.caption2).foregroundColor(.secondary)
                    Text("\(vm.previewCount)")
                        .font(.title2.bold()).foregroundColor(.blue)
                }
                Divider().frame(height: 30)
                Toggle(isOn: $vm.optimizeVehicleRotation) {
                    VStack(alignment: .leading) {
                        Text("TURNI").font(.caption2).bold()
                        Text("Ottimizza mezzi").font(.caption).foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
}

// MARK: - Action Buttons

private extension ScheduleCreationView {

    var actionButtonsSection: some View {
        let isValid = vm.stationSequence.count >= 2

        return VStack(spacing: 12) {
            if let status = vm.aiStatus {
                optimizationProgressView(status: status)
            } else {
                generateButton(isValid: isValid)
            }
            if !isValid {
                Text("⚠️ Aggiungi almeno 2 stazioni alla linea")
                    .font(.caption).foregroundColor(.orange)
            }
            cancelButton
        }
        .padding()
    }

    func optimizationProgressView(status: String) -> some View {
        VStack(spacing: 14) {
            optimizationHeader(status: status)
            optimizationProgressBar
            stopOptimizationButton
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
        )
        .shadow(color: Color.blue.opacity(0.1), radius: 8, y: 4)
    }

    func optimizationHeader(status: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.blue.opacity(0.1)).frame(width: 36, height: 36)
                Image(systemName: "sparkles").foregroundColor(.blue).imageScale(.medium).symbolEffect(.pulse)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Analisi in corso").font(.caption.bold()).foregroundColor(.secondary)
                Text(status).font(.subheadline.bold()).foregroundColor(.primary)
            }
            Spacer()
        }
    }

    var optimizationProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)).frame(height: 8)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [.blue, .blue.opacity(0.7)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * max(0.02, vm.optimizerProgress), height: 8)
                    .animation(.easeInOut(duration: 0.3), value: vm.optimizerProgress)
            }
        }
        .frame(height: 8)
    }

    var stopOptimizationButton: some View {
        Button(action: {
            vm.aiTask?.cancel()
            vm.aiTask = nil
            vm.aiStatus = nil
            vm.optimizerProgress = 0.0
            vm.departureOptimizer.progressCallback = nil
        }) {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill").imageScale(.small)
                Text("FERMA OTTIMIZZAZIONE").font(.caption.bold())
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.red.opacity(0.08))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    func generateButton(isValid: Bool) -> some View {
        Button(action: {
            vm.aiTask = Task { await vm.proposeOptimizedTimes() }
        }) {
            HStack {
                Image(systemName: "sparkles")
                Text(isValid ? "GENERA ORARIO" : "CONFIGURA LINEA")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .cornerRadius(16)
            .shadow(color: (isValid ? Color.blue : Color.gray).opacity(0.3), radius: 8, y: 4)
        }
        .disabled(!isValid)
    }

    var cancelButton: some View {
        Button(action: { appState.creationLineId = nil }) {
            Text("cancel".localized.uppercased())
                .font(.caption.bold()).foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Optimization Overlay

private extension ScheduleCreationView {

    var optimizationOverlay: some View {
        ZStack {
            if vm.cadenceOptimizer.isRunning {
                Color.black.opacity(0.3).edgesIgnoringSafeArea(.all).transition(.opacity)
                overlayCard
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.cadenceOptimizer.isRunning)
    }

    var overlayCard: some View {
        VStack(spacing: 24) {
            overlayTitle
            overlayConflictBar
            overlayProgress
        }
        .padding(30)
        .frame(maxWidth: 400)
        .background(.regularMaterial)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    var overlayTitle: some View {
        Text(vm.cadenceOptimizer.isRunning ? "Calcolo Slot Ideale..." : "Ottimizzazione Orario...")
            .font(.title3.bold()).foregroundColor(.white)
            .shadow(radius: 5).padding(.top, 8)
    }

    var overlayConflictBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Conflitti").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                Text("\(Int(vm.cadenceOptimizer.fitness))")
                    .font(.title.bold().monospacedDigit()).foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    var overlayProgress: some View {
        VStack(spacing: 8) {
            ProgressView(value: vm.cadenceOptimizer.progress)
                .tint(.white)
            HStack {
                Text("\(Int(vm.cadenceOptimizer.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
        }
    }
}

// MARK: - Helpers

private extension ScheduleCreationView {

    func infoLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary).bold()
            Text(value).font(.body)
        }
    }
}

// MARK: - ViewModifiers for onChange handlers (split to reduce type-checker pressure)

struct ScheduleChangeModifiersA: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState
    let handleOptimizedTimesConfirmed: (Bool) -> Void
    let handleStationChange: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.optimizedTimesConfirmed) { _, confirmed in
                handleOptimizedTimesConfirmed(confirmed)
            }
            .onChange(of: vm.mode) { _, newMode in
                if newMode == .taktfahrplan && vm.intervalMinutes != 60 && vm.intervalMinutes != 120 {
                    vm.intervalMinutes = 120
                }
            }
            .onChange(of: vm.startStationId) { _, _ in handleStationChange() }
            .onChange(of: vm.endStationId) { _, _ in handleStationChange() }
            .onChange(of: vm.startTime) { _, _ in vm.updatePreview() }
            .onChange(of: vm.endTime) { _, _ in vm.updatePreview() }
    }
}

struct ScheduleChangeModifiersB: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .onChange(of: vm.intervalMinutes) { _, _ in vm.updatePreview() }
            .onChange(of: vm.scheduleReturn) { _, _ in vm.updatePreview() }
            .onChange(of: vm.stationSequence) { _, newSeq in
                if appState.useCloudAI && newSeq.count >= 2 { vm.triggerLineAnalysis() }
            }
            .onChange(of: vm.preferredParity) { _, newValue in
                vm.startNumber = (newValue == .odd) ? 1 : 2
                vm.returnStartNumber = (newValue == .odd) ? 2 : 1
            }
            .onChange(of: vm.startNumber) { _, newValue in
                vm.returnStartNumber = (newValue % 2 == 0) ? 1 : 2
            }
            .onChange(of: vm.selectedTrainType) { _, _ in vm.updateSuggestedVehicles() }
    }
}
