import SwiftUI

struct ConflictDashboardView: View {
    let conflicts: [ScheduleConflict]
    let network: RailwayNetwork
    var onFocusConflict: (ScheduleConflict) -> Void
    
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 20) {
            if conflicts.isEmpty {
                SuccessBanner()
            } else {
                ConflictHeader(count: conflicts.count)
                
                Picker("visualization".localized, selection: $selectedTab) {
                    Text("all_tab".localized).tag(0)
                    Text("hotspots_tab".localized).tag(1)
                    Text("lines_tab".localized).tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 16) {
                        if selectedTab == 0 {
                            allConflictsList
                        } else if selectedTab == 1 {
                            hotspotsList
                        } else {
                            linesList
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.clear)
    }
    
    private var allConflictsList: some View {
        ForEach(conflicts) { conflict in
            ConflictCard(conflict: conflict) {
                onFocusConflict(conflict)
            }
        }
    }
    
    private var hotspotsList: some View {
        let items = analyzeHotspots()
        return ForEach(items, id: \.id) { hotspot in
            HotspotCard(hotspot: hotspot, network: network)
        }
    }
    
    private var linesList: some View {
        let grouped = Dictionary(grouping: conflicts) { conflict in
            // Basic heuristic: check if it's a line conflict or which line it belongs to
            if conflict.locationId.contains("-") {
                return "line_segments".localized
            } else {
                return "nodes_stations".localized
            }
        }
        
        return ForEach(grouped.keys.sorted(), id: \.self) { key in
            VStack(alignment: .leading, spacing: 10) {
                Text(key)
                    .font(.headline)
                    .padding(.leading, 4)
                
                ForEach(grouped[key] ?? []) { conflict in
                    ConflictCard(conflict: conflict) {
                        onFocusConflict(conflict)
                    }
                }
            }
        }
    }
    
    private func analyzeHotspots() -> [HotspotInfo] {
        var counts: [String: Int] = [:]
        for c in conflicts {
            counts[c.locationId, default: 0] += 1
        }
        
        return counts.map { id, count in
            HotspotInfo(id: id, count: count)
        }.sorted { $0.count > $1.count }
    }
}

struct HotspotInfo: Identifiable {
    let id: String
    let count: Int
}

struct SuccessBanner: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: true)
            
            VStack(spacing: 5) {
                Text("perfect_timetable".localized)
                    .font(.title2.bold())
                Text("no_conflicts_desc".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .padding()
    }
}

struct ConflictHeader: View {
    let count: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "conflicts_detected_fmt_short".localized, count))
                    .font(.title3.bold())
                Text("conflict_analysis_desc".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Text("criticality".localized)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(6)
        }
        .padding(.horizontal)
    }
}

struct HotspotCard: View {
    let hotspot: HotspotInfo
    let network: RailwayNetwork
    
    var body: some View {
        HStack(spacing: 15) {
            Text("\(hotspot.count)")
                .font(.system(size: 24, weight: .black, design: .monospaced))
                .foregroundColor(.red)
                .frame(width: 50, height: 50)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                let name = network.nodes.first(where: { $0.id == hotspot.id })?.name ?? hotspot.id
                Text(name)
                    .font(.headline)
                Text("consecutive_collisions".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(15)
    }
}
