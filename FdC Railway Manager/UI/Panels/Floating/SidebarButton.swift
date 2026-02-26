import SwiftUI
import UIKit

struct SidebarButton: View {
    let title: String
    var icon: String? = nil
    var customIcon: String? = nil
    var isSpecial: Bool = false
    let action: () -> Void
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let ci = customIcon {
                    Text(ci).frame(width: 24)
                } else if let si = icon {
                    Image(systemName: si)
                        .font(.system(size: 16))
                        .foregroundColor(isSpecial ? appState.theme.accent : appState.theme.medium)
                        .frame(width: 24)
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isSpecial ? appState.theme.accent : appState.theme.dark)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.clear) // Full control
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
