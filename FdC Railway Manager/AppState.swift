import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var showAI: Bool = false
    var aiNetwork: RailwayNetwork? = nil
    @Published var didAutoImport: Bool = false
    @Published var importMessage: String? = nil
}
