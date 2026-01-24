import Foundation
import SwiftUI
import Combine

enum ImportStatus: Equatable {
    case idle
    case loading
    case success(summary: String)
    case failure(error: String)
}

@MainActor
class FDCImportViewModel: ObservableObject {
    @Published var status: ImportStatus = .idle
    // Reference to app state to populate
    var network: RailwayNetwork?
    var trainManager: TrainManager?
    var appState: AppState?

    init(network: RailwayNetwork? = nil, trainManager: TrainManager? = nil, appState: AppState? = nil) {
        self.network = network
        self.trainManager = trainManager
        self.appState = appState
    }

    func importBundledFDC(named name: String = "fdc2.fdc") async {
        status = .loading
        print("[FDCImportViewModel] Starting import of bundled file: \(name)")
        do {
            var fileURL: URL? = nil
            // direct lookup first
            if let u = Bundle.main.url(forResource: name, withExtension: nil) {
                fileURL = u
            } else {
                // fallback: search resources for any .fdc file
                if let resourceRoot = Bundle.main.resourceURL {
                    print("[FDCImportViewModel] resourceURL: \(resourceRoot.path), searching for .fdc files...")
                    let fm = FileManager.default
                    let enumerator = fm.enumerator(at: resourceRoot, includingPropertiesForKeys: nil)
                    while let item = enumerator?.nextObject() as? URL {
                        if item.pathExtension.lowercased() == "fdc" {
                            print("[FDCImportViewModel] Found .fdc file in bundle: \(item.path)")
                            fileURL = item
                            break
                        }
                    }
                } else {
                    print("[FDCImportViewModel] Bundle.resourceURL is nil; cannot search bundle resources")
                }
            }

            guard let url = fileURL else {
                status = .failure(error: "File \(name) non trovato nel bundle (neanche con ricerca)")
                print("[FDCImportViewModel] File not found in bundle after fallback search: \(name)")
                return
            }

            let data = try Data(contentsOf: url)
            print("[FDCImportViewModel] Read \(data.count) bytes from bundle file: \(url.path)")

            // Parse using FDCParser
            let parsed = try FDCParser.parse(data: data)
            print("[FDCImportViewModel] Parsed network: \(parsed.name) stations=\(parsed.stations.count) edges=\(parsed.edges.count) trains=\(parsed.trains.count)")

            // Map parsed into RailwayNetwork
            let nodes = parsed.stations.map { fdcStation in
                let type: Node.NodeType = {
                    switch fdcStation.type?.lowercased() {
                    case "interchange": return .interchange
                    case "depot": return .depot
                    default: return .station
                    }
                }()
                return Node(id: fdcStation.id, name: fdcStation.name, type: type, latitude: fdcStation.latitude, longitude: fdcStation.longitude, capacity: fdcStation.capacity, platforms: fdcStation.platformCount ?? 2)
            }
            let edges = parsed.edges.map { fdcEdge in
                let trackType: Edge.TrackType = {
                    switch fdcEdge.trackType?.lowercased() {
                    case "highspeed", "high_speed": return .highSpeed
                    case "single": return .single
                    case "double": return .double
                    default: return .regional
                    }
                }()
                return Edge(from: fdcEdge.from, to: fdcEdge.to, distance: fdcEdge.distance ?? 1.0, trackType: trackType, maxSpeed: Int(fdcEdge.maxSpeed ?? 120.0), capacity: fdcEdge.capacity)
            }
            
            // Mapping for train IDs (FDC String -> Swift UUID)
            var trainIdMap: [String: UUID] = [:]
            
            // Map trains
            let trains = parsed.trains.map { fdcTrain -> Train in
                let newId = UUID()
                trainIdMap[fdcTrain.id] = newId
                return Train(id: newId, 
                      name: fdcTrain.name, 
                      type: fdcTrain.type ?? "Regionale", 
                      maxSpeed: fdcTrain.maxSpeed ?? 120, 
                      priority: fdcTrain.priority ?? 5,
                      acceleration: fdcTrain.acceleration ?? 0.5,
                      deceleration: fdcTrain.deceleration ?? 0.5)
            }

            // Map schedules with correct UUIDs and Names
            let df = ISO8601DateFormatter()
            let mappedSchedules = parsed.rawSchedules.map { sch -> TrainSchedule in
                let stops = sch.stops.map { stop -> ScheduleStop in
                    let stationName = nodes.first(where: { $0.id == stop.node_id })?.name ?? stop.node_id
                    return ScheduleStop(stationId: stop.node_id, 
                                       arrivalTime: df.date(from: stop.arrival), 
                                       departureTime: df.date(from: stop.departure), 
                                       platform: stop.platform,
                                       dwellsMinutes: 2,
                                       stationName: stationName)
                }
                let swiftTrainId = trainIdMap[sch.train_id] ?? UUID()
                let trainName = trains.first(where: { $0.id == swiftTrainId })?.name ?? sch.train_id
                return TrainSchedule(trainId: swiftTrainId, trainName: trainName, stops: stops)
            }

            if let network = self.network {
                network.name = parsed.name
                network.nodes = nodes
                network.edges = edges
                network.lines = parsed.lines
                print("[FDCImportViewModel] Applied \(nodes.count) nodes, \(edges.count) edges, \(parsed.lines.count) lines")
            }
            
            if let trainManager = self.trainManager {
                trainManager.trains = trains
                print("[FDCImportViewModel] Applied \(trains.count) trains to TrainManager")
            }
            
            // Populate simulator
            if let appState = self.appState {
                appState.simulator.schedules = mappedSchedules
            }
            
            let summary = "Importati \(nodes.count) stazioni, \(edges.count) binari, \(parsed.lines.count) linee, \(trains.count) treni, \(mappedSchedules.count) orari"
            status = .success(summary: summary)
            print("[FDCImportViewModel] Import success: \(summary)")
        } catch let err as NSError {
            status = .failure(error: err.localizedDescription)
            print("[FDCImportViewModel] Import failed NSError: \(err.localizedDescription)")
        } catch {
            status = .failure(error: error.localizedDescription)
            print("[FDCImportViewModel] Import failed: \(error.localizedDescription)")
        }
    }
}
