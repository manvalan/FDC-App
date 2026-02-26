import SwiftUI
import UIKit

struct CompactInfoRow: View {
    let label: String
    let value: String
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundColor(appState.theme.medium)
            Spacer()
            Text(value).font(.subheadline.bold()).foregroundColor(appState.theme.dark)
        }
    }
}
