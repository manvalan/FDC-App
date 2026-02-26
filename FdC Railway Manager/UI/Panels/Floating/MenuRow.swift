import SwiftUI
import UIKit

struct MenuRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                    .foregroundColor(isSelected ? appState.theme.accent : appState.theme.medium)
                
                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? appState.theme.dark : appState.theme.medium)
                
                Spacer()
                
                if isSelected {
                    Circle()
                        .fill(appState.theme.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? appState.theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
