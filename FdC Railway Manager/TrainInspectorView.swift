import SwiftUI

// MARK: - Train Inspector
struct TrainInspectorView: View {
    let train: RailwayTrain
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var manager: LinesManager
    @StateObject private var wikiImageService = WikiImageService()
    
    @State private var isEditingEnabled = false
    @State private var showVehicleSheet = false
    
    private var network: NetworkModel { appState.railroad.network }
    
    private var trainBinding: Binding<RailwayTrain>? {
        manager.binding(for: train)
    }
    
    private var trainConflicts: [ScheduleConflict] {
        appState.railroad.lines.conflictManager.conflicts.filter {
            $0.trainAId == train.id || $0.trainBId == train.id
        }
    }
    
    var body: some View {
        Group {
            if let binding = trainBinding {
                content(train: binding)
            } else {
                InspectorView(
                    title: "train_not_found".localized,
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    onBack: nil,
                    onClose: { appState.clearSelection() }
                ) {
                    Text("train_not_found_message".localized)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            isEditingEnabled.toggle()
        }
    }
    
    private func content(train: Binding<RailwayTrain>) -> some View {
        InspectorView(
            title: train.wrappedValue.name,
            icon: "train.side.front.car",
            iconColor: .blue,
            onBack: nil,
            onClose: {
                withAnimation {
                    appState.clearSelection()
                }
            }
        ) {
            EditingModeBanner(isEditingEnabled: $isEditingEnabled)
            
            if !trainConflicts.isEmpty {
                conflictBanner
            }
            
            if let error = train.wrappedValue.schedulingError {
                schedulingErrorBanner(error)
            }
            
            identificationSection(train: train)
            vehicleAssignmentSection(train: train)
            timetableSection(train: train)
        }
        .disabled(!isEditingEnabled)
        .onAppear {
            isEditingEnabled = true
        }
        .onDisappear {
            isEditingEnabled = false
        }
    }
    
    // MARK: - Banners
    
    private var conflictBanner: some View {
        InspectorInfoBanner(
            type: .error,
            title: "active_conflicts".localized,
            message: String(format: "train_conflicts_count".localized, trainConflicts.count)
        )
    }
    
    private func schedulingErrorBanner(_ error: String) -> some View {
        InspectorInfoBanner(
            type: .warning,
            title: "scheduling_error".localized,
            message: error
        )
    }
    
    // MARK: - Sections
    
    private func identificationSection(train: Binding<RailwayTrain>) -> some View {
        InspectorSection(title: "identification".localized, icon: "tag.fill", iconColor: .blue) {
            HStack(alignment: .top, spacing: 16) {
                vehicleImage(train: train.wrappedValue)
                
                VStack(alignment: .leading, spacing: 8) {
                    InspectorTextField(
                        label: "train_name".localized,
                        text: train.name,
                        placeholder: "ES 9600"
                    )
                    
                    Picker("type_label".localized, selection: train.type) {
                        Text("regional_type".localized).tag("Regionale")
                        Text("direct_type".localized).tag("Diretto")
                        Text("high_speed_type".localized).tag("Alta Velocità")
                        Text("merci_type".localized).tag("Merci")
                        Text("support_type".localized).tag("Supporto")
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
    
    private func vehicleImage(train: RailwayTrain) -> some View {
        Group {
            if let vId = train.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                
                if let imageName = vehicle.imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else if let url = wikiImageService.currentImageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            ProgressView()
                        }
                    }
                } else {
                    Image(systemName: "train.side.front.car")
                        .font(.title)
                        .foregroundColor(.blue)
                }
            } else {
                Image(systemName: "train.side.front.car")
                    .font(.title)
                    .foregroundColor(.blue)
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .clipped()
        .onAppear {
            if let vId = train.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }),
               vehicle.imageName == nil || UIImage(named: vehicle.imageName ?? "") == nil {
                wikiImageService.searchImage(for: vehicle.model)
            }
        }
    }
    
    private func vehicleAssignmentSection(train: Binding<RailwayTrain>) -> some View {
        InspectorSection(title: "materiale_rotabile".localized, icon: "bus.doubledecker.fill", iconColor: .purple) {
            if train.wrappedValue.vehicleId == nil {
                InspectorInfoBanner(
                    type: .error,
                    title: "warning".localized,
                    message: "vehicle_assignment_required".localized
                )
            }
            
            vehicleMenu(train: train)
            
            if let vId = train.wrappedValue.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                
                vehicleDetailsButton
                vehicleMetrics(vehicle: vehicle)
                vehicleConflicts(train: train, vehicleId: vId)
            }
        }
    }
    
    private func vehicleMenu(train: Binding<RailwayTrain>) -> some View {
        Menu {
            Button("no_vehicle".localized) {
                train.wrappedValue.vehicleId = nil
            }
            
            let models = Array(Set(manager.vehicles.map { $0.model })).sorted()
            
            ForEach(models, id: \.self) { model in
                Menu(model) {
                    let vehiclesInModel = manager.vehicles.filter { $0.model == model }
                    ForEach(vehiclesInModel) { v in
                        Button(v.name) {
                            train.wrappedValue.vehicleId = v.id
                            train.wrappedValue.maxSpeed = v.maxSpeed
                            train.wrappedValue.acceleration = v.acceleration
                            train.wrappedValue.deceleration = v.deceleration
                        }
                    }
                }
            }
        } label: {
            HStack {
                if let vId = train.wrappedValue.vehicleId,
                   let v = manager.vehicles.first(where: { $0.id == vId }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(v.name)
                            .font(.system(.body, design: .rounded).bold())
                        Text(v.model)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("select_vehicle".localized)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var vehicleDetailsButton: some View {
        Button(action: { showVehicleSheet = true }) {
            HStack {
                Image(systemName: "info.circle")
                Text("vehicle_details".localized)
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showVehicleSheet) {
            if let vId = train.vehicleId,
               let vehicle = manager.vehicles.first(where: { $0.id == vId }) {
                VehicleEditSheet(manager: manager, vehicle: vehicle)
            }
        }
    }
    
    private func vehicleMetrics(vehicle: RailwayVehicle) -> some View {
        HStack(spacing: 16) {
            MetricView(label: "length".localized, value: "\(Int(vehicle.length))m")
            MetricView(label: "max_speed".localized, value: "\(Int(vehicle.maxSpeed))km/h")
            MetricView(label: "acceleration".localized, value: String(format: "%.2f m/s²", vehicle.acceleration))
            Spacer()
        }
        .padding(.top, 4)
    }
    
    private func vehicleConflicts(train: Binding<RailwayTrain>, vehicleId: UUID) -> some View {
        Group {
            let conflicts = manager.getVehicleConflicts(for: vehicleId).filter {
                $0.trainA.id == train.wrappedValue.id || $0.trainB.id == train.wrappedValue.id
            }
            
            if let firstConflict = conflicts.first {
                InspectorInfoBanner(
                    type: .error,
                    title: nil,
                    message: firstConflict.description
                )
            }
        }
    }
    
    private func timetableSection(train: Binding<RailwayTrain>) -> some View {
        InspectorSection(title: "assigned_service".localized, icon: "clock.fill", iconColor: .orange) {
            if let lineId = train.wrappedValue.lineId,
               let line = manager.lines.first(where: { $0.id == lineId }) {
                
                lineInfo(line: line)
                priorityStepper(train: train)
                itineraryView(train: train, line: line)
                
            } else {
                noLineAssignedView
            }
        }
    }
    
    private func lineInfo(line: RailwayLine) -> some View {
        HStack {
            if let color = line.color {
                Circle()
                    .fill(Color(hex: color) ?? .clear)
                    .frame(width: 8, height: 8)
            }
            Text(String(format: "line_label_fmt".localized, line.name))
                .font(.subheadline.bold())
            Spacer()
        }
    }
    
    private func priorityStepper(train: Binding<RailwayTrain>) -> some View {
        HStack(spacing: 4) {
            Text("priority".localized + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Stepper(value: train.priority, in: 1...10) {
                Text("\(train.wrappedValue.priority)")
                    .font(.caption.bold())
                    .foregroundColor(priorityColor(train.wrappedValue.priority))
            }
            .fixedSize()
            .labelsHidden()
        }
    }
    
    private func itineraryView(train: Binding<RailwayTrain>, line: RailwayLine) -> some View {
        RailwayItineraryView(
            train: train,
            network: appState.railroad.network,
            lineColor: Color(hex: line.color ?? ""),
            isReadOnly: !isEditingEnabled
        )
        .frame(minHeight: 400)
        .cornerRadius(12)
    }
    
    private var noLineAssignedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.3))
            Text("no_line_assigned".localized)
                .italic()
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func priorityColor(_ p: Int) -> Color {
        if p <= 2 { return .red }
        if p <= 5 { return .orange }
        return .blue
    }
}
