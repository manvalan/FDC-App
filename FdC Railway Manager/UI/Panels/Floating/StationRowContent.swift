import SwiftUI
import UIKit

struct StationRowContent: View {
    let node: Node
    @EnvironmentObject var appState: AppState
    
    private var nodeColor: Color {
        if let customColor = node.customColor, let color = Color(hex: customColor) {
            return color
        }
        switch node.type {
        case .station: return .blue
        case .interchange: return .orange
        case .depot: return .gray
        case .junction: return .green
        }
    }
    
    @ViewBuilder
    private func stationSymbol(size: CGFloat = 28) -> some View {
        // Interchange stations use double red circle
        if node.type == .interchange {
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: size * 0.6, height: size * 0.6)
            }
        } else {
            let color = nodeColor
            
            switch node.visualType ?? .filledCircle {
            case .filledCircle:
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptyCircle:
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: size, height: size)
            case .filledSquare:
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: size, height: size)
            case .emptySquare:
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 3)
                    .frame(width: size, height: size)
            case .filledStar:
                Image(systemName: "star.fill")
                    .foregroundColor(color)
                    .font(.system(size: size))
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(nodeColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                stationSymbol(size: 28)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                let typeStr = node.type.localizedName
                if let platforms = node.platforms {
                    Text("\(typeStr) • \(platforms) " + "platforms".localized)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text(typeStr)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedNodeId == node.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedNodeId == node.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}
