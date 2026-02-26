import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public struct Switch: Identifiable, Codable, Hashable {
    public let id: UUID
    public let nodeId: String
    public var state: SwitchState = .normal
    public let connectedEdges: [UUID] // ID degli Edge collegati
    
    public enum SwitchState: String, Codable {
        case normal, reverse
    }
}
