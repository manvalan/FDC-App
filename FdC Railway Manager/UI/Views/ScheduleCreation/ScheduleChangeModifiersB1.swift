import SwiftUI
import Combine

struct ScheduleChangeModifiersB1: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: vm.intervalMinutes) { (oldValue: Int, newValue: Int) in vm.updatePreview() }
            .onChange(of: vm.scheduleReturn) { (oldValue: Bool, newValue: Bool) in vm.updatePreview() }
            .onChange(of: vm.preferredParity) { (oldValue: NumberParity, newValue: NumberParity) in
                vm.startNumber = (newValue == .odd) ? 1 : 2
                vm.returnStartNumber = (newValue == .odd) ? 2 : 1
            }
            .onChange(of: vm.startNumber) { (oldValue: Int, newValue: Int) in
                vm.returnStartNumber = (newValue % 2 == 0) ? 1 : 2
            }
    }
}
