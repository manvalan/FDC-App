import SwiftUI

struct SidebarOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            FloatingSideMenu()
                .transition(.move(edge: .leading))
            Spacer()
        }
        .background(Color.black.opacity(0.2).onTapGesture { appState.showPanel(.none) })
        .zIndex(ZIndex.sidebar)
    }
}
