import SwiftUI
import Combine

struct ScheduleChangeModifiersB: ViewModifier {
    @ObservedObject var vm: ScheduleCreationViewModel
    @ObservedObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .modifier(ScheduleChangeModifiersB1(vm: vm))
            .modifier(ScheduleChangeModifiersB2(vm: vm, appState: appState))
    }
}
