import XCTest
@testable import FdC_Railway_Manager

final class SchedulingServicesTests: XCTestCase {
    
    var network: RailwayNetwork!
    var trainManager: TrainManager!
    
    override func setUp() {
        super.setUp()
        let networkModel = NetworkModel()
        network = RailwayNetwork()
        // Mocking a simple network: A (0m) --10km-- B (100m) --10km-- C (50m)
        let nodeA = RailwayNode(id: "A", name: "Stazione A", type: .station, latitude: 43.0, longitude: 11.0, altitude: 0)
        let nodeB = RailwayNode(id: "B", name: "Stazione B", type: .hub, latitude: 43.1, longitude: 11.0, altitude: 100)
        let nodeC = RailwayNode(id: "C", name: "Stazione C", type: .station, latitude: 43.2, longitude: 11.0, altitude: 50)
        
        network.nodes = [nodeA, nodeB, nodeC]
        network.edges = [
            RailwayEdge(from: "A", to: "B", distance: 10.0, trackType: .single, maxSpeed: 120),
            RailwayEdge(from: "B", to: "C", distance: 10.0, trackType: .single, maxSpeed: 100)
        ]
        
        trainManager = TrainManager(network: networkModel)
    }
    
    // MARK: - PathResolver Tests
    
    func testPathResolverSequence() {
        let resolver = PathResolver(network: network)
        let sequence = resolver.resolveStationSequence(startId: "A", endId: "C")
        
        XCTAssertEqual(sequence.count, 3)
        XCTAssertEqual(sequence[0], "A")
        XCTAssertEqual(sequence[1], "B")
        XCTAssertEqual(sequence[2], "C")
    }
    
    func testPathResolverHasHighSpeed() {
        let resolver = PathResolver(network: network)
        XCTAssertFalse(resolver.hasHighSpeedTrack(stationSequence: ["A", "B", "C"]))
        
        // Add a high speed edge
        network.edges.append(RailwayEdge(from: "A", to: "C", distance: 18.0, trackType: .highSpeed, maxSpeed: 300))
        XCTAssertTrue(resolver.hasHighSpeedTrack(stationSequence: ["A", "C"]))
    }
    
    // MARK: - KinematicCalculator Tests
    
    func testKinematicCalculatorLegTime() {
        let calculator = KinematicCalculator(network: network)
        let train = Train(id: UUID(), number: 101, name: "Test", type: "regional", 
                          lineId: nil, departureTime: Date(), stops: [], 
                          vehicleId: nil, maxSpeed: 160, acceleration: 1.0, 
                          deceleration: 1.0, mass: 200, power: 2600, 
                          priority: 1, isElectric: true, isMainTrain: true)
        
        let minutes = calculator.legTravelMinutes(from: "A", to: "B", train: train)
        
        // Distance 10km, maxSpeed 120kmh. 
        // 10km at 120kmh = 5 minutes. + acceleration/deceleration + 35s constant.
        XCTAssertGreaterThan(minutes, 5.0)
        XCTAssertLessThan(minutes, 8.0)
    }
    
    func testAltitudeCharacteristics() {
        let calculator = KinematicCalculator(network: network)
        let chars = calculator.calculateAltitudeCharacteristics(stationSequence: ["A", "B", "C"])
        
        // A(0) -> B(100) is 100m gain. B(100) -> C(50) is 50m descent.
        XCTAssertEqual(chars.totalElevationGain, 100.0)
        XCTAssertNotNil(chars.maxGradient)
    }
    
    // MARK: - TaktEngine Tests
    
    func testTaktEngineSuggestions() {
        // Setup B as a Takt node at minute 30
        if let idx = network.nodes.firstIndex(where: { $0.id == "B" }) {
            network.nodes[idx].taktMinutes = 30
        }
        
        let kinematic = KinematicCalculator(network: network)
        let engine = TaktEngine(network: network, kinematicCalculator: kinematic)
        
        let suggestions = engine.calculateTaktSuggestions(stationSequence: ["A", "B", "C"])
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions[0].taktMinute, 30)
        XCTAssertFalse(suggestions[0].suggestedArrival.isEmpty)
    }
    
    // MARK: - VehicleSuitabilityEngine Tests
    
    func testVehicleSuitability() {
        let kinematic = KinematicCalculator(network: network)
        let engine = VehicleSuitabilityEngine(kinematicCalculator: kinematic)
        
        let regionalVehicle = Vehicle(id: UUID(), name: "Regionale", mass: 200, power: 2600, maxSpeed: 160, acceleration: 1.0, deceleration: 1.0, isElectric: true)
        let freightVehicle = Vehicle(id: UUID(), name: "Merci", mass: 2000, power: 5000, maxSpeed: 100, acceleration: 0.2, deceleration: 0.5, isElectric: true)
        
        let scoreReg = engine.calculateSuitabilityScore(
            vehicle: regionalVehicle, lineMaxSpeed: 120, 
            stationSequence: ["A", "B", "C"], estimatedDistance: 20.0, 
            isLineElectrified: true)
        
        let scoreFreight = engine.calculateSuitabilityScore(
            vehicle: freightVehicle, lineMaxSpeed: 120, 
            stationSequence: ["A", "B", "C"], estimatedDistance: 20.0, 
            isLineElectrified: true)
        
        XCTAssertGreaterThan(scoreReg, scoreFreight, "Regional vehicle should be more suitable for a passenger line than a freight locomotive")
    }
}
