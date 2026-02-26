import SwiftUI
import UIKit

struct FloatingModeBar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 20) {
            ForEach(AppMode.allCases) { mode in
                Button(action: {
                    appState.currentMode = mode
                    appState.showPanel(.none)
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 20, weight: .semibold))
                        Text(mode.title)
                            .font(.caption2)
                            .bold()
                    }
                    .foregroundColor(appState.currentMode == mode ? appState.theme.accent : appState.theme.medium)
                    .frame(width: 110, height: 75)
                    .background(appState.currentMode == mode ? appState.theme.accent.opacity(0.12) : appState.theme.light.opacity(0.3))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(appState.currentMode == mode ? appState.theme.accent.opacity(0.3) : appState.theme.line.opacity(0.1), lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(appState.theme.background)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
        .transition(.move(edge: .top).combined(with: .opacity))
        .gesture(
            DragGesture().onEnded { val in
                if val.translation.height < -20 {
                    appState.showPanel(.none)
                }
            }
        )
    }
    
    private func icon(for mode: AppMode) -> String {
        switch mode {
        case .design: return "pencil.and.outline"
        case .schedule: return "calendar.badge.clock"
        case .live: return "play.fill"
        case .editor: return "pencil"
        }
    }
}
