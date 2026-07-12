import XCTest
@testable import FdC_Railway_Manager

/// Regressione per TAKTFAHRPLAN_120MIN_FIX.md:
/// con cadenza 120 min, T1+T2 della stessa coppia devono
/// incontrarsi allo stesso hub Takt (±5 min).
@MainActor
final class Taktfahrplan120MinTests: XCTestCase {

    private var calendar: Calendar!
    private var taktEngine: TaktEngine!
    private var nodes: [RailwayNode]!
    private var edges: [Edge]!

    override func setUp() {
        super.setUp()
        calendar = Calendar.current

        let nodeA = RailwayNode(
            id: "A", name: "Origine", type: .station,
            latitude: 43.0, longitude: 11.0, altitude: 0
        )
        var nodeB = RailwayNode(
            id: "B", name: "Hub Takt", type: .interchange,
            latitude: 43.1, longitude: 11.0, altitude: 50
        )
        nodeB.taktMinutes = 45
        let nodeC = RailwayNode(
            id: "C", name: "Destinazione", type: .station,
            latitude: 43.2, longitude: 11.0, altitude: 0
        )
        nodes = [nodeA, nodeB, nodeC]
        edges = [
            Edge(from: "A", to: "B", distance: 10.0,
                 trackType: .single, maxSpeed: 120),
            Edge(from: "B", to: "C", distance: 10.0,
                 trackType: .single, maxSpeed: 120),
        ]

        let topology = RailwayTopology(nodes: nodes, edges: edges)
        taktEngine = TaktEngine(
            topology: topology,
            kinematicCalculator: KinematicCalculator(topology: topology)
        )
    }

    // MARK: - Unit: taktHubTimes

    func test_taktHubTimes_sameBase_T1T2_arriveWithinFiveMinutes() {
        let base = calendar.date(
            from: DateComponents(
                year: 2026, month: 1, day: 1,
                hour: 7, minute: 45
            )
        )!
        let t1 = Train(
            number: 101, name: "T1", type: "R",
            departureTime: base, stops: [], isMainTrain: true
        )
        let t2 = Train(
            number: 102, name: "T2", type: "R",
            departureTime: base, stops: [], isMainTrain: true
        )

        let (arr1, _) = taktEngine.taktHubTimes(
            train: t1, base: base, calendar: calendar
        )
        let (arr2, _) = taktEngine.taktHubTimes(
            train: t2, base: base, calendar: calendar
        )
        let delta = abs(arr1.timeIntervalSince(arr2))

        XCTAssertLessThan(
            delta, 5 * 60,
            "T1 e T2 devono arrivare entro 5 min allo stesso hub"
        )
    }

    // MARK: - Integration: generaOrarioCadenzato

    func test_generaOrarioCadenzato_120minPair_sameHubWindow() async {
        let dep = calendar.date(
            from: DateComponents(
                year: 2026, month: 1, day: 1,
                hour: 5, minute: 0
            )
        )!
        let t1 = makeTrain(
            number: 101, departure: dep,
            stationIds: ["A", "B", "C"]
        )
        let t2 = makeTrain(
            number: 102, departure: dep,
            stationIds: ["C", "B", "A"]
        )

        let result = await taktEngine.generaOrarioCadenzato(
            newTrains: [t1, t2],
            existingTrains: [],
            preferredTaktNodeId: "B"
        )

        XCTAssertEqual(result.count, 2)
        let hubArrivals = result.compactMap { train -> Date? in
            train.stops.first(where: { $0.stationId == "B" })?.arrival
        }
        XCTAssertEqual(hubArrivals.count, 2)

        let delta = abs(
            hubArrivals[0].timeIntervalSince(hubArrivals[1])
        )
        XCTAssertLessThan(
            delta, 5 * 60,
            "Coppia T1+T2: arrivi all'hub B devono coincidere (±5 min)"
        )
    }

    func test_generaOrarioCadenzato_twoCycles_pairsMeetSeparately() async {
        let dep1 = calendar.date(
            from: DateComponents(
                year: 2026, month: 1, day: 1,
                hour: 5, minute: 0
            )
        )!
        let dep2 = calendar.date(
            byAdding: .minute, value: 120, to: dep1
        )!
        let trains = [
            makeTrain(number: 101, departure: dep1,
                      stationIds: ["A", "B", "C"]),
            makeTrain(number: 102, departure: dep1,
                      stationIds: ["C", "B", "A"]),
            makeTrain(number: 103, departure: dep2,
                      stationIds: ["A", "B", "C"]),
            makeTrain(number: 104, departure: dep2,
                      stationIds: ["C", "B", "A"]),
        ]

        let result = await taktEngine.generaOrarioCadenzato(
            newTrains: trains,
            existingTrains: [],
            preferredTaktNodeId: "B"
        )

        XCTAssertEqual(result.count, 4)
        let pair1 = hubArrivalDelta(
            in: result, numbers: [101, 102]
        )
        let pair2 = hubArrivalDelta(
            in: result, numbers: [103, 104]
        )

        XCTAssertLessThan(pair1, 5 * 60, "Coppia 101+102")
        XCTAssertLessThan(pair2, 5 * 60, "Coppia 103+104")
        XCTAssertGreaterThan(
            abs(pair1HubMidpoint(result, [101, 102])
                - pair1HubMidpoint(result, [103, 104])),
            30 * 60,
            "I due cicli 120 min devono usare hub window distinti"
        )
    }

    // MARK: - Helpers

    private func makeTrain(
        number: Int, departure: Date, stationIds: [String]
    ) -> Train {
        let stops = stationIds.map {
            RelationStop(stationId: $0, minDwellTime: 3)
        }
        return Train(
            number: number,
            name: "T\(number)",
            type: "R",
            departureTime: departure,
            stops: stops,
            maxSpeed: 120,
            acceleration: 0.5,
            deceleration: 0.5,
            mass: 200,
            power: 2500,
            isMainTrain: true
        )
    }

    private func hubArrivalDelta(
        in trains: [Train], numbers: [Int]
    ) -> TimeInterval {
        let arrivals = trains
            .filter { numbers.contains($0.number ?? -1) }
            .compactMap {
                $0.stops.first(where: { $0.stationId == "B" })?.arrival
            }
        guard arrivals.count == 2 else { return .infinity }
        return abs(arrivals[0].timeIntervalSince(arrivals[1]))
    }

    private func pair1HubMidpoint(
        _ trains: [Train], _ numbers: [Int]
    ) -> TimeInterval {
        let arrivals = trains
            .filter { numbers.contains($0.number ?? -1) }
            .compactMap {
                $0.stops.first(where: { $0.stationId == "B" })?.arrival
            }
        guard arrivals.count == 2 else { return 0 }
        return (arrivals[0].timeIntervalSince1970
            + arrivals[1].timeIntervalSince1970) / 2
    }
}
