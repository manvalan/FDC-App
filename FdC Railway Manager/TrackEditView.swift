import SwiftUI

struct TrackEditView: View {
    @Binding var edge: Edge
    @EnvironmentObject var network: RailwayNetwork
    var onDelete: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirmation = false
    
    private var fromStation: Node? {
        network.nodes.first(where: { $0.id == edge.from })
    }
    
    private var toStation: Node? {
        network.nodes.first(where: { $0.id == edge.to })
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text("\(fromStation?.name ?? edge.from) → \(toStation?.name ?? edge.to)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("edit_track".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Track Properties
                VStack(alignment: .leading, spacing: 8) {
                    Text("track_properties".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("distance_km".localized)
                        Spacer()
                        TextField("distance".localized, value: $edge.distance, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                        Text("km")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("max_speed_kmh".localized)
                        Spacer()
                        TextField("speed".localized, value: $edge.maxSpeed, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                        Text("km/h")
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("track_type".localized, selection: $edge.trackType) {
                        Text("track_single".localized).tag(Edge.TrackType.single)
                        Text("track_double".localized).tag(Edge.TrackType.double)
                        Text("track_highspeed".localized).tag(Edge.TrackType.highSpeed)
                        Text("track_regional".localized).tag(Edge.TrackType.regional)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: edge.trackType) { newType in
                        switch newType {
                        case .single: edge.capacity = 6
                        case .double: edge.capacity = 24
                        case .highSpeed: edge.capacity = 15
                        case .regional: edge.capacity = 6
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Capacity
                VStack(alignment: .leading, spacing: 8) {
                    Text("capacity".localized.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("capacity_trains_h".localized)
                        Spacer()
                        TextField("capacity".localized, value: $edge.capacity, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                        Text("trains/h")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                
                // Delete
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text("delete_track".localized)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .alert("delete_track".localized, isPresented: $showDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) { }
            Button("delete".localized, role: .destructive) {
                onDelete()
            }
        } message: {
            Text("delete_track_confirm".localized)
        }
    }
}
