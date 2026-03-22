import SwiftUI
import UIKit
import Combine

struct LineQuickStats: View {
    let line: TrainRoute
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    @State private var longPressMode: LineInspectorMode? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            modeSelector
            
            VStack(alignment: .leading, spacing: 12) {
                CompactInfoRow(label: "Stazioni", value: "\(line.stationIds.count)")
                
                Divider()
                    .padding(.vertical, 8)
                
                propertiesEditor
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            handleGlobalLongPress()
        }
    }
    
    // MARK: - Subviews
    
    private var modeSelector: some View {
        HStack(spacing: 4) {
            ForEach(LineInspectorMode.allCases) { mode in
                modeButton(for: mode)
            }
        }
        .padding(4)
        .background(appState.theme.light.opacity(0.3))
        .cornerRadius(12)
    }
    
    private func modeButton(for mode: LineInspectorMode) -> some View {
        Button(action: {
            if longPressMode != mode {
                updateMode(mode)
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
                    handleModeLongPress(mode)
                }
        )
    }
    
    private var propertiesEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROPRIETÀ LINEA")
                .font(.caption.bold())
                .foregroundColor(appState.theme.medium)
                .padding(.bottom, 4)
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Nome")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                TextField("Nome linea", text: nameBinding)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prefisso")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("RE", text: prefixBinding)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codice")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("5", value: codeBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            
            HStack {
                Text("Colore")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                Spacer()
                ColorPicker("", selection: colorBinding)
                    .labelsHidden()
            }
        }
    }
    
    // MARK: - Bindings
    
    private var nameBinding: Binding<String> {
        Binding(
            get: { linesManager.routes.first(where: { $0.id == line.id })?.name ?? line.name },
            set: { newName in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].name = newName
                    linesManager.validateSchedules()
                    appState.objectWillChange.send()
                }
            }
        )
    }
    
    private var prefixBinding: Binding<String> {
        Binding(
            get: { linesManager.routes.first(where: { $0.id == line.id })?.serviceCodePrefix ?? "" },
            set: { newPrefix in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].serviceCodePrefix = newPrefix.isEmpty ? nil : newPrefix
                    linesManager.validateSchedules()
                    appState.objectWillChange.send()
                }
            }
        )
    }
    
    private var codeBinding: Binding<Int> {
        Binding(
            get: { linesManager.routes.first(where: { $0.id == line.id })?.numberPrefix ?? 0 },
            set: { newCode in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].numberPrefix = newCode == 0 ? nil : newCode
                    linesManager.validateSchedules()
                    appState.objectWillChange.send()
                }
            }
        )
    }
    
    private var colorBinding: Binding<Color> {
        Binding(
            get: {
                let current = linesManager.routes.first(where: { $0.id == line.id }) ?? line
                return Color(hex: current.color ?? "") ?? .blue
            },
            set: { newColor in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }),
                   let hex = newColor.toHex() {
                    linesManager.routes[idx].color = hex
                    linesManager.validateSchedules()
                    appState.objectWillChange.send()
                }
            }
        )
    }
    
    // MARK: - Helpers
    
    private func updateMode(_ mode: LineInspectorMode) {
        withAnimation(.spring(response: 0.3)) { 
            appState.lineInspectorMode = mode 
            appState.isLineEditing = (mode == .infrastructure)
            appState.isScheduleGeneratorVisible = false
            appState.isVehicleManagementVisible = false
        }
    }
    
    private func handleModeLongPress(_ mode: LineInspectorMode) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        withAnimation(.spring(response: 0.4)) {
            appState.lineInspectorMode = mode
            if mode == .infrastructure {
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
    
    private func handleGlobalLongPress() {
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
