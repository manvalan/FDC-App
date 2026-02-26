import SwiftUI
import UniformTypeIdentifiers
import CoreLocation

struct StationSnippet: Decodable {
    let id: String
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let type: String?
}
