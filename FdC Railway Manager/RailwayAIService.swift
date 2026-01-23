import Foundation
import Combine

class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
    private let baseURL = URL(string: "http://localhost:8002/api/v2")!
    
    func optimize(request: RailwayAIRequest) -> AnyPublisher<RailwayAIResponse, Error> {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("optimize"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .map(\.data)
            .decode(type: RailwayAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Helper to convert current app state to RailwayAIRequest
    func createRequest(network: RailwayNetwork, trains: [Train], currentConflicts: [String] = []) -> RailwayAIRequest {
        let stations = network.nodes.map { $0.id }
        var availablePlatforms: [String: [Int]] = [:]
        for node in network.nodes {
            if let p = node.platforms {
                availablePlatforms[node.id] = Array(1...p)
            } else {
                availablePlatforms[node.id] = [1, 2] // Default
            }
        }
        
        var maxSpeeds: [String: Double] = [:]
        for edge in network.edges {
            let sectionID = "\(edge.from)_\(edge.to)"
            maxSpeeds[sectionID] = Double(edge.maxSpeed)
        }
        
        let networkInfo = RailwayAINetworkInfo(
            stations: stations,
            available_platforms: availablePlatforms,
            max_speeds: maxSpeeds
        )
        
        let trainInfos = trains.map { train in
            RailwayAITrainInfo(
                train_id: train.id.uuidString,
                arrival: nil, // To be filled if available in schedule
                departure: nil,
                platform: nil,
                current_speed_kmh: Double(train.maxSpeed),
                priority: 5 // Default
            )
        }
        
        // Mocking a conflict if none provided but trains exist
        let conflicts = currentConflicts.isEmpty && !trains.isEmpty ? [
            RailwayAIConflictInput(
                conflict_type: "platform_conflict",
                location: stations.first ?? "UNKNOWN",
                trains: Array(trainInfos.prefix(2)),
                severity: "medium",
                time_overlap_seconds: 60
            )
        ] : [] // In a real app, this would be computed from the schedule
        
        return RailwayAIRequest(
            conflicts: conflicts,
            network: networkInfo,
            preferences: nil
        )
    }
}
