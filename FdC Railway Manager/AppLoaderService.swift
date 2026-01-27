import Foundation
import SwiftUI
import Combine

@MainActor
class AppLoaderService: ObservableObject {
    @Published var isLoading = false
    let network: RailwayNetwork
    let trainManager: TrainManager
    let appState: AppState
    
    init(network: RailwayNetwork, trainManager: TrainManager, appState: AppState) {
        self.network = network
        self.trainManager = trainManager
        self.appState = appState
    }
    
    func performInitialLoad() async {
        // Automatic import logic
        guard !appState.didAutoImport else { return }
        
        let importer = FDCImportViewModel(network: network, trainManager: trainManager, appState: appState)
        await importer.importBundledFDC(named: "fdc2.fdc")
        
        // Ensure trains are calculated
        trainManager.validateSchedules(with: network)
        
        appState.didAutoImport = true
    }
}
