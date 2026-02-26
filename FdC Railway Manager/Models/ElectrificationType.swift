import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

public enum ElectrificationType: String, Codable, CaseIterable, Identifiable {
    case none = "Nessuna (Diesel)"
    case dc3kv = "3kV CC"
    case ac25kv = "25kV CA"
    case dc950v = "950V CC" // Tipico FdC
    
    public var id: String { rawValue }
    
    public var isElectrified: Bool {
        return self != .none
    }
}
