import SwiftUI
import Combine

/// Vista principale per la creazione di un orario ferroviario.
/// Delega tutta la logica di business al `ScheduleCreationViewModel`.
struct ScheduleCreationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var network: NetworkModel
    @EnvironmentObject var manager: LinesManager
    @EnvironmentObject var appState: AppState

    @StateObject private var vm: ScheduleCreationViewModel

    // UI-only state (not business logic)
    @State private var showModelSelector = false
    @State private var showOptimizedTimesPreview = false

    let route: TrainRoute

    /// Inizializza la vista con la relazione di servizio e la modalità iniziale.
    init(route: TrainRoute, initialMode: ScheduleMode = .single) {
        self.route = route
        self._vm = StateObject(wrappedValue: ScheduleCreationViewModel(line: route, initialMode: initialMode))
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

    /// Contenuto principale della vista: scroll del form + overlay di ottimizzazione.
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

// MARK: - Gestori Eventi (≤10 righe ciascuno)

private extension ScheduleCreationView {

    /// Gestisce la conferma degli orari ottimizzati dall'anteprima AI.
    func handleOptimizedTimesConfirmed(_ confirmed: Bool) {
        guard confirmed, let data = appState.optimizedTimesPreviewData else { return }
        vm.startTime = data.proposedOutboundTime
        vm.endTime = data.proposedReturnTime ?? vm.endTime
        vm.intervalMinutes = data.proposedInterval ?? vm.intervalMinutes
        appState.optimizedTimesPreviewData = nil
        appState.optimizedTimesConfirmed = false
        vm.aiTask = Task { await vm.generateSchedule() }
    }

    /// Gestisce il cambio di stazione di partenza o arrivo: aggiorna sequenza, calcoli e anteprima.
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

// MARK: - Layout del Form

private extension ScheduleCreationView {

    /// Contenuto scrollabile del form con tutte le sezioni.
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

// MARK: - Intestazione

private extension ScheduleCreationView {

    /// Intestazione con nome della linea e selettore modalità (singola/cadenzata/Takt).
    var headerSection: some View {
        HStack {
            Text(String(format: "schedule_gen_line_fmt".localized, route.name))
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

// MARK: - Selezione Stazioni

private extension ScheduleCreationView {

    /// Sezione per la selezione delle stazioni di partenza e arrivo.
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

    /// Riga singola con picker di selezione stazione.
    func stationPickerRow(title: String, selection: Binding<String>) -> some View {
        StationPickerRow(title: title, selection: selection, route: route, network: network, vm: vm)
    }
}

struct StationPickerRow: View {
    let title: String
    @Binding var selection: String
    let route: TrainRoute
    let network: NetworkModel
    let vm: ScheduleCreationViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            Picker(title, selection: $selection) {
                ForEach(route.stationIds, id: \.self) { stationId in
                    HStack(spacing: 8) {
                        StationSymbolView(station: network.nodes.first(where: { $0.id == stationId }), size: 14)
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
}

// MARK: - Dettagli Percorso

private extension ScheduleCreationView {

    /// Sezione con metriche percorso, tipologia treno e selezione materiale rotabile.
    var pathInfoRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETTAGLI SERVIZIO")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                metricsRow
                infrastructureCharacteristicsRow
                Divider()
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

    /// Riga con le metriche di servizio: stazioni, distanza e durata stimata.
    var metricsRow: some View {
        HStack(spacing: 12) {
            ScheduleMetricView(label: "Stazioni", value: "\(vm.stationSequence.count)")
            ScheduleMetricView(label: "Distanza", value: String(format: "%.1fkm", vm.estimatedDistance))
            ScheduleMetricView(label: "Durata St.", value: "\(vm.estimatedTravelTime)m")
            Spacer()
        }
    }

    /// Riga con le caratteristiche fisiche dell'infrastruttura: elettrificazione, pendenza, spaziatura fermate.
    var infrastructureCharacteristicsRow: some View {
        let lc = vm.lineCharacteristics
        return HStack(spacing: 8) {
            infraBadge(
                icon: lc.isElectrified ? "bolt.fill" : "fuelpump.fill",
                label: lc.isElectrified ? "Elettrificata" : "Non elettrificata",
                color: lc.isElectrified ? .yellow : .orange
            )
            if let grad = lc.maxGradient {
                infraBadge(
                    icon: gradientIcon(grad),
                    label: gradientLabel(grad),
                    color: gradientColor(grad)
                )
            }
            infraBadge(
                icon: lc.isFrequentStops ? "tram.fill" : "train.side.front.car",
                label: lc.isFrequentStops ? "Fermate ravvic." : String(format: "%.0f km/fermata", lc.averageStopDistance),
                color: lc.isFrequentStops ? .purple : .blue
            )
            Spacer()
        }
    }

    private func infraBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(color.opacity(0.12))
        .cornerRadius(8)
    }

    private func gradientIcon(_ g: Double) -> String {
        if g > 30 { return "mountain.2.fill" }
        if g > 15 { return "chevron.up.2" }
        if g > 5  { return "chevron.up" }
        return "minus"
    }

    private func gradientLabel(_ g: Double) -> String {
        if g > 30 { return String(format: "%.0f‰ Ripida", g) }
        if g > 15 { return String(format: "%.0f‰ Montana", g) }
        if g > 5  { return String(format: "%.0f‰ Collinare", g) }
        return String(format: "%.0f‰ Pianura", g)
    }

    private func gradientColor(_ g: Double) -> Color {
        if g > 30 { return .red }
        if g > 15 { return .orange }
        if g > 5  { return .yellow }
        return .green
    }

    /// Picker per la selezione del tipo di treno (regionale, diretto, AV, ecc.).
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

    /// Sezione per la selezione del materiale rotabile (veicolo/modello).
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

    /// Pulsante che apre il selettore modello treno in un foglio modale.
    var vehicleSelectionMenu: some View {
        Button(action: { showModelSelector = true }) {
            vehicleMenuContent
        }
        .sheet(isPresented: $showModelSelector) {
            TrainModelSelectorView(
                selectedModel: $vm.selectedModel,
                lineCharacteristics: vm.lineCharacteristics
            )
        }
    }

    /// Contenuto del pulsante di selezione veicolo (miniatura + info oppure placeholder).
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

    /// Miniatura dell'immagine del modello di treno selezionato.
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

    /// Informazioni testuale del modello: nome, costruttore, velocità e accelerazione.
    func vehicleModelInfo(model: TrainModel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.nome).font(.subheadline.bold())
            Text("\(model.costruttore) • \(model.specifiche.velocita_max_kmh)km/h • \(String(format: "%.1f", model.fisica.accelerazione_m_s2))m/s²")
                .font(.caption2).foregroundColor(.secondary)
        }
    }
}

// MARK: - Schema Fermate

private extension ScheduleCreationView {

    /// Sezione con lo schema delle fermate: quali stazioni vengono servite o saltate.
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

    /// Intestazione dello schema fermate con pulsanti rapidi (Locale, Intercity, Diretto).
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

    /// Pulsante "Locale": rimuove tutti i salti (ferma ovunque).
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

    /// Pulsante "Intercity": salta le stazioni non principali (senza simbolo quadrato).
    var intercityButton: some View {
        Button(action: { vm.applyIntercityPattern() }) {
            Text("Intercity")
                .font(.caption2.bold())
                .foregroundColor(.purple)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .cornerRadius(6)
        }
    }

    /// Pulsante "Diretto": salta tutte le fermate intermedie.
    var direttoButton: some View {
        let allSkipped = vm.skippedStopIds.count == max(0, vm.stationSequence.count - 2)
        return Button(action: { vm.applyExpressPattern() }) {
            Text("Diretto")
                .font(.caption2.bold())
                .foregroundColor(allSkipped ? .white : .orange)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(allSkipped ? Color.orange : Color.orange.opacity(0.2))
                .cornerRadius(6)
        }
    }


    /// Lista delle fermate con indicatore visivo e toggle di attivazione.
    var stopPatternList: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.stationSequence.enumerated()), id: \.offset) { index, stationId in
                stopPatternRow(index: index, stationId: stationId)
            }
        }
    }

    /// Singola riga nello schema fermate con indicatore, nome e toggle salta/ferma.
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

    /// Pallino indicatore: blu pieno se fermata, grigio se saltata.
    func stopIndicator(isSkipped: Bool) -> some View {
        ZStack {
            Circle().fill(isSkipped ? Color.gray.opacity(0.3) : Color.blue)
                .frame(width: 16, height: 16)
            if !isSkipped {
                Circle().fill(Color.white).frame(width: 6, height: 6)
            }
        }
    }

    /// Etichetta con nome stazione e ruolo (partenza/arrivo/transito).
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

    /// Pulsante toggle per saltare o ripristinare una fermata intermedia.
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

    /// Messaggio mostrato quando non ci sono abbastanza stazioni per lo schema.
    var emptyStopPatternMessage: some View {
        Text("Aggiungi almeno 2 stazioni per configurare lo schema fermate")
            .font(.caption).foregroundColor(.secondary).italic().padding()
    }
}

// MARK: - Sezione Taktfahrplan

private extension ScheduleCreationView {

    /// Sezione Taktfahrplan: selezione hub di convergenza e suggerimenti finestre temporali.
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

    /// Intestazione sezione Taktfahrplan.
    var taktHeader: some View {
        HStack {
            Image(systemName: "clock.badge.checkmark").font(.caption).foregroundColor(.orange)
            Text("TAKTFAHRPLAN (CADENZAMENTO SVIZZERO)")
                .font(.system(.caption, design: .rounded).bold())
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    /// Picker per selezionare la stazione hub Takt di riferimento.
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

    /// Card con i suggerimenti di finestra arrivo/partenza per la stazione Takt selezionata.
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

    /// Blocco con titolo e valore per una finestra temporale Takt.
    func taktTimeWindow(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption.bold()).foregroundColor(color)
        }
        .padding(8)
        .background(color.opacity(0.08)).cornerRadius(8)
    }

    /// Messaggio quando nessuna stazione ha un minuto Takt configurato.
    var taktEmptyMessage: some View {
        Text("Nessuna stazione nel percorso ha un minuto Takt configurato.")
            .font(.caption2).foregroundColor(.secondary).italic()
    }

    /// Nota informativa sull'algoritmo di convergenza Takt.
    var taktInfoMessage: some View {
        Text("ℹ️ L'algoritmo cercherà di far convergere i treni tra -15/-5 minuti e ripartire tra +5/+15 minuti rispetto al minuto Takt.")
            .font(.caption2).foregroundColor(.secondary).italic()
    }
}

// MARK: - Selezione Cadenza

private extension ScheduleCreationView {

    /// Sezione programmazione: ottimizzatore, orari servizio, frequenza e numerazione.
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

    /// Toggle per abilitare l'ottimizzatore genetico degli orari.
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

    /// Toggle per indicare se questa è la linea principale con priorità Takt.
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

    /// Controlli per gli orari di inizio/fine servizio e frequenza.
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

    /// Selezione orario di inizio servizio.
    var startTimeRow: some View {
        HStack {
            Image(systemName: "clock").foregroundColor(.blue)
            Text("Inizio Servizio").font(.subheadline)
            Spacer()
            DatePicker("", selection: $vm.startTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// Selezione orario di fine servizio (solo per modalità cadenzata/Takt).
    var endTimeRow: some View {
        HStack {
            Image(systemName: "clock.fill").foregroundColor(.red)
            Text("Fine Servizio").font(.subheadline)
            Spacer()
            DatePicker("", selection: $vm.endTime, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }

    /// Selezione della frequenza/intervallo tra le corse.
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

    /// Toggle per pianificare anche le corse di ritorno.
    var returnToggle: some View {
        Toggle(isOn: $vm.scheduleReturn) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                Text("Pianifica anche il ritorno").font(.subheadline.bold())
            }
        }
    }

    /// Controlli per la parità della numerazione e il numero di partenza.
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

// MARK: - Toggle Ritorno e Anteprima

private extension ScheduleCreationView {

    /// Toggle aggiuntivo per la generazione delle corse di ritorno.
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

    /// Sezione anteprima con conteggio corse.
    var previewSection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .center) {
                    Text("CORSE").font(.caption2).foregroundColor(.secondary)
                    Text("\(vm.previewCount)")
                        .font(.title2.bold()).foregroundColor(.blue)
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading) {
                    Text("TURNI").font(.caption2).bold()
                    Text("Gestiti nel menu dedicato")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
}

// MARK: - Pulsanti Azione

private extension ScheduleCreationView {

    /// Sezione con i pulsanti di azione: genera orario, annulla, stato ottimizzazione.
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

    /// Vista di progresso durante l'ottimizzazione con barra e pulsante di arresto.
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

    /// Intestazione dell'area di ottimizzazione con icona animata e stato testuale.
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

    /// Barra di progresso animata dell'ottimizzazione.
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

    /// Pulsante per interrompere l'ottimizzazione in corso.
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

    /// Pulsante principale per generare l'orario (disabilitato se la configurazione non è valida).
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

    /// Pulsante di annullamento per chiudere la vista senza generare.
    var cancelButton: some View {
        Button(action: { appState.creationRouteId = nil }) {
            Text("cancel".localized.uppercased())
                .font(.caption.bold()).foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Overlay Ottimizzazione

private extension ScheduleCreationView {

    /// Overlay a schermo intero mostrato durante l'ottimizzazione della cadenza.
    var optimizationOverlay: some View {
        ZStack {
            if vm.cadenceOptimizer.isRunning {
                Color.black.opacity(0.3).edgesIgnoringSafeArea(.all).transition(.opacity)
                overlayCard
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.cadenceOptimizer.isRunning)
    }

    /// Card centrale dell'overlay con titolo, barra conflitti e progresso.
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

    /// Titolo dell'overlay ("Calcolo Slot Ideale" o "Ottimizzazione Orario").
    var overlayTitle: some View {
        Text(vm.cadenceOptimizer.isRunning ? "Calcolo Slot Ideale..." : "Ottimizzazione Orario...")
            .font(.title3.bold()).foregroundColor(.white)
            .shadow(radius: 5).padding(.top, 8)
    }

    /// Barra che mostra il conteggio conflitti corrente durante l'ottimizzazione.
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

    /// Barra di progresso percentuale dell'ottimizzazione della cadenza.
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

// MARK: - Componenti di Supporto

private extension ScheduleCreationView {

    /// Etichetta informativa generica con titolo e valore.
    func infoLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.secondary).bold()
            Text(value).font(.body)
        }
    }
}

// MARK: - ViewModifier per i gestori onChange (divisi per ridurre la pressione sul type-checker)

/// Primo gruppo di ViewModifier onChange: gestisce conferma orari ottimizzati,
/// cambio modalità, cambio stazioni e aggiornamento orari.
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

/// Secondo gruppo di ViewModifier onChange: gestisce intervallo, ritorno,
/// sequenza stazioni, parità, numero iniziale e tipo treno.
struct ScheduleChangeModifiersB: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .modifier(ScheduleChangeModifiersB1(vm: vm))
            .modifier(ScheduleChangeModifiersB2(vm: vm, appState: appState))
    }
}

struct ScheduleChangeModifiersB1: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: vm.intervalMinutes) { (oldValue: Int, newValue: Int) in vm.updatePreview() }
            .onChange(of: vm.scheduleReturn) { (oldValue: Bool, newValue: Bool) in vm.updatePreview() }
            .onChange(of: vm.preferredParity) { (oldValue: NumberParity, newValue: NumberParity) in
                vm.startNumber = (newValue == .odd) ? 1 : 2
                vm.returnStartNumber = (newValue == .odd) ? 2 : 1
            }
            .onChange(of: vm.startNumber) { (oldValue: Int, newValue: Int) in
                vm.returnStartNumber = (newValue % 2 == 0) ? 1 : 2
            }
    }
}

struct ScheduleChangeModifiersB2: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .onChange(of: vm.stationSequence) { (oldValue: [String], newValue: [String]) in
                // if appState.useCloudAI && newValue.count >= 2 { vm.triggerLineAnalysis() }
            }
            .onChange(of: vm.selectedTrainType) { (oldValue: TrainCategory, newValue: TrainCategory) in
                vm.updateSuggestedVehicles()
            }
    }
}
