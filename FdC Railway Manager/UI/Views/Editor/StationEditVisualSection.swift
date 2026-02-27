import SwiftUI

struct StationEditVisualSection: View {
    @Binding var station: RailwayNode
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("visual_style".localized.uppercased()).font(.caption.bold()).foregroundColor(appState.theme.medium)
            
            symbolPicker
            colorPicker
        }
        .padding().background(appState.theme.backgroundSecondary).cornerRadius(12)
    }
    
    private var symbolPicker: some View {
        HStack {
            Text("Stile Simbolo").font(.subheadline)
            Spacer()
            Picker("Simbolo", selection: $station.visualType) {
                ForEach(RailwayNode.StationVisualType.allCases) { type in
                    Image(systemName: symbolSystemName(for: type)).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var colorPicker: some View {
        HStack {
            Text("Colore").font(.subheadline)
            Spacer()
            ColorPicker("", selection: Binding(
                get: { Color(hex: station.customColor ?? station.defaultColor) ?? .black },
                set: { if let hex = $0.toHex() { station.customColor = hex } }
            )).labelsHidden()
        }
    }
    
    private func symbolSystemName(for type: RailwayNode.StationVisualType) -> String {
        switch type {
        case .filledSquare: return "square.fill"
        case .emptySquare: return "square"
        case .filledCircle: return "circle.fill"
        case .emptyCircle: return "circle"
        case .filledStar: return "star.fill"
        }
    }
}
