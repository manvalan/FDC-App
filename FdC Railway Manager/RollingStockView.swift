import SwiftUI

enum VehicleGroupingMode: String, CaseIterable, Identifiable {
    case byName = "Nome"
    case byManufacturer = "Produttore"
    case byModel = "Modello"
    case byLine = "Linea"
    
    var id: String { rawValue }
}

struct RollingStockView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var manager: LinesManager
    
    @State private var showingAddSheet = false
    @State private var isListEditMode: EditMode = .inactive
    @State private var groupingMode: VehicleGroupingMode = .byName
    
    init(manager: LinesManager) {
        self.manager = manager
    }
    
    private var sortedVehicles: [Vehicle] {
        manager.vehicles.sorted { $0.name < $1.name }
    }
    
    private var manufacturer: String {
        // Extract manufacturer from model
        let model = appState.selectedVehicle?.model.uppercased() ?? ""
        if model.contains("ETR") || model.contains("ALN") { return "Alstom" }
        if model.contains("HTR") || model.contains("TAF") || model.contains("TSR") { return "Hitachi" }
        if model.contains("ATR 803") { return "Stadler" }
        if model.contains("ETR 170") || model.contains("ETR 343") { return "Stadler" }
        if model.contains("ATR 220") || model.contains("SWING") { return "Pesa" }
        if model.contains("E.464") || model.contains("E464") || model.contains("E.494") || model.contains("E.191") || model.contains("E.652") || model.contains("D.445") { return "Locomotive" }
        return "Altro"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Materiale Rotabile").font(.headline).foregroundColor(appState.theme.dark)
                Spacer()
                Button(action: {
                    showingAddSheet = true
                }) {
                    Label("Nuovo", systemImage: "plus.circle.fill").font(.subheadline.bold())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(appState.theme.accent)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            // Grouping Mode Picker
            Picker("Visualizza per", selection: $groupingMode) {
                ForEach(VehicleGroupingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // List based on grouping mode
            switch groupingMode {
            case .byName:
                vehicleListByName
            case .byManufacturer:
                vehicleListByManufacturer
            case .byModel:
                vehicleListByModel
            case .byLine:
                vehicleListByLine
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VehicleEditSheet(manager: manager, vehicle: nil as RailwayVehicle?)
                .environmentObject(appState)
        }
    }
    
    // MARK: - List Views by Grouping Mode
    
    private var vehicleListByName: some View {
        List {
            ForEach(sortedVehicles) { vehicle in
                VehicleRowContent(vehicle: vehicle, manager: manager)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isListEditMode == .inactive {
                            appState.selectedVehicleId = vehicle.id
                        }
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        withAnimation {
                            isListEditMode = (isListEditMode == .active) ? .inactive : .active
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteVehicles)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $isListEditMode)
    }
    
    private var vehicleListByManufacturer: some View {
        let grouped = Dictionary(grouping: manager.vehicles) { vehicle -> String in
            getManufacturer(for: vehicle.model)
        }
        
        return List {
            ForEach(grouped.keys.sorted(), id: \.self) { manufacturer in
                Section(header: Text(manufacturer).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[manufacturer]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var vehicleListByModel: some View {
        let grouped = Dictionary(grouping: manager.vehicles, by: { $0.model })
        
        return List {
            ForEach(grouped.keys.sorted(), id: \.self) { model in
                Section(header: Text(model).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[model]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var vehicleListByLine: some View {
        // Group vehicles by which line's trains they're assigned to
        var grouped: [String: [RailwayVehicle]] = [:]
        var unassigned: [Vehicle] = []
        
        for vehicle in manager.vehicles {
            let assignedTrains = manager.trains.filter { $0.vehicleId == vehicle.id }
            if assignedTrains.isEmpty {
                unassigned.append(vehicle)
            } else {
                for train in assignedTrains {
                    if let routeId = train.routeId,
                       let route = manager.routes.first(where: { $0.id == routeId }) {
                        if grouped[route.name] == nil {
                            grouped[route.name] = []
                        }
                        if !grouped[route.name]!.contains(where: { $0.id == vehicle.id }) {
                            grouped[route.name]!.append(vehicle)
                        }
                    }
                }
            }
        }
        
        return List {
            if !unassigned.isEmpty {
                Section(header: Text("Non Assegnati").font(.headline).foregroundColor(.secondary)) {
                    ForEach(unassigned.sorted { $0.name < $1.name }) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
            
            ForEach(grouped.keys.sorted(), id: \.self) { lineName in
                Section(header: Text(lineName).font(.headline).foregroundColor(appState.theme.dark)) {
                    ForEach(grouped[lineName]?.sorted { $0.name < $1.name } ?? []) { vehicle in
                        VehicleRowContent(vehicle: vehicle, manager: manager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isListEditMode == .inactive {
                                    appState.selectedVehicleId = vehicle.id
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Helper Functions
    
    private func getManufacturer(for model: String) -> String {
        let m = model.uppercased()
        if m.contains("ETR 103") || m.contains("ETR 104") || m.contains("ETR 204") || m.contains("ETR 255") { return "Alstom (Pop)" }
        if m.contains("ETR 425") || m.contains("ETR 324") { return "Alstom (Jazz)" }
        if m.contains("ALN 501") || m.contains("MINUETTO") { return "Alstom (Minuetto)" }
        if m.contains("ETR 600") || m.contains("ETR 610") || m.contains("ETR 485") { return "Alstom (Pendolino)" }
        if m.contains("ETR 1000") || m.contains("ETR 500") || m.contains("FRECCIAROSSA") { return "Hitachi (Frecciarossa)" }
        if m.contains("ETR 700") || m.contains("FRECCIARGENTO") { return "Hitachi (Frecciargento)" }
        if m.contains("ETR 421") || m.contains("ETR 521") || m.contains("ETR 621") { return "Hitachi (Rock)" }
        if m.contains("HTR 312") || m.contains("HTR 412") { return "Hitachi (Blues)" }
        if m.contains("TAF") { return "Hitachi (TAF)" }
        if m.contains("TSR") { return "Hitachi (TSR)" }
        if m.contains("ETR 170") || m.contains("FLIRT") { return "Stadler (FLIRT)" }
        if m.contains("ETR 343") { return "Stadler (FLIRT XL)" }
        if m.contains("ATR 803") || m.contains("COLLEONI") { return "Stadler (Colleoni)" }
        if m.contains("ATR 220") || m.contains("SWING") { return "Pesa (Swing)" }
        if m.contains("E.464") || m.contains("E464") { return "Locomotive (E.464)" }
        if m.contains("E.494") { return "Locomotive (TRAXX)" }
        if m.contains("E.191") || m.contains("E.193") { return "Locomotive (Vectron)" }
        if m.contains("E.652") { return "Locomotive (Caimano)" }
        if m.contains("D.445") { return "Locomotive (Diesel)" }
        return "Altro"
    }
    
    private func deleteVehicles(at offsets: IndexSet) {
        for index in offsets {
            let vehicle = sortedVehicles[index]
            // First unassign trains
            for tIdx in manager.trains.indices {
                if manager.trains[tIdx].vehicleId == vehicle.id {
                    manager.trains[tIdx].vehicleId = nil
                }
            }
            manager.vehicles.removeAll { $0.id == vehicle.id }
        }
        manager.createCheckpoint()
    }
}

struct VehicleRowContent: View {
    let vehicle: Vehicle
    let manager: LinesManager
    @EnvironmentObject var appState: AppState
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") { return .purple }
        return .secondary
    }
    
    private var assignedTrains: [Train] {
        manager.trains.filter { $0.vehicleId == vehicle.id }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Vehicle photo or badge icon
            Group {
                if let imageName = vehicle.imageName, !imageName.isEmpty, let _ = UIImage(named: imageName) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(modelColor.opacity(0.15))
                        Text(String(vehicle.model.prefix(3)).uppercased())
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(modelColor)
                    }
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text("\(vehicle.model) • \(Int(vehicle.length))m • \(Int(vehicle.maxSpeed)) km/h")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                if !assignedTrains.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(assignedTrains.prefix(3)) { train in
                                Text(train.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                            if assignedTrains.count > 3 {
                                Text("+\(assignedTrains.count - 3)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedVehicleId == vehicle.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedVehicleId == vehicle.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}

struct VehicleRow: View {
    let vehicle: Vehicle
    let trains: [Train]
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(modelColor.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: "train.side.front.car")
                    .foregroundColor(modelColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(vehicle.name)
                        .font(.headline)
                    Spacer()
                    Text(vehicle.model)
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(modelColor.opacity(0.15))
                        .foregroundColor(modelColor)
                        .cornerRadius(4)
                }
                
                HStack(spacing: 12) {
                    Label("\(Int(vehicle.length))m", systemImage: "arrow.left.and.right")
                    Label("\(Int(vehicle.maxSpeed)) km/h", systemImage: "gauge.with.dots.needle.67percent")
                    
                    let conflicts = manager.getVehicleConflicts(for: vehicle.id)
                    if !conflicts.isEmpty {
                        Label("\(conflicts.count) conflitti", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                
                if trains.isEmpty {
                    Text("Nessun treno assegnato")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.6))
                        .italic()
                } else {
                    let sorted = trains.sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(sorted) { train in
                                Text(train.name)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundColor(.accentColor)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") { return .purple }
        return .secondary
    }
}


