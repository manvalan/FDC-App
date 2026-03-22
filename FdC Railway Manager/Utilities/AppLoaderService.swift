import Foundation
import SwiftUI
import Combine

@MainActor
class AppLoaderService: ObservableObject {
    @Published var isLoading = false
    let appState: AppState
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func performInitialLoad() {
        isLoading = true
        defer { isLoading = false }

        // Load data into the new architecture
        appState.railroad.io.load()
        
        // Post-load tasks
        appState.railroad.lines.validateSchedules()
        
        // Pre-populate simulator for map visualization
        appState.simulator.schedules = appState.railroad.lines.generateSchedulesPreview()
    }
    
    func saveCurrentState() {
        // Delegate saving to the new IOManager
        appState.railroad.io.save()
    }
}
