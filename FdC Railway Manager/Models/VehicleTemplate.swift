import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers
import CoreLocation
import MapKit

struct VehicleTemplate: Identifiable {
    var id: String { name }
    let name: String
    let model: String
    let length: Double
    let maxSpeed: Double
    let acceleration: Double
    let deceleration: Double
    let mass: Double
    let power: Double
    let isElectric: Bool
    let imageName: String?
    
    init(name: String, model: String, length: Double, maxSpeed: Double, acceleration: Double = 0.5, deceleration: Double = 0.4, mass: Double = 200, power: Double = 2500, isElectric: Bool = true, imageName: String? = nil) {
        self.name = name
        self.model = model
        self.length = length
        self.maxSpeed = maxSpeed
        self.acceleration = acceleration
        self.deceleration = deceleration
        self.mass = mass
        self.power = power
        self.isElectric = isElectric
        self.imageName = imageName
    }
    
    static let all: [VehicleTemplate] = [
        // --- ALSTOM ---
        VehicleTemplate(name: "ETR 103 (Pop 3 casse)", model: "ETR 103", length: 65, maxSpeed: 160, acceleration: 1.0, mass: 140, power: 2000, imageName: "pop_3_casse"),
        VehicleTemplate(name: "ETR 104 (Pop 4 casse)", model: "ETR 104", length: 84, maxSpeed: 160, acceleration: 1.0, mass: 180, power: 2600, imageName: "pop_4_casse"),
        VehicleTemplate(name: "ETR 204 (Pop 4 casse V2)", model: "ETR 204", length: 84, maxSpeed: 160, acceleration: 1.1, mass: 185, power: 2800, imageName: "pop_4_casse_v2"),
        VehicleTemplate(name: "ETR 255 (Pop 5 casse)", model: "ETR 255", length: 104, maxSpeed: 160, acceleration: 0.9, mass: 220, power: 3200, imageName: "pop_5_casse"),
        VehicleTemplate(name: "ETR 425 (Jazz 5 casse)", model: "ETR 425", length: 82, maxSpeed: 160, acceleration: 0.9, mass: 175, power: 2400, imageName: "jazz_5_casse"),
        VehicleTemplate(name: "ETR 324 (Jazz 4 casse)", model: "ETR 324", length: 67, maxSpeed: 160, acceleration: 1.0, mass: 145, power: 2000, imageName: "jazz_4_casse"),
        VehicleTemplate(name: "ALn/Eln 501 (Minuetto)", model: "ALn 501", length: 52, maxSpeed: 130, acceleration: 0.8, mass: 110, power: 1250, isElectric: false, imageName: "minuetto"),
        VehicleTemplate(name: "ETR 600/610 (Pendolino)", model: "ETR 600", length: 187, maxSpeed: 250, acceleration: 0.48, mass: 390, power: 5500, imageName: "pendolino_etr600"),
        VehicleTemplate(name: "ETR 485 (Pendolino)", model: "ETR 485", length: 236, maxSpeed: 250, acceleration: 0.45, mass: 440, power: 5600, imageName: "pendolino_etr485"),
        
        // --- HITACHI / ANSALDO BREDA ---
        VehicleTemplate(name: "ETR 1000 (Frecciarossa)", model: "ETR 1000", length: 202, maxSpeed: 360, acceleration: 0.7, mass: 450, power: 9800, imageName: "frecciarossa_1000"),
        VehicleTemplate(name: "ETR 500 (Frecciarossa)", model: "ETR 500", length: 328, maxSpeed: 300, acceleration: 0.35, mass: 550, power: 8800, imageName: "frecciarossa_500"),
        VehicleTemplate(name: "ETR 700 (Frecciargento)", model: "ETR 700", length: 202, maxSpeed: 250, acceleration: 0.45, mass: 440, power: 5560, imageName: "frecciargento_700"),
        
        // --- INTERCITY (COMP. FISSA) ---
        VehicleTemplate(name: "E.401 + 8 UIC-Z (IC)", model: "E.401", length: 220, maxSpeed: 200, acceleration: 0.4, mass: 500, power: 6000, imageName: "ic_e401"),
        VehicleTemplate(name: "E.402B + 8 UIC-Z (IC)", model: "E.402B", length: 225, maxSpeed: 200, acceleration: 0.4, mass: 520, power: 6000, imageName: "ic_e402b"),
        VehicleTemplate(name: "ETR 421 (Rock 4 casse)", model: "ETR 421", length: 110, maxSpeed: 160, acceleration: 1.1, mass: 220, power: 3400, imageName: "rock_4_casse"),
        VehicleTemplate(name: "ETR 521 (Rock 5 casse)", model: "ETR 521", length: 136, maxSpeed: 160, acceleration: 1.0, mass: 270, power: 4200, imageName: "rock_5_casse"),
        VehicleTemplate(name: "ETR 621 (Rock 6 casse)", model: "ETR 621", length: 162, maxSpeed: 160, acceleration: 0.9, mass: 320, power: 5000, imageName: "rock_6_casse"),
        VehicleTemplate(name: "HTR 312 (Blues 3 casse)", model: "HTR 312", length: 67, maxSpeed: 160, acceleration: 1.0, mass: 150, power: 2200, isElectric: true, imageName: "blues_3_casse"),
        VehicleTemplate(name: "HTR 412 (Blues 4 casse)", model: "HTR 412", length: 86, maxSpeed: 160, acceleration: 0.9, mass: 190, power: 2800, isElectric: true, imageName: "blues_4_casse"),
        VehicleTemplate(name: "TAF (Treno Alta Freq.)", model: "TAF", length: 104, maxSpeed: 140, acceleration: 0.8, mass: 210, power: 2300, imageName: "taf"),
        VehicleTemplate(name: "TSR (Treno Serv. Reg.)", model: "TSR", length: 78, maxSpeed: 140, acceleration: 0.9, mass: 165, power: 2500, imageName: "tsr"),
        
        // --- STADLER ---
        VehicleTemplate(name: "ATR 803 (Colleoni)", model: "ATR 803", length: 67, maxSpeed: 140, acceleration: 1.0, mass: 135, power: 1800, isElectric: false, imageName: "colleoni"),
        VehicleTemplate(name: "ETR 170 (FLIRT)", model: "ETR 170", length: 75, maxSpeed: 160, acceleration: 1.2, mass: 125, power: 2600, imageName: "flirt"),
        VehicleTemplate(name: "ETR 343 (FLIRT XL)", model: "ETR 343", length: 105, maxSpeed: 160, acceleration: 1.1, mass: 180, power: 3000, imageName: "flirt_xl"),
        
        // --- PESA ---
        VehicleTemplate(name: "ATR 220 (Swing)", model: "ATR 220", length: 55, maxSpeed: 130, acceleration: 0.7, mass: 105, power: 1100, isElectric: false, imageName: "swing"),
        
        // --- LOCOMOTIVE / NAVETTA ---
        VehicleTemplate(name: "E.464 + 5 Medie Distanze", model: "E.464", length: 155, maxSpeed: 160, acceleration: 0.5, mass: 310, power: 3500, isElectric: true, imageName: "navetta_md"),
        VehicleTemplate(name: "E.464 + 3 Vivalto", model: "E.464", length: 110, maxSpeed: 160, acceleration: 0.7, mass: 230, power: 3500, isElectric: true, imageName: "vivalto_3"),
        VehicleTemplate(name: "E.464 + 5 Vivalto", model: "E.464", length: 160, maxSpeed: 160, acceleration: 0.5, mass: 330, power: 3500, isElectric: true, imageName: "vivalto_5"),
        VehicleTemplate(name: "E.494 (TRAXX DC3)", model: "E.494", length: 19, maxSpeed: 160, acceleration: 0.4, mass: 82, power: 6400, isElectric: true, imageName: "traxx_dc3"),
        VehicleTemplate(name: "E.191/193 (Vectron)", model: "E.191", length: 19, maxSpeed: 200, acceleration: 0.5, mass: 86, power: 6400, isElectric: true, imageName: "vectron"),
        VehicleTemplate(name: "E.652 (Caimano)", model: "E.652", length: 18, maxSpeed: 160, acceleration: 0.4, mass: 106, power: 5000, isElectric: true, imageName: "caimano"),
        VehicleTemplate(name: "D.445 (Loco Diesel)", model: "D.445", length: 14, maxSpeed: 130, acceleration: 0.3, mass: 72, power: 1560, isElectric: false, imageName: "d445"),
        
        // --- LEGACY / STORICI ---
        VehicleTemplate(name: "ALn 663 (Singola)", model: "Fiat Ferroviaria (Diesel)", length: 23, maxSpeed: 120, acceleration: 0.4, mass: 43, power: 340, isElectric: false, imageName: "aln663"),
        VehicleTemplate(name: "ALn 776 (Singola)", model: "Ferrosud (Diesel)", length: 24, maxSpeed: 150, acceleration: 0.6, mass: 45, power: 450, isElectric: false, imageName: "aln776")
    ]
}
