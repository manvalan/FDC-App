import SwiftUI
import Combine

struct ScheduleChangeModifiersB2: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .onChange(of: vm.stationSequence) { (oldValue: [String], newValue: [String]) in
                // if appState.useCloudAI && newValue.count >= 2 { vm.triggerLineAnalysis() }
            }
            .onChange(of: vm.selectedTrainType) { (oldValue: TrainCategory, newValue: TrainCategory) in
                vm.updateSuggestedVehicles()
            }
    }
}
