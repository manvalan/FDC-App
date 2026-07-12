import SwiftUI

struct TrainDatabasePickerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var database = TrainDatabaseManager.shared
    @Environment(\.dismiss) var dismiss

    let onSelect: (TrainDatabaseEntry) -> Void

    @State private var searchText = ""
    @State private var selectedManufacturer: String?

    private var manufacturers: [String] {
        Array(Set(database.trains.map { $0.costruttore })).sorted()
    }

    private var filteredTrains: [TrainDatabaseEntry] {
        var result = database.trains

        if let manufacturer = selectedManufacturer {
            result = result.filter { $0.costruttore == manufacturer }
        }

        if !searchText.isEmpty {
            result = result.filter { train in
                train.nome.lowercased().contains(searchText.lowercased()) ||
                train.tipo.lowercased().contains(searchText.lowercased())
            }
        }

        return result.sorted { $0.nome < $1.nome }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(appState.theme.medium)
                    TextField("Cerca treno...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()
                .background(appState.theme.backgroundSecondary)

                if !manufacturers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterButton(title: "Tutti", manufacturer: nil)
                            ForEach(manufacturers, id: \.self) { manufacturer in
                                filterButton(title: manufacturer, manufacturer: manufacturer)
                            }
                        }
                        .padding()
                    }
                    .background(appState.theme.surface)
                }

                Divider()

                if filteredTrains.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 60))
                            .foregroundColor(appState.theme.medium.opacity(0.3))
                        Text("Nessun treno trovato")
                            .font(.headline)
                            .foregroundColor(appState.theme.medium)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredTrains) { train in
                                TrainDatabaseCard(train: train) {
                                    onSelect(train)
                                    dismiss()
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(appState.theme.background)
            .navigationTitle("Database Treni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }

    private func filterButton(title: String, manufacturer: String?) -> some View {
        Button(action: { selectedManufacturer = manufacturer }) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    selectedManufacturer == manufacturer
                        ? appState.theme.accent
                        : appState.theme.backgroundSecondary
                )
                .foregroundColor(
                    selectedManufacturer == manufacturer ? .white : appState.theme.dark
                )
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct TrainDatabaseCard: View {
    @EnvironmentObject var appState: AppState
    let train: TrainDatabaseEntry
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                if let assetName = train.assetName, UIImage(named: assetName) != nil {
                    Image(assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "tram.fill")
                        .font(.largeTitle)
                        .foregroundColor(appState.theme.accent)
                        .frame(width: 100, height: 70)
                        .background(appState.theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(train.nome)
                        .font(.headline)
                        .foregroundColor(appState.theme.dark)
                    Text(train.tipo)
                        .font(.subheadline)
                        .foregroundColor(appState.theme.medium)
                    HStack(spacing: 12) {
                        Label("\(Int(train.specifiche.velocitaMaxKmh)) km/h", systemImage: "speedometer")
                        Label(
                            "\(String(format: "%.2f", train.fisica.accelerazioneMS2)) m/s²",
                            systemImage: "arrow.up.right"
                        )
                    }
                    .font(.caption)
                    .foregroundColor(appState.theme.accent)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(appState.theme.medium)
            }
            .padding()
            .background(appState.theme.surface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(appState.theme.line.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
