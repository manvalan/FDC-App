import SwiftUI
import UIKit

struct FerroviaRowContent: View {
    let ferrovia: Ferrovia
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 12) {
            // Badge icon with ferrovia color
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(ferrovia.displayColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                NetworkSymbols.ferroviaSymbol(color: ferrovia.color, size: 24)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ferrovia.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(appState.theme.dark)
                
                Text("\(ferrovia.nodeIds.count) stazioni")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(appState.selectedInfraLineId == ferrovia.id ? appState.theme.accent.opacity(0.15) : appState.theme.backgroundSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.selectedInfraLineId == ferrovia.id ? appState.theme.accent : appState.theme.line.opacity(0.2), lineWidth: 1)
        )
    }
}
