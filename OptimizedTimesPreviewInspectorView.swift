import SwiftUI

/// Inspector view for previewing optimized departure times before generating trains
struct OptimizedTimesPreviewInspectorView: View {
    @EnvironmentObject var appState: AppState
    
    let line: RailwayLine
    let mode: ScheduleCreationView.ScheduleMode
    let currentOutboundTime: Date
    let currentReturnTime: Date?
    let proposedOutboundTime: Date
    let proposedReturnTime: Date?
    let proposedInterval: Int?
    let proposedReturnInterval: Int?
    
    @State private var confirmationEnabled = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Orari Ottimizzati")
                        .font(.title2)
                        .bold()
                    Text(line.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: cancelPreview) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Information banner
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ottimizzazione Completata")
                                .font(.headline)
                            Text("Gli orari sono stati ottimizzati per ridurre i conflitti sulla linea")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Outbound comparison
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.green)
                            Text("Andata")
                                .font(.headline)
                        }
                        
                        HStack(spacing: 20) {
                            // Current time
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Attuale")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(currentOutboundTime))
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                            }
                            
                            Image(systemName: "arrow.right")
                                .foregroundColor(.blue)
                            
                            // Proposed time
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ottimizzato")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatTime(proposedOutboundTime))
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        if let interval = proposedInterval {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.secondary)
                                Text("Cadenza: \(interval) minuti")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(10)
                    
                    // Return comparison (if applicable)
                    if let currentRet = currentReturnTime, let proposedRet = proposedReturnTime {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.left.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Ritorno")
                                    .font(.headline)
                            }
                            
                            HStack(spacing: 20) {
                                // Current time
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Attuale")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(currentRet))
                                        .font(.title3)
                                        .foregroundColor(.secondary)
                                        .strikethrough()
                                }
                                
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.blue)
                                
                                // Proposed time
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ottimizzato")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatTime(proposedRet))
                                        .font(.title)
                                        .bold()
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            if let interval = proposedReturnInterval {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.secondary)
                                    Text("Cadenza: \(interval) minuti")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.5))
                        .cornerRadius(10)
                    }
                    
                    // Benefits section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Vantaggi")
                                .font(.headline)
                        }
                        
                        benefitRow(icon: "chart.line.downtrend.xyaxis", text: "Riduzione conflitti")
                        benefitRow(icon: "clock.badge.checkmark", text: "Maggiore puntualità")
                        benefitRow(icon: "chart.bar.fill", text: "Migliore utilizzo binari")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            
            Divider()
            
            // Bottom actions
            VStack(spacing: 12) {
                // Swipe to confirm
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(confirmationEnabled ? Color.green : Color.blue.opacity(0.2))
                        .frame(height: 50)
                    
                    HStack {
                        Image(systemName: confirmationEnabled ? "checkmark.circle.fill" : "arrow.right.circle.fill")
                            .foregroundColor(confirmationEnabled ? .white : .blue)
                        Text(confirmationEnabled ? "Confermato" : "Scorri per confermare")
                            .foregroundColor(confirmationEnabled ? .white : .blue)
                            .bold()
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                confirmationEnabled = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    confirmAndGenerate()
                                }
                            }
                        }
                )
                
                Button(action: cancelPreview) {
                    Text("Annulla")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .background(Color(.systemBackground))
    }
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func confirmAndGenerate() {
        // Apply optimized times and trigger generation
        appState.optimizedTimesConfirmed = true
        appState.optimizedTimesPreviewData = nil
        // Ripristina creationLineId per mostrare ScheduleCreationView durante la generazione
        appState.creationLineId = line.id
    }
    
    private func cancelPreview() {
        appState.optimizedTimesPreviewData = nil
        // Ripristina creationLineId per tornare a ScheduleCreationView
        appState.creationLineId = line.id
    }
}
