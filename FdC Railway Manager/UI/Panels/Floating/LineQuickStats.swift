import SwiftUI
import UIKit

struct LineQuickStats: View {
    let line: TrainRoute
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var longPressMode: AppState.LineInspectorMode? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Mode Selector
            HStack(spacing: 4) {
                ForEach(AppState.LineInspectorMode.allCases) { mode in
                    Button(action: {
                        // Don't execute tap action if long press just completed on this mode
                        if longPressMode != mode {
                            withAnimation(.spring(response: 0.3)) { 
                                appState.lineInspectorMode = mode 
                                appState.isLineEditing = (mode == .infrastructure)
                                appState.isScheduleGeneratorVisible = false
                                appState.isVehicleManagementVisible = false
                            }
                        }
                        longPressMode = nil
                    }) {
                        ZStack {
                            if appState.lineInspectorMode == mode {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(appState.theme.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            
                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(appState.lineInspectorMode == mode ? .white : appState.theme.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                longPressMode = mode
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                withAnimation(.spring(response: 0.4)) {
                                    appState.lineInspectorMode = mode
                                    if mode == .infrastructure {
                                        appState.isLineEditing = true
                                        appState.isScheduleGeneratorVisible = false
                                        appState.isVehicleManagementVisible = false
                                    } else if mode == .schedule {
                                        appState.creationRouteId = line.id
                                        appState.isScheduleGeneratorVisible = true
                                        appState.isVehicleManagementVisible = false
                                    } else if mode == .vehicles {
                                        appState.isVehicleManagementVisible = true
                                        appState.isScheduleGeneratorVisible = false
                                    }
                                }
                            }
                    )
                }
            }
            .padding(4)
            .background(appState.theme.light.opacity(0.3))
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 12) {
                CompactInfoRow(label: "Stazioni", value: "\(line.stationIds.count)")
                
                Divider()
                    .padding(.vertical, 8)
                
                // LINE PROPERTIES EDITOR
                Text("PROPRIETÀ LINEA")
                    .font(.caption.bold())
                    .foregroundColor(appState.theme.medium)
                    .padding(.bottom, 4)
                
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nome")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("Nome linea", text: Binding(
                        get: { linesManager.routes.first(where: { $0.id == line.id })?.name ?? line.name },
                        set: { newName in
                            if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                                linesManager.routes[idx].name = newName
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Prefisso")
                            .font(.caption2.bold())
                            .foregroundColor(appState.theme.medium)
                        TextField("RE", text: Binding(
                            get: { linesManager.routes.first(where: { $0.id == line.id })?.serviceCodePrefix ?? "" },
                            set: { newPrefix in
                                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                                    linesManager.routes[idx].serviceCodePrefix = newPrefix.isEmpty ? nil : newPrefix
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codice")
                            .font(.caption2.bold())
                            .foregroundColor(appState.theme.medium)
                        TextField("5", value: Binding(
                            get: { linesManager.routes.first(where: { $0.id == line.id })?.numberPrefix ?? 0 },
                            set: { newCode in
                                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                                    linesManager.routes[idx].numberPrefix = newCode == 0 ? nil : newCode
                                }
                            }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                    }
                }
                
                HStack {
                    Text("Colore")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: {
                            let current = linesManager.routes.first(where: { $0.id == line.id }) ?? line
                            return Color(hex: current.color ?? "") ?? .blue
                        },
                        set: { newColor in
                            if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }),
                               let hex = newColor.toHex() {
                                linesManager.routes[idx].color = hex
                            }
                        }
                    ))
                    .labelsHidden()
                }
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press on the entire line inspector opens train creation when in Schedule mode
            if appState.lineInspectorMode == .schedule {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    appState.creationRouteId = line.id
                    appState.isScheduleGeneratorVisible = true
                    appState.isVehicleManagementVisible = false
                }
            }
        }
    }
}
