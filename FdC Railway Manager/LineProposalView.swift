import SwiftUI

struct LineProposalView: View {
    @ObservedObject var network: RailwayNetwork
    @EnvironmentObject var trainManager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    let proposals: [ProposedLine]
    let onApply: ([ProposedLine], Bool) -> Void  // Bool = createTrains
    
    @State private var selectedLineIds: Set<String> = []
    @State private var createSampleTrains = false  // Default: NO trains
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Proposte AI")
                        .font(.largeTitle.bold())
                    Text("L'intelligenza artificiale ha analizzato la tua rete e propone \(proposals.count) nuove linee ottimizzate.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // Selection controls
                HStack {
                    Button(action: {
                        selectedLineIds = Set(proposals.map { $0.id })
                    }) {
                        Label("Seleziona Tutte", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        selectedLineIds.removeAll()
                    }) {
                        Label("Deseleziona Tutte", systemImage: "circle")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Text("\(selectedLineIds.count) selezionate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Divider()
                
                // Proposals list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(proposals, id: \.id) { proposal in
                            ProposalRow(
                                proposal: proposal,
                                isSelected: selectedLineIds.contains(proposal.id),
                                onToggle: {
                                    if selectedLineIds.contains(proposal.id) {
                                        selectedLineIds.remove(proposal.id)
                                    } else {
                                        selectedLineIds.insert(proposal.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                Divider()
                
                // Train creation option
                VStack(spacing: 8) {
                    Toggle(isOn: $createSampleTrains) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Crea anche treni di esempio")
                                .font(.subheadline.bold())
                            Text("Genera automaticamente treni cadenzati per ogni linea (6:00-22:00)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                // Bottom actions
                HStack(spacing: 16) {
                    Button("Annulla") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Crea \(selectedLineIds.count) Linee") {
                        let selectedProposals = proposals.filter { selectedLineIds.contains($0.id) }
                        onApply(selectedProposals, createSampleTrains)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedLineIds.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Select all by default
            selectedLineIds = Set(proposals.map { $0.id })
        }
    }
}

struct ProposalRow: View {
    let proposal: ProposedLine
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            // Line info
            VStack(alignment: .leading, spacing: 8) {
                // Line name
                HStack {
                    Text(proposal.id)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let color = proposal.color {
                        Circle()
                            .fill(Color(hex: color) ?? .blue)
                            .frame(width: 12, height: 12)
                    }
                }
                
                // Route with real station names
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(proposal.stationSequence.joined(separator: " → "))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Frequency
                HStack(spacing: 12) {
                    Label(proposal.frequency, systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Label("\(proposal.stops.count) fermate", systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}
