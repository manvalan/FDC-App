import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

struct RailwayNetworkDTO: Codable {
    var name: String? = nil
    let nodes: [RailwayNode]
    let edges: [RailwayEdge]
    /// Infrastructure lines (ex `ferrovie`). JSON key kept as `"ferrovie"` for backward compat.
    var lines: [RailwayLine]? = nil
    /// Service-route templates (ex `lines`). JSON key kept as `"lines"` for backward compat.
    var routes: [TrainRoute]? = nil
    var trains: [RailwayTrain]? = nil
    var vehicles: [RailwayVehicle]? = nil

    enum CodingKeys: String, CodingKey {
        case name, nodes, edges
        case lines   = "ferrovie"   // physical infrastructure lines
        case routes  = "lines"      // service route templates
        case trains, vehicles
    }
}
