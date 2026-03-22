import SwiftUI
import Combine

// Owns sidebar navigation, active panel, and inspector tab selection.
// AppState holds an instance and forwards changes to its objectWillChange.
@MainActor
final class NavigationState: ObservableObject {

    @Published var sidebarSelection: SidebarItem? = .lines
    @Published var jumpToTrainId: UUID? = nil
    @Published var activePanel: ActivePanel = .none
    @Published var lineInspectorMode: LineInspectorMode = .infrastructure

    // MARK: - Convenience accessors

    var isSideMenuVisible: Bool { activePanel == .sidebar }
    var isInspectorVisible: Bool { activePanel == .inspector }
    var isModeBarVisible: Bool { activePanel == .modeBar }

    // MARK: - Panel management

    func showPanel(_ panel: ActivePanel) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            activePanel = panel
        }
    }

    func togglePanel(_ panel: ActivePanel) {
        showPanel(activePanel == panel ? .none : panel)
    }
}
