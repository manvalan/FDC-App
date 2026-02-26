import SwiftUI

struct InspectorOverlay: View {
    var body: some View {
        HStack {
            Spacer()
            ModernInspectorPanel()
        }
        .zIndex(ZIndex.inspector)
    }
}
