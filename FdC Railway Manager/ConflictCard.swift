import SwiftUI

struct ConflictCard: View {
    let conflict: ScheduleConflict
    var onFocus: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 15) {
                // Icon based on location type
                ZStack {
                    Circle()
                        .fill(conflict.locationType == .station ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: conflict.locationType == .station ? "building.2.fill" : "road.lanes")
                        .foregroundColor(conflict.locationType == .station ? .blue : .orange)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.locationName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(conflict.locationType == .station ? "Conflitto in Stazione" : "Occupazione Tratta Singola")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Time Badge
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatTime(conflict.timeStart))
                        .font(.system(.subheadline, design: .monospaced).bold())
                    Text("Durata: \(Int(conflict.timeEnd.timeIntervalSince(conflict.timeStart)))s")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                TrainParticipantView(name: conflict.trainAName, id: conflict.trainAId)
                
                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(.red)
                    .font(.caption.bold())
                
                TrainParticipantView(name: conflict.trainBName, id: conflict.trainBId)
            }
            
            if let onFocus = onFocus {
                Button(action: onFocus) {
                    HStack {
                        Image(systemName: "scope")
                        Text("Visualizza sulla mappa")
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct TrainParticipantView: View {
    let name: String
    let id: UUID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "train.side.front.car")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
            }
            
            Text(id.uuidString.prefix(8))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
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
                timeEnd: Date().addingTimeInterval(120)
            ))
            .padding()
        }
    }
}
