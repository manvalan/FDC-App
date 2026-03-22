import SwiftUI
import Foundation
import Combine

// MARK: - Inspector Navigator (stack di pagine)
@MainActor
public class InspectorNavigator: ObservableObject {
    public struct Page: Identifiable {
        public let id = UUID()
        public let title: String
        public let content: AnyView
        
        public init(title: String, content: AnyView) {
            self.title = title
            self.content = content
        }
    }
    
    @Published public var stack: [Page] = []
    
    public var currentTitle: String? {
        stack.last?.title
    }
    
    public var canGoBack: Bool {
        !stack.isEmpty
    }
    
    public func push<V: View>(title: String, @ViewBuilder content: () -> V) {
        stack.append(Page(title: title, content: AnyView(content())))
    }
    
    public func pop() {
        if !stack.isEmpty {
            stack.removeLast()
        }
    }
    
    public func popToRoot() {
        stack.removeAll()
    }
    
    public init() {}
}
