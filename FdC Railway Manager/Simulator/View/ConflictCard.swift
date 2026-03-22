import SwiftUI

struct ConflictCard: View {
    @EnvironmentObject var appState: AppState
    let conflict: ScheduleConflict
    var suggestedResolution: String? = nil
    var onFocus: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                // Icon based on location type
                ZStack {
                    Circle()
                        .fill(conflict.locationType == .station ? appState.theme.accent.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: conflict.locationType == .station ? "building.2.fill" : "road.lanes")
                        .foregroundColor(conflict.locationType == .station ? appState.theme.accent : .orange)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.locationName)
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    
                    Text(conflict.locationType == .station ? "Conflitto in Stazione" : "Occupazione Tratta Singola")
                        .font(.caption)
                        .foregroundColor(appState.theme.medium)
                }
                
                Spacer()
                
                // Time Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(conflict.timeStart))
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundColor(appState.theme.dark)
                    Text("Durata: \(Int(conflict.timeEnd.timeIntervalSince(conflict.timeStart)))s")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(appState.theme.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(appState.theme.backgroundSecondary)
                .cornerRadius(8)
                
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundColor(appState.theme.medium)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                TrainParticipantView(name: conflict.trainAName, id: conflict.trainAId)
                
                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(.red)
                    .font(.caption.bold())
                
                TrainParticipantView(name: conflict.trainBName, id: conflict.trainBId)
            }
            
            if let suggestions = suggestedResolution {
                 Text("💡 \(suggestions)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(appState.theme.surface)
        .cornerRadius(12)
        .shadow(color: appState.theme.line.opacity(0.1), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            onFocus?()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct TrainParticipantView: View {
    @EnvironmentObject var appState: AppState
    let name: String
    let id: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "train.side.front.car")
                    .font(.caption)
                    .foregroundColor(appState.theme.accent)
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundColor(appState.theme.dark)
                    .lineLimit(1)
            }
            
            Text(id.uuidString.prefix(8))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(appState.theme.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConflictCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1).ignoresSafeArea()
            ConflictCard(conflict: ScheduleConflict(
                trainAId: UUID(),
                trainBId: UUID(),
                trainAName: "Regionale 1234",
                trainBName: "Frecciarossa 9999",
                locationType: .station,
                locationName: "Firenze S.M.N.",
                locationId: "FI_SMN",
                timeStart: Date(),
                timeEnd: Date().addingTimeInterval(120),
                capacity: 1,
                occupantsCount: 2
            ))
            .padding()
        }
    }
}
