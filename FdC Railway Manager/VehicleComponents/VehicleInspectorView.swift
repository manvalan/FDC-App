import SwiftUI

struct VehicleInspectorView: View {
    let vehicle: Vehicle
    @EnvironmentObject var appState: AppState
    var manager: LinesManager { appState.railroad.lines }
    
    private var modelColor: Color {
        let m = vehicle.model.lowercased()
        if m.contains("coradia") || m.contains("pop") || m.contains("jazz") || m.contains("minuetto") { return .blue }
        if m.contains("caravaggio") || m.contains("rock") { return .orange }
        if m.contains("pesa") || m.contains("swing") { return .green }
        if m.contains("stadler") || m.contains("colleoni") { return .red }
        if m.contains("navetta") || m.contains("e.464") || m.contains("e464") { return .purple }
        if m.contains("etr") && (m.contains("1000") || m.contains("500") || m.contains("700")) { return .red }
        return .secondary
    }
    
    private var assignedTrains: [Train] {
        manager.trains.filter { $0.vehicleId == vehicle.id }
            .sorted { ($0.departureTime ?? Date.distantPast) < ($1.departureTime ?? Date.distantPast) }
    }
    
    private var imageName: String {
        let model = vehicle.model.uppercased()
        if model.contains("ETR 103") { return "ETR_103_Pop" }
        if model.contains("ETR 104") { return "ETR_104_Pop" }
        if model.contains("ETR 204") { return "ETR_204_Pop" }
        if model.contains("ETR 255") { return "ETR_255_Pop" }
        if model.contains("ETR 425") { return "ETR_425_Jazz" }
        if model.contains("ETR 324") { return "ETR_324_Jazz" }
        if model.contains("ALN 501") || model.contains("MINUETTO") { return "ALn_501_Minuetto" }
        if model.contains("ETR 600") || model.contains("ETR 610") { return "ETR_600_Pendolino" }
        if model.contains("ETR 485") { return "ETR_485_Pendolino" }
        if model.contains("ETR 1000") { return "ETR_1000_Frecciarossa" }
        if model.contains("ETR 500") { return "ETR_500_Frecciarossa" }
        if model.contains("ETR 700") { return "ETR_700_Frecciargento" }
        if model.contains("ETR 421") { return "ETR_421_Rock" }
        if model.contains("ETR 521") { return "ETR_521_Rock" }
        if model.contains("ETR 621") { return "ETR_621_Rock" }
        if model.contains("HTR 312") { return "HTR_312_Blues" }
        if model.contains("HTR 412") { return "HTR_412_Blues" }
        if model.contains("ETR 170") { return "ETR_170_FLIRT" }
        if model.contains("ATR 220") || model.contains("SWING") { return "ATR_220_Swing" }
        if model.contains("E.464") || model.contains("E464") { return "Locomotiva_E464" }
        if model.contains("TSR") { return "Treno_Servizio_Regionale_TSR" }
        return ""
    }
    
    private var trainIconForModel: String {
        let model = vehicle.model.uppercased()
        // High-speed trains
        if model.contains("FRECCIAROSSA") || model.contains("ETR 1000") || model.contains("ETR 500") {
            return "train.side.front.car"
        }
        // Frecciargento
        if model.contains("FRECCIARGENTO") || model.contains("ETR 700") {
            return "train.side.front.car"
        }
        // Pendolino (tilting trains)
        if model.contains("PENDOLINO") || model.contains("ETR 600") || model.contains("ETR 610") || model.contains("ETR 485") {
            return "tram.fill.tunnel"
        }
        // Regional EMUs (Pop, Rock, Jazz)
        if model.contains("POP") || model.contains("ROCK") || model.contains("JAZZ") || 
           model.contains("ETR 103") || model.contains("ETR 104") || model.contains("ETR 204") || 
           model.contains("ETR 255") || model.contains("ETR 421") || model.contains("ETR 521") || 
           model.contains("ETR 621") || model.contains("ETR 425") || model.contains("ETR 324") {
            return "tram.fill"
        }
        // Blues
        if model.contains("BLUES") || model.contains("HTR 312") || model.contains("HTR 412") {
            return "tram.fill"
        }
        // Light rail (Minuetto)
        if model.contains("MINUETTO") || model.contains("ALN 501") {
            return "tram"
        }
        // Stadler (FLIRT, Colleoni)
        if model.contains("STADLER") || model.contains("FLIRT") || model.contains("COLLEONI") || 
           model.contains("ETR 170") || model.contains("ATR 803") {
            return "tram.fill"
        }
        // Pesa Swing
        if model.contains("SWING") || model.contains("ATR 220") {
            return "tram.fill"
        }
        // Locomotives
        if model.contains("LOCOMOTIVA") || model.contains("E.464") || model.contains("E464") || 
           model.contains("E.494") || model.contains("E.191") || model.contains("E.193") || 
           model.contains("E.652") || model.contains("D.445") {
            return "rectangle.fill.on.rectangle.fill"
        }
        // TSR
        if model.contains("TSR") {
            return "tram.fill"
        }
        // Default
        return "train.side.front.car"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            vehicleImageHeader
            vehicleInfoCard
            assignedTrainsTimeline
            vehicleConflictsSection
        }
    }

    private var vehicleImageHeader: some View {
        Group {
            if !imageName.isEmpty, UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                imagePlaceholder
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [modelColor.opacity(0.3), modelColor.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)
            .cornerRadius(12)
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(modelColor.opacity(0.2))
                        .frame(width: 100, height: 100)
                    Image(systemName: trainIconForModel)
                        .font(.system(size: 50, weight: .light))
                        .foregroundColor(modelColor.opacity(0.8))
                }
                
                VStack(spacing: 4) {
                    Text(vehicle.model).font(.title3.bold()).foregroundColor(modelColor)
                    Text("Immagine non disponibile").font(.caption2).foregroundColor(modelColor.opacity(0.6))
                }
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(modelColor.opacity(0.3), lineWidth: 1))
    }

    private var vehicleInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vehicle.name).font(.title2.bold()).foregroundColor(appState.theme.dark)
                    Text(vehicle.model).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(modelColor.opacity(0.15)).frame(width: 60, height: 60)
                    Image(systemName: "train.side.front.car").font(.system(size: 30)).foregroundColor(modelColor)
                }
            }
            Divider()
            technicalSpecsGrid
            vehicleNotesSection
        }
        .padding()
        .background(appState.theme.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var technicalSpecsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specifiche Tecniche").font(.headline).foregroundColor(appState.theme.dark)
            HStack(spacing: 20) {
                specItem(label: "Lunghezza", value: "\(Int(vehicle.length)) m", icon: "arrow.left.and.right")
                specItem(label: "Velocità Max", value: "\(Int(vehicle.maxSpeed)) km/h", icon: "gauge.with.dots.needle.67percent")
            }
            HStack(spacing: 20) {
                specItem(label: "Accelerazione", value: String(format: "%.1f m/s²", vehicle.acceleration), icon: "arrow.up.circle")
                specItem(label: "Decelerazione", value: String(format: "%.1f m/s²", vehicle.deceleration), icon: "arrow.down.circle")
            }
        }
    }

    private func specItem(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(label).font(.caption).foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon).font(.caption)
            }
            Text(value).font(.title3.bold())
        }
    }

    private var vehicleNotesSection: some View {
        Group {
            if let notes = vehicle.notes, !notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Note").font(.headline).foregroundColor(appState.theme.dark)
                    Text(notes).font(.body).foregroundColor(.secondary)
                }
            }
        }
    }

    private var assignedTrainsTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Turno Materiale").font(.headline).foregroundColor(appState.theme.dark)
            if assignedTrains.isEmpty {
                emptyTrainsIndicator
            } else {
                VStack(spacing: 8) {
                    ForEach(assignedTrains) { train in
                        assignedTrainTimelineRow(train)
                    }
                }
            }
        }
    }

    private var emptyTrainsIndicator: some View {
        HStack {
            Image(systemName: "info.circle").foregroundColor(.secondary)
            Text("Nessun treno assegnato a questo mezzo").font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appState.theme.surface)
        .cornerRadius(12)
    }

    private func assignedTrainTimelineRow(_ train: Train) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(train.name).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
                Spacer()
                if let route = manager.routes.first(where: { $0.id == train.routeId }) {
                    Text(route.name).font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(route.displayColor.opacity(0.2)).foregroundColor(route.displayColor).cornerRadius(4)
                }
            }
            assignedTrainTimeInfo(train)
        }
        .padding()
        .background(appState.theme.surface)
        .cornerRadius(10)
    }

    private func assignedTrainTimeInfo(_ train: Train) -> some View {
        HStack(spacing: 12) {
            if let dep = train.departureTime {
                Label(dep.timeFormat, systemImage: "arrow.up.circle.fill").font(.caption).foregroundColor(.green)
            }
            if let arr = train.stops.last?.arrival {
                Label(arr.timeFormat, systemImage: "arrow.down.circle.fill").font(.caption).foregroundColor(.red)
            }
            Spacer()
            if let origin = train.stops.first?.stationId, let dest = train.stops.last?.stationId {
                let originName = appState.railroad.network.nodes.first(where: { $0.id == origin })?.name ?? origin
                let destName = appState.railroad.network.nodes.first(where: { $0.id == dest })?.name ?? dest
                Text("\(originName) → \(destName)").font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private var vehicleConflictsSection: some View {
        let conflicts = manager.getVehicleConflicts(for: vehicle.id)
        return Group {
            if !conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                        Text("Conflitti di Turno").font(.headline).foregroundColor(.red)
                    }
                    ForEach(conflicts) { conflict in
                        Text(conflict.description).font(.subheadline).foregroundColor(appState.theme.dark)
                            .padding().background(Color.red.opacity(0.05)).cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }
}
