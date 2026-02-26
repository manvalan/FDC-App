import SwiftUI

struct WidePanelOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            WidePanelView()
                .frame(width: Layout.widePanelWidth)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            Spacer()
                .frame(width: Layout.inspectorWidth)
        }
        .edgesIgnoringSafeArea(.all)
        .zIndex(ZIndex.widePanel)
    }
}
