import SwiftUI

struct SimulationControlsOverlay: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Spacer()
            LiveSimulationShelf()
                .padding(.bottom, Layout.standardPadding)
        }
        .zIndex(ZIndex.simulation)
    }
}
