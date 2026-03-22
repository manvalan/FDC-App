import SwiftUI

struct EditorSubModePicker: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(DesignSubMode.allCases) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        appState.designSubMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.subheadline)
                        .fontWeight(appState.designSubMode == mode ? .bold : .medium)
                        .foregroundColor(appState.designSubMode == mode ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(appState.designSubMode == mode ? Color.accentColor : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
