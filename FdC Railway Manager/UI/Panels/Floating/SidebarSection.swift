import SwiftUI
import UIKit

private struct SidebarSection<Content: View>: View {
    let title: String
    let content: Content
    @EnvironmentObject var appState: AppState
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(appState.theme.medium)
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            content
        }
    }
}
