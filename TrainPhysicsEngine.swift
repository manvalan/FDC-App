import Foundation

/// Motore fisico centralizzato per il calcolo realistico dei movimenti dei treni
/// Utilizza i parametri fisici reali dei modelli (accelerazione, frenatura, aderenza, massa, potenza)
class TrainPhysicsEngine {
    
    // MARK: - Constants
    
    /// Gravità terrestre (m/s²)
    private static let gravity: Double = 9.81
    
    /// Resistenza aerodinamica media per treni moderni (kg/m)
    private static let airResistanceCoefficient: Double = 0.003
    
    /// Margine di sicurezza per frenatura (moltiplicatore)
    private static let brakingSafetyMargin: Double = 1.15
    
    /// Tempo minimo di sosta in stazione (secondi)
    private static let minimumStopTime: Double = 30
    
    // MARK: - Main Physics Model
    
    /// Parametri fisici completi di un treno
    struct TrainPhysics {
        let maxSpeed: Double              // km/h
        let acceleration: Double          // m/s²
        let serviceBraking: Double        // m/s²
        let emergencyBraking: Double      // m/s²
        let adhesionCoefficient: Double   // coefficiente di aderenza
        let mass: Double                  // tonnellate
        let power: Double                 // kW
        
        /// Inizializzatore diretto con tutti i parametri
        init(maxSpeed: Double, acceleration: Double, serviceBraking: Double, 
             emergencyBraking: Double, adhesionCoefficient: Double, 
             mass: Double, power: Double) {
            self.maxSpeed = maxSpeed
            self.acceleration = acceleration
            self.serviceBraking = serviceBraking
            self.emergencyBraking = emergencyBraking
            self.adhesionCoefficient = adhesionCoefficient
            self.mass = mass
            self.power = power
        }
        
        /// Crea parametri fisici da un modello del database
        init(from model: TrainModel) {
            self.maxSpeed = Double(model.specifiche.velocita_max_kmh)
            self.acceleration = model.fisica.accelerazione_m_s2
            self.serviceBraking = model.fisica.frenatura_servizio_m_s2
            self.emergencyBraking = model.fisica.frenatura_emergenza_m_s2
            self.adhesionCoefficient = model.fisica.coefficiente_aderenza
            self.mass = model.specifiche.massa_tonnellate
            self.power = Double(model.specifiche.potenza_kw)
        }
        
        /// Crea parametri fisici da un Vehicle esistente
        init(from vehicle: Vehicle) {
            self.maxSpeed = vehicle.maxSpeed
            self.acceleration = vehicle.acceleration
            self.serviceBraking = vehicle.deceleration
            self.emergencyBraking = vehicle.deceleration * 1.3
            self.adhesionCoefficient = 0.22
            self.mass = 200.0
            self.power = 2500.0
        }
        
        /// Crea parametri fisici da un Train (usa valori di default se mancanti)
        init(from train: Train) {
            self.maxSpeed = train.maxSpeed
            self.acceleration = train.acceleration
            self.serviceBraking = train.deceleration
            self.emergencyBraking = train.deceleration * 1.3
            self.adhesionCoefficient = 0.22
            self.mass = 200.0
            self.power = 2500.0
        }
    }
    
    // MARK: - Travel Time Calculation
    
    /// Calcola il tempo di percorrenza tra due punti considerando fisica realistica
    /// - Parameters:
    ///   - distance: Distanza in km
    ///   - trackMaxSpeed: Velocità massima del binario in km/h
    ///   - physics: Parametri fisici del treno
    ///   - initialSpeed: Velocità iniziale in km/h (default: 0)
    ///   - finalSpeed: Velocità finale richiesta in km/h (default: 0)
    ///   - gradient: Pendenza media in % (positiva = salita, negativa = discesa)
    /// - Returns: Tempo in ore
    static func calculateTravelTime(
        distance: Double,
        trackMaxSpeed: Double,
        physics: TrainPhysics,
        initialSpeed: Double = 0,
        finalSpeed: Double = 0,
        gradient: Double = 0
    ) -> Double {
        
        guard distance > 0 else { return 0 }
        
        // Velocità effettiva: minimo tra velocità treno e velocità binario
        let effectiveMaxSpeed = min(physics.maxSpeed, trackMaxSpeed)
        
        // Converti velocità in m/s
        let v0 = initialSpeed / 3.6  // velocità iniziale
        let vf = finalSpeed / 3.6     // velocità finale
        let vmax = effectiveMaxSpeed / 3.6  // velocità massima
        let distanceM = distance * 1000  // distanza in metri
        
        // Calcola accelerazione e frenatura effettive considerando pendenza
        let effectiveAccel = calculateEffectiveAcceleration(
            physics: physics,
            gradient: gradient,
            isAccelerating: true
        )
        let effectiveBraking = calculateEffectiveAcceleration(
            physics: physics,
            gradient: gradient,
            isAccelerating: false
        )
        
        // Calcola distanze per accelerazione e frenatura
        let accelerationDistance: Double
        let brakingDistance: Double
        let accelerationTime: Double
        let brakingTime: Double
        
        if v0 < vmax {
            // Fase di accelerazione
            accelerationDistance = (vmax * vmax - v0 * v0) / (2 * effectiveAccel)
            accelerationTime = (vmax - v0) / effectiveAccel
        } else {
            accelerationDistance = 0
            accelerationTime = 0
        }
        
        if vmax > vf {
            // Fase di frenatura
            brakingDistance = (vmax * vmax - vf * vf) / (2 * effectiveBraking)
            brakingTime = (vmax - vf) / effectiveBraking
        } else {
            brakingDistance = 0
            brakingTime = 0
        }
        
        // Calcola fase di crociera a velocità costante
        let cruiseDistance = max(0, distanceM - accelerationDistance - brakingDistance)
        let cruiseTime = cruiseDistance / vmax
        
        // Se non c'è abbastanza spazio per accelerare e frenare
        if cruiseDistance < 0 {
            // Calcola velocità di picco raggiungibile
            let vPeak = sqrt(
                (v0 * v0 * effectiveBraking + vf * vf * effectiveAccel + 2 * distanceM * effectiveAccel * effectiveBraking) /
                (effectiveAccel + effectiveBraking)
            )
            
            let t1 = (vPeak - v0) / effectiveAccel
            let t2 = (vPeak - vf) / effectiveBraking
            
            return (t1 + t2) / 3600  // converti in ore
        }
        
        // Tempo totale in ore
        return (accelerationTime + cruiseTime + brakingTime) / 3600
    }
    
    // MARK: - Effective Acceleration with Gradient
    
    /// Calcola l'accelerazione effettiva considerando la pendenza
    private static func calculateEffectiveAcceleration(
        physics: TrainPhysics,
        gradient: Double,
        isAccelerating: Bool
    ) -> Double {
        
        // Componente gravitazionale della pendenza (m/s²)
        let gradientComponent = gravity * (gradient / 100.0)
        
        if isAccelerating {
            // In accelerazione, la pendenza riduce l'accelerazione disponibile
            let netAccel = physics.acceleration - gradientComponent
            
            // Verifica aderenza: F_trazione <= μ * m * g
            let maxTractionAccel = physics.adhesionCoefficient * gravity
            
            return max(0.1, min(netAccel, maxTractionAccel))
        } else {
            // In frenatura, la pendenza può aiutare (discesa) o ostacolare (salita)
            let netBraking = physics.serviceBraking + gradientComponent
            
            // Verifica aderenza in frenatura
            let maxBrakingAccel = physics.adhesionCoefficient * gravity * brakingSafetyMargin
            
            return max(0.3, min(netBraking, maxBrakingAccel))
        }
    }
    
    // MARK: - Power and Speed Limits
    
    /// Calcola la velocità massima sostenibile in salita data la potenza
    static func calculateMaxSpeedOnGradient(
        physics: TrainPhysics,
        gradient: Double
    ) -> Double {
        
        guard gradient > 0 else { return physics.maxSpeed }
        
        // Resistenza gravitazionale (kW)
        let gradientResistance = physics.mass * gravity * (gradient / 100.0) * physics.maxSpeed / 3.6 / 1000
        
        // Resistenza aerodinamica (approssimata)
        let airResistance = airResistanceCoefficient * pow(physics.maxSpeed / 3.6, 2) / 1000
        
        // Potenza disponibile per vincere le resistenze
        let availablePower = physics.power * 0.85  // 85% efficienza
        
        // Se la potenza non è sufficiente, calcola velocità sostenibile
        if gradientResistance + airResistance > availablePower {
            // Risolvi per velocità: P = (m*g*sin(θ) + k*v²) * v
            // Approssimiamo: v ≈ P / (m*g*sin(θ))
            let sustainableSpeed = (availablePower * 1000 * 3.6) / (physics.mass * gravity * gradient / 100.0)
            return min(physics.maxSpeed, sustainableSpeed)
        }
        
        return physics.maxSpeed
    }
    
    // MARK: - Braking Distance
    
    /// Calcola la distanza di frenatura di emergenza
    static func calculateEmergencyBrakingDistance(
        physics: TrainPhysics,
        currentSpeed: Double,
        gradient: Double = 0
    ) -> Double {
        
        let v = currentSpeed / 3.6  // m/s
        let gradientComponent = gravity * (gradient / 100.0)
        let effectiveBraking = physics.emergencyBraking + gradientComponent
        
        // Spazio di frenatura (metri)
        let brakingDistance = (v * v) / (2 * effectiveBraking)
        
        // Aggiungi tempo di reazione (2 secondi)
        let reactionDistance = v * 2.0
        
        return (brakingDistance + reactionDistance) / 1000  // converti in km
    }
    
    // MARK: - Stop Time Calculation
    
    /// Calcola il tempo di sosta in stazione
    static func calculateStopTime(
        stationType: StationType,
        passengers: PassengerLoad = .medium
    ) -> TimeInterval {
        
        let baseTime: Double
        
        switch stationType {
        case .terminal, .hub:
            baseTime = 180  // 3 minuti
        case .major:
            baseTime = 90   // 1.5 minuti
        case .minor, .stop:
            baseTime = 60   // 1 minuto
        case .junction:
            baseTime = 120  // 2 minuti (cambio direzione)
        case .depot:
            baseTime = 300  // 5 minuti (manutenzione)
        }
        
        // Modifica in base al carico passeggeri
        let passengerMultiplier: Double
        switch passengers {
        case .empty: passengerMultiplier = 0.7
        case .low: passengerMultiplier = 0.85
        case .medium: passengerMultiplier = 1.0
        case .high: passengerMultiplier = 1.2
        case .full: passengerMultiplier = 1.4
        }
        
        return max(minimumStopTime, baseTime * passengerMultiplier)
    }
    
    // MARK: - Energy Consumption
    
    /// Calcola il consumo energetico stimato (kWh)
    static func calculateEnergyConsumption(
        distance: Double,
        physics: TrainPhysics,
        averageSpeed: Double,
        gradient: Double = 0
    ) -> Double {
        
        let distanceM = distance * 1000
        
        // Energia cinetica
        let v = averageSpeed / 3.6
        let kineticEnergy = 0.5 * physics.mass * 1000 * v * v / 3600000  // kWh
        
        // Energia potenziale (se in salita)
        let potentialEnergy = physics.mass * 1000 * gravity * (distanceM * gradient / 100.0) / 3600000  // kWh
        
        // Energia per resistenza aerodinamica
        let time = distanceM / v
        let airResistanceEnergy = airResistanceCoefficient * v * v * time / 3600  // kWh
        
        // Totale (con efficienza 85%)
        return (kineticEnergy + potentialEnergy + airResistanceEnergy) / 0.85
    }
    
    // MARK: - Helper Enums
    
    enum StationType {
        case terminal, hub, major, minor, stop, junction, depot
    }
    
    enum PassengerLoad {
        case empty, low, medium, high, full
    }
}

// MARK: - Convenience Extensions

extension TrainPhysicsEngine.TrainPhysics {
    /// Crea parametri fisici di default per una categoria di treno
    static func defaultPhysics(for category: TrainCategory) -> TrainPhysicsEngine.TrainPhysics {
        switch category {
        case .highSpeed:
            return TrainPhysicsEngine.TrainPhysics(
                maxSpeed: 300,
                acceleration: 0.6,
                serviceBraking: 0.9,
                emergencyBraking: 1.2,
                adhesionCoefficient: 0.20,
                mass: 500,
                power: 8800
            )
        case .direct:
            return TrainPhysicsEngine.TrainPhysics(
                maxSpeed: 200,
                acceleration: 0.5,
                serviceBraking: 0.8,
                emergencyBraking: 1.1,
                adhesionCoefficient: 0.21,
                mass: 400,
                power: 4500
            )
        case .regional:
            return TrainPhysicsEngine.TrainPhysics(
                maxSpeed: 160,
                acceleration: 1.0,
                serviceBraking: 1.0,
                emergencyBraking: 1.3,
                adhesionCoefficient: 0.22,
                mass: 200,
                power: 2600
            )
        case .freight:
            return TrainPhysicsEngine.TrainPhysics(
                maxSpeed: 100,
                acceleration: 0.2,
                serviceBraking: 0.5,
                emergencyBraking: 0.7,
                adhesionCoefficient: 0.18,
                mass: 2000,
                power: 5000
            )
        case .support:
            return TrainPhysicsEngine.TrainPhysics(
                maxSpeed: 120,
                acceleration: 0.3,
                serviceBraking: 0.6,
                emergencyBraking: 0.9,
                adhesionCoefficient: 0.20,
                mass: 100,
                power: 1500
            )
        }
    }
}
