import SwiftUI
import UIKit

struct LinePropertyEditor: View {
    let line: TrainRoute
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var linesManager: LinesManager
    
    var body: some View {
        let _ = print("🔍 [LinePropertyEditor] Rendering for line: \(line.name)")
        return VStack(alignment: .leading, spacing: 12) {
            Text("PROPRIETÀ LINEA")
                .font(.caption.bold())
                .foregroundColor(appState.theme.medium)
            
            // Name
            VStack(alignment: .leading, spacing: 6) {
                Text("Nome")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                TextField("Nome linea", text: lineNameBinding)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Prefix and Code
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prefisso")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("RE", text: linePrefixBinding)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Codice")
                        .font(.caption2.bold())
                        .foregroundColor(appState.theme.medium)
                    TextField("5", value: lineCodeBinding, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            
            // Color
            HStack {
                Text("Colore")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
                Spacer()
                ColorPicker("", selection: lineColorBinding)
                    .labelsHidden()
            }
            
            Divider()
                .padding(.top, 4)
        }
        .padding(16)
        .background(appState.theme.backgroundSecondary)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private var lineNameBinding: Binding<String> {
        Binding(
            get: { 
                linesManager.routes.first(where: { $0.id == line.id })?.name ?? line.name
            },
            set: { newName in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].name = newName
                    // Force UI update
                    appState.selectedRouteId = line.id
                }
            }
        )
    }
    
    private var linePrefixBinding: Binding<String> {
        Binding(
            get: { 
                linesManager.routes.first(where: { $0.id == line.id })?.serviceCodePrefix ?? line.serviceCodePrefix ?? ""
            },
            set: { newPrefix in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].serviceCodePrefix = newPrefix.isEmpty ? nil : newPrefix
                    // Force UI update
                    appState.selectedRouteId = line.id
                }
            }
        )
    }
    
    private var lineCodeBinding: Binding<Int> {
        Binding(
            get: { 
                linesManager.routes.first(where: { $0.id == line.id })?.numberPrefix ?? line.numberPrefix ?? 0
            },
            set: { newCode in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }) {
                    linesManager.routes[idx].numberPrefix = newCode == 0 ? nil : newCode
                    // Force UI update
                    appState.selectedRouteId = line.id
                }
            }
        )
    }
    
    private var lineColorBinding: Binding<Color> {
        Binding(
            get: { 
                let currentLine = linesManager.routes.first(where: { $0.id == line.id }) ?? line
                return Color(hex: currentLine.color ?? "") ?? .blue
            },
            set: { newColor in
                if let idx = linesManager.routes.firstIndex(where: { $0.id == line.id }),
                   let hex = newColor.toHex() {
                    linesManager.routes[idx].color = hex
                    // Force UI update
                    appState.selectedRouteId = line.id
                }
            }
        )
    }
}
