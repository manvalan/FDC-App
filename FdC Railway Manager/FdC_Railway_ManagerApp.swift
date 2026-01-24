import SwiftUI

@main
struct FdC_Railway_ManagerApp: App {
    @StateObject private var network = RailwayNetwork(name: "FdC Demo")
    @StateObject private var trainManager = TrainManager()
    @StateObject private var appState = AppState()

    init() {
        // nothing here; use task in scene to perform async import if needed
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(network)
                .environmentObject(trainManager)
                .environmentObject(appState)
                .task {
                    // automatic import of bundled fdc2.fdc once per launch
                    guard !appState.didAutoImport else { return }
                    let importer = FDCImportViewModel(network: network, trainManager: trainManager, appState: appState)
                    print("[App] Attempting automatic bundled FDC import...")
                    await importer.importBundledFDC(named: "fdc2.fdc")
                    switch importer.status {
                    case .success(let summary):
                        print("[App] Import succeeded: \(summary)")
                        appState.didAutoImport = true
                    case .failure(let error):
                        print("[App] Import failed: \(error)")
                        appState.didAutoImport = false
                    default:
                        print("[App] Import finished with status: \(importer.status)")
                    }
                }
        }
    }
}
