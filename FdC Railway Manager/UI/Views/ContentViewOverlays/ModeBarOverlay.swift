import SwiftUI

struct ModeBarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            Color.black.opacity(0.001)
                .onTapGesture { appState.showPanel(.none) }
                .zIndex(ZIndex.modeDismiss)
            
            VStack {
                FloatingModeBar()
                    .padding(.top, Layout.leftEdgeWidth)
                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(ZIndex.modeBar)
        }
    }
}
