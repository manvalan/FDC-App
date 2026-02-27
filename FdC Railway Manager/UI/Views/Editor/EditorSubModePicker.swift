import SwiftUI

struct EditorSubModePicker: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Picker("Modalità", selection: $appState.designSubMode) {
            ForEach(DesignSubMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}
