import Foundation

struct ProposedLine: Codable {
    let id: String
    let origin: Int
    let destination: Int
    let stops: [Int]  // Complete route with all intermediate stations
    let frequency: String
    let firstDepartureMinute: Int

    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, origin, destination, stops, frequency, color
        case firstDepartureMinute = "first_departure_minute"
    }

    // Compatibility computed properties for the UI
    var name: String {
        let graph = RailwayGraphManager.shared
        if let s1 = graph.getOriginalStationId(fromNumericId: origin),
           let s2 = graph.getOriginalStationId(fromNumericId: destination) {
            return "Linea Rapida \(s1) - \(s2)"
        }
        return id
    }
    
    var stationSequence: [String] {
        let graph = RailwayGraphManager.shared
        
        // Use the complete stops array if available
        if !stops.isEmpty {
            return stops.compactMap { graph.getOriginalStationId(fromNumericId: $0) }
        }
        
        // Fallback to origin/destination only
        let sA = graph.getOriginalStationId(fromNumericId: origin) ?? String(origin)
        let sB = graph.getOriginalStationId(fromNumericId: destination) ?? String(destination)
        return [sA, sB]
    }
    
    var frequencyMinutes: Int {
        // Extract number from "Every 30 min"
        let digits = frequency.filter { "0123456789".contains($0) }
        return Int(digits) ?? 60
    }
}

struct SchedulePreviewItem: Codable {
    let line: String
    let departure: String
    let origin: Int
    let destination: Int
    let stops: [Int]  // Complete route with all intermediate stations
}

struct ProposalResponse: Codable {
    let proposedLines: [ProposedLine]
    let schedulePreviewItems: [SchedulePreviewItem]?

    enum CodingKeys: String, CodingKey {
        case proposedLines = "proposed_lines"
        case schedulePreviewItems = "schedule_preview"
    }
}

struct ProposerResponseRoot: Codable {
    let success: Bool?
    let proposal: ProposalResponse?
    let error: String?
    let message: String?
    let detail: String?
}

class ScheduleProposer {
    static let shared = ScheduleProposer()
    
    private init() {}
    
    func requestProposal(using graph: RailwayGraphManager, network: RailwayNetwork, targetLines: Int, completion: @escaping (Result<ProposalResponse, Error>) -> Void) {
        // 1. Generate the network JSON using the graph manager
        guard let networkDict = graph.generateAIRequestDictionary(for: [], network: network) else {
            completion(.failure(NSError(domain: "Impossibile generare il grafo della rete.", code: 0)))
            return
        }
        
        // 2. Prepare the endpoint
        let baseURL = AppState.shared.aiEndpoint.isEmpty ? "http://railway-ai.michelebigi.it:8080" : AppState.shared.aiEndpoint
        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)api/v1/propose_schedule" : "\(baseURL)/api/v1/propose_schedule"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "URL Proposta non valido: \(urlString)", code: 0)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        print("[ScheduleProposer] Requesting: \(url.absoluteString)")
        
        // PIGNOLO PROTOCOL: Flatten the dictionary. Server expects stations and tracks at top level.
        var body = networkDict
        body["target_lines"] = targetLines
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 3. Attach Authentication
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        // 4. Execute Network Request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(NSError(domain: "Nessun dato ricevuto.", code: 0))) }
                return
            }
            
            // Log response for debug
            if let body = String(data: data, encoding: .utf8) {
                print("[ScheduleProposer] Response: \(body)")
            }
            
            do {
                let decoder = JSONDecoder()
                let root = try decoder.decode(ProposerResponseRoot.self, from: data)
                
                if let proposal = root.proposal {
                    DispatchQueue.main.async { completion(.success(proposal)) }
                } else {
                    let errorMessage = root.error ?? root.message ?? root.detail ?? "Errore sconosciuto dall'IA."
                    DispatchQueue.main.async { completion(.failure(NSError(domain: errorMessage, code: 0))) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
