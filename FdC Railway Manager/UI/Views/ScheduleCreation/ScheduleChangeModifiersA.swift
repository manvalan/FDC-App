import SwiftUI
import Combine

struct ScheduleChangeModifiersA: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState
    let handleOptimizedTimesConfirmed: (Bool) -> Void
    let handleStationChange: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: appState.optimizedTimesConfirmed) { _, confirmed in
                handleOptimizedTimesConfirmed(confirmed)
            }
            .onChange(of: vm.mode) { _, newMode in
                if newMode == .taktfahrplan && vm.intervalMinutes != 60 && vm.intervalMinutes != 120 {
                    vm.intervalMinutes = 120
                }
            }
            .onChange(of: vm.startStationId) { _, _ in handleStationChange() }
            .onChange(of: vm.endStationId) { _, _ in handleStationChange() }
            .onChange(of: vm.startTime) { _, _ in vm.updatePreview() }
            .onChange(of: vm.endTime) { _, _ in vm.updatePreview() }
    }
}
