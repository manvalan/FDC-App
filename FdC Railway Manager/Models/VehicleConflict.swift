import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

struct VehicleConflict: Identifiable {
    var id: UUID = UUID()
    let trainA: Train
    let trainB: Train
    let arrivalA: Date
    let departureB: Date
    
    var description: String {
        "Il treno \(trainA.name) arriva alle \(arrivalA.timeFormat), ma il treno \(trainB.name) parte alle \(departureB.timeFormat). Tempo di giro insufficiente."
    }
}
