import SwiftUI
import UIKit

struct SidebarSubButton: View {
    let title: String
    let icon: String
    var isSelected: Bool = false
    let action: () -> Void
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.medium)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.dark)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? appState.theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(10)
        }
    }
}
