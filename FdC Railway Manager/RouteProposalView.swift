import SwiftUI
import Combine

struct RouteProposalView: View {
    @ObservedObject var network: NetworkModel
    @EnvironmentObject var trainManager: LinesManager
    @Environment(\.dismiss) var dismiss
    
    let proposals: [ProposedRoute]
    let onApply: ([ProposedRoute], Bool) -> Void  // Bool = createTrains
    
    @State private var selectedRouteIds: Set<String> = []
    @State private var createSampleTrains = false  // Default: NO trains
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("ai_proposals_title".localized)
                        .font(.largeTitle.bold())
                    Text(String(format: "ai_proposals_desc_fmt".localized, proposals.count))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.blue.opacity(0.1))
                
                // Selection controls
                HStack {
                    Button(action: {
                        selectedRouteIds = Set(proposals.map { $0.id })
                    }) {
                        Label("select_all".localized, systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        selectedRouteIds.removeAll()
                    }) {
                        Label("deselect_all".localized, systemImage: "circle")
                    }
                    .buttonStyle(.borderless)
                    
                    Spacer()
                    
                    Text(String(format: "selected_count_fmt".localized, selectedRouteIds.count))
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
                                network: network,
                                isSelected: selectedRouteIds.contains(proposal.id),
                                onToggle: {
                                    if selectedRouteIds.contains(proposal.id) {
                                        selectedRouteIds.remove(proposal.id)
                                    } else {
                                        selectedRouteIds.insert(proposal.id)
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
                            Text("create_sample_trains".localized)
                                .font(.subheadline.bold())
                            Text("create_sample_trains_desc".localized)
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
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(String(format: "create_lines_btn_fmt".localized, selectedRouteIds.count)) {
                        let selectedProposals = proposals.filter { selectedRouteIds.contains($0.id) }
                        onApply(selectedProposals, createSampleTrains)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedRouteIds.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Select all by default
            selectedRouteIds = Set(proposals.map { $0.id })
        }
    }
}

struct ProposalRow: View {
    let proposal: ProposedRoute
    let network: NetworkModel
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
                    
                    let names = proposal.stationSequence.map { id in
                        network.nodes.first(where: { $0.id == id })?.name ?? "?? (\(id.prefix(4)))"
                    }
                    
                    Text(names.joined(separator: " → "))
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
