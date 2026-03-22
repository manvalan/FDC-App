import Foundation
import SwiftUI

// MARK: - RailwayLine (Infrastructure) List Popover

struct InfraLinesListPopover: View {

    @EnvironmentObject var appState: AppState
    var onSelect: (RailwayLine) -> Void
    var onCreate: () -> Void

    var body: some View {
        VStack {
            HStack {
                Text("Linee")
                    .font(.headline)
                Spacer()
                Button(action: onCreate) {
                    Image(systemName: "plus")
                }
            }
            .padding()

            if appState.railroad.network.lines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "map.fill")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Nessuna Linea")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Crea una linea per definire un percorso fisico dell'infrastruttura")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(appState.railroad.network.lines) { line in
                        Button(action: { onSelect(line) }) {
                            HStack {
                                Circle()
                                    .fill(line.displayColor)
                                    .frame(width: 8, height: 8)
                                Text(line.name)
                                Spacer()
                                Text("\(line.nodeIds.count) nodi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteInfraLine)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(UIColor.systemBackground))
    }

    func deleteInfraLine(at offsets: IndexSet) {
        offsets.forEach { index in
            let line = appState.railroad.network.lines[index]
            if appState.selectedInfraLineId == line.id {
                appState.selectedInfraLineId = nil
            }
            appState.railroad.network.lines.removeAll { $0.id == line.id }
        }
    }
}

// MARK: - RailwayLine (Infrastructure) Inspector List

struct InfraLinesInspectorList: View {
    @EnvironmentObject var appState: AppState
    var onSelect: (RailwayLine) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if appState.railroad.network.lines.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Nessuna Linea")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Seleziona 2 o più nodi sulla mappa e usa il pulsante '+' per creare una linea infrastrutturale")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appState.railroad.network.lines) { line in
                            Button(action: { onSelect(line) }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(line.displayColor)
                                        .frame(width: 12, height: 12)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(line.name)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                        Text("\(line.nodeIds.count) nodi · \(line.electrification.rawValue)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(UIColor.tertiarySystemBackground)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(UIColor.systemBackground))
    }
}

