import SwiftUI

struct SimulationControlView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var liveSim: LiveSimulationManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Time Display
            VStack(alignment: .leading, spacing: 2) {
                Text(liveSim.currentSimTime, style: .time)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("simulation_time".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 100)
            
            Divider().frame(height: 30)
            
            // Play/Pause
            Button(action: {
                withAnimation(.spring()) {
                    liveSim.toggle()
                }
            }) {
                Image(systemName: liveSim.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(liveSim.isRunning ? Color.orange : Color.green)
                    .clipShape(Circle())
                    .shadow(color: (liveSim.isRunning ? Color.orange : Color.green).opacity(0.3), radius: 5)
            }
            .buttonStyle(.plain)
            
            // Multiplier controls
            HStack(spacing: 0) {
                multiplierButton(label: "1x", value: 1.0)
                multiplierButton(label: "5x", value: 5.0)
                multiplierButton(label: "10x", value: 10.0)
                multiplierButton(label: "60x", value: 60.0)
            }
            .background(Color(.systemGray6))
            .clipShape(Capsule())
            
            Button(action: { liveSim.stop() }) {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
        )
    }
    
    private func multiplierButton(label: String, value: Double) -> some View {
        Button(action: { liveSim.timeMultiplier = value }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(liveSim.timeMultiplier == value ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(liveSim.timeMultiplier == value ? Color.blue : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
