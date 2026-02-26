
import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

// Bridge for refactoring compatibility
typealias RailwayNetwork = NetworkModel
typealias TrainManager = LinesManager
typealias RailwayEdge = Edge // Disambiguation from SwiftUI.Edge
typealias RailwayTrackSegment = TrackSegment
typealias RailwayNode = Node
typealias RailwayVehicle = Vehicle
typealias RailwayTrain = Train
