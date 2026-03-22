import Foundation
import SwiftUI
import Combine

extension RailwayAIService {
    func optimize(request: RailwayAIRequest) -> AnyPublisher<RailwayAIResponse, Error> {
        // PIGNOLO PROTOCOL: Guard against server-side limits (max 50 trains)
        if request.trains.count > 50 {
            let error = NSError(
                domain: "ai_limit_title".localized,
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: String(format: "ai_too_many_trains_fmt".localized, request.trains.count)]
            )
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        let finalURL = baseURL.appendingPathComponent("optimize")
        print("\n" + String(repeating: "🌐", count: 40))
        print("🚀 [AI START] Inizio richiesta di ottimizzazione...")
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 240.0 // 4 minuti per gestire code sul server
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        // Use central AuthManager to ensure Header Unico and prioritize API Key
        authManager.attachAuthHeaders(to: &urlRequest)
        
        do {
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(request)
            urlRequest.httpBody = jsonData
            
            print("📦 [DEBUG] Payload pronto: \(jsonData.count) bytes.")
            
            // Log in background per ispezione UI (non rallenta la richiesta)
            DispatchQueue.global(qos: .background).async {
                let prettyEncoder = JSONEncoder()
                prettyEncoder.outputFormatting = .prettyPrinted
                if let prettyData = try? prettyEncoder.encode(request),
                   let prettyJson = String(data: prettyData, encoding: .utf8) {
                    print("\n" + String(repeating: "📤", count: 20))
                    print("📤 [AI REQUEST FULL JSON]:\n\(prettyJson)")
                    print(String(repeating: "📤", count: 20) + "\n")
                    DispatchQueue.main.async {
                        self.lastRequestJSON = prettyJson
                    }
                    let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
                    try? prettyJson.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
                }
            }
        } catch {
            print("❌ [AI ERROR] Encoding failed: \(error)")
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        print("📡 [DEBUG] Cessione richiesta a URLSession...")
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(.seconds(240), scheduler: DispatchQueue.global(qos: .userInitiated))
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let rawBody = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                
                print("\n" + String(repeating: "📥", count: 20))
                print("📡 [AI RESPONSE] STATUS: \(httpResponse.statusCode)")
                print("📥 [AI RESPONSE FULL JSON]:\n\(rawBody)")
                print(String(repeating: "📥", count: 20) + "\n")
                
                if httpResponse.statusCode == 401 {
                    print("🚫 [AI UNAUTHORIZED] Clearing token...")
                    DispatchQueue.main.async { self.token = nil }
                }
                
                if httpResponse.statusCode != 200 {
                    throw NSError(domain: "Server Error \(httpResponse.statusCode): \(rawBody)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: RailwayAIResponse.self, decoder: JSONDecoder())
            .handleEvents(receiveOutput: { response in
                // Log detailed resolutions
                if let resolutions = response.resolutions, !resolutions.isEmpty {
                    print("🌐 [AI AUDIT] Ricevute \(resolutions.count) risoluzioni:")
                    for res in resolutions {
                        print("   🔹 Treno ID \(res.train_id): Shift=\(res.time_adjustment_min)m, Binario=\(res.track_assignment ?? -1)")
                    }
                } else {
                    print("🌐 [AI AUDIT] Nessuna risoluzione suggerita (orario già ottimale o nessun conflitto risolvibile).")
                }
                print(String(repeating: "💠", count: 40) + "\n")
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("⚠️ [AI FINISHED] Request failed: \(error.localizedDescription)")
                } else {
                    print("✅ [AI FINISHED] Success!")
                }
                print(String(repeating: "🌐", count: 40) + "\n")
            })
            .eraseToAnyPublisher()
    }
    
    // PIGNOLO PROTOCOL: Unified analysis for lines (created or in-progress)
    func analyzeRoute(name: String, stationIds: [String], nodes: [RailwayNode], edges: [RailwayEdge]) async throws -> RouteAnalysis {
        // 1. Resolve Station Names for the Prompt
        let stopNames = stationIds.compactMap { sid in
            nodes.first(where: { $0.id == sid })?.name
        }.joined(separator: ", ")
        
        print("🧠 [AI DEBUG] analyzeRoute: stationsCount=\(stationIds.count), resolvedNames='\(stopNames)'")
        
        // Validation: If stops are empty, AI will hallucinate based on the whole network.
        // Fallback: If we have at least 2 stationIds but names are empty, the IDs might be mismatched.
        if stopNames.isEmpty && stationIds.count >= 2 {
            print("⚠️ [AI WARNING] Station IDs provided but names resolved to empty string. Checking ID mismatch...")
            for sid in stationIds.prefix(5) {
                print("   - ID Search: '\(sid)' exists in network? \(nodes.contains(where: { $0.id == sid }))")
            }
        }
        
        let prompt = """
        Analyze the railway route: "\(name)"
        Stops: \(stopNames.isEmpty ? "None specified (analyze the provided network)" : stopNames)
        
        CONTEXT: 
        - All distances in the provided 'tracks' data are in KILOMETERS (km).
        - All speeds are in KM/H.
        - The network layout is schematic but distances are real.
        
        Please provide:
        1. Maximum frequency (e.g., "Every 15 min")
        2. Recommended frequency (e.g., "Every 30 min")
        3. Optimal offset in minutes between departure from origin and departure from destination (to balance the fleet and minimize wait times).
        
        Respond ONLY with a JSON object using EXACTLY these keys in snake_case:
        {
          "max_frequency": "string",
          "recommended_frequency": "string",
          "optimal_offset_ab": int
        }
        Do not include any other keys or text.
        """
        
        // PIGNOLO PROTOCOL: We must map the network to the AI's expected format (Integer IDs, etc.)
        // We filter the tracks to only include those relevant to the route if possible.
        // If we have a sequence, we find the edges.
        var relevantEdgeIds = Set<UUID>()
        if stationIds.count >= 2 {
            for i in 0..<(stationIds.count - 1) {
                let from = stationIds[i]
                let to = stationIds[i+1]
                if let pathEdges = NetworkModel.findPathEdges(from: from, to: to, nodes: nodes, edges: edges) {
                    for e in pathEdges { relevantEdgeIds.insert(e.id) }
                }
            }
        }
        
        let aiRequest = self.createRequest(nodes: nodes, edges: edges, trains: [], fixedTrainIds: [], activeAgentIds: nil, temporalObstacles: nil, conflicts: [])
        
        // Filter tracks if we identified relevant ones, otherwise send all (less ideal)
        let filteredTracks: [RailwayAITrackInfo]
        if !relevantEdgeIds.isEmpty {
            // We need to map our UUIDs back to the AI Track IDs we just created in createRequest
            let relevantAiTrackIds = Set(relevantEdgeIds.compactMap { trackMapping[$0.uuidString] })
            filteredTracks = aiRequest.tracks.filter { relevantAiTrackIds.contains($0.id) }
            print("🧠 [AI DEBUG] Filtering tracks: origin=\(aiRequest.tracks.count) -> filtered=\(filteredTracks.count)")
        } else {
            filteredTracks = aiRequest.tracks
            print("⚠️ [AI WARNING] No relevant tracks found for path. Sending full network (\(filteredTracks.count) tracks).")
        }

        let responseString: String = try await withCheckedThrowingContinuation { continuation in
            let analysisURL = baseURL.appendingPathComponent("analyze_line").absoluteString
            
            // We use a specialized payload for analysis that includes the prompt and the mapped network data
            struct AnalysisPayload: Codable {
                let prompt: String
                let stations: [RailwayAIStationInfo]
                let tracks: [RailwayAITrackInfo]
                let line_name: String
                let temporal_obstacles: [TemporalObstacle]
                let current_time_minutes: Int
            }
            
            let payload = AnalysisPayload(
                prompt: prompt,
                stations: aiRequest.stations,
                tracks: filteredTracks,
                line_name: name,
                temporal_obstacles: aiRequest.temporal_obstacles ?? [],
                current_time_minutes: self.getMinutesFromMidnight(for: Date())
            )
            
            // PIGNOLO PROTOCOL: Debug Logging for Units
            if let firstTrack = payload.tracks.first {
                print("🧠 [AI DEBUG] Outbound Units: tracksCount=\(payload.tracks.count), firstLength=\(firstTrack.length_km)")
            }
            
            guard let jsonData = try? JSONEncoder().encode(payload) else {
                continuation.resume(throwing: NSError(domain: "Serializzazione fallita", code: 0))
                return
            }
            
            // Print full payload for deep debugging if needed
            let payloadStr = String(data: jsonData, encoding: .utf8) ?? ""
            if payloadStr.count < 1000 {
                print("🧠 [AI DEBUG] Full Payload: \(payloadStr)")
            } else {
                print("🧠 [AI DEBUG] Payload (truncated): \(payloadStr.prefix(500))...")
            }
            
            var request = URLRequest(url: URL(string: analysisURL)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            authManager.attachAuthHeaders(to: &request)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                    continuation.resume(throwing: NSError(domain: "Nessuna risposta dal server", code: 0))
                    return
                }
                
                // The generic sendToRailwayAI logic expected a Result<String, Error>
                // Here we handle the response directly to avoid double-encoding issues
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    continuation.resume(throwing: NSError(domain: "Errore Server (\(httpResponse.statusCode)): \(responseString)", code: httpResponse.statusCode))
                    return
                }
                
                continuation.resume(returning: responseString)
            }.resume()
        }

        // Extract JSON from potential markdown blocks or conversational filler
        print("🧠 [AI DEBUG] Raw Response: \(responseString)")
        
        var cleanJson = responseString
        
        // Remove markdown blocks if present
        if cleanJson.contains("```") {
            let lines = cleanJson.components(separatedBy: .newlines)
            var inJson = false
            var extracted = ""
            for line in lines {
                if line.hasPrefix("```") {
                    inJson = !inJson
                    continue
                }
                if inJson {
                    extracted += line + "\n"
                }
            }
            if !extracted.isEmpty {
                cleanJson = extracted
            } else {
                // FALLBACK: Just remove the markers
                cleanJson = cleanJson.replacingOccurrences(of: "```json", with: "")
                                     .replacingOccurrences(of: "```", with: "")
            }
        }
        
        // Final trim
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it starts with some text before the first '{', try to find the '{'
        if let firstBrace = cleanJson.firstIndex(of: "{"), let lastBrace = cleanJson.lastIndex(of: "}") {
            cleanJson = String(cleanJson[firstBrace...lastBrace])
        }
        
        print("🧠 [AI DEBUG] Cleaned JSON: \(cleanJson)")
        
        if let data = cleanJson.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                // PIGNOLO PROTOCOL: If the AI uses camelCase despite instructions, try to handle it.
                // Note: The CodingKeys in the struct usually take precedence.
                return try decoder.decode(RouteAnalysis.self, from: data)
            } catch {
                print("❌ [AI DECODE ERROR] \(error)")
                throw error
            }
        } else {
            throw NSError(domain: "Invalid JSON response (Empty)", code: 0)
        }
    }
    
    // Helper to bridge async/await with the existing logic if needed, but here we just implemented it inline for clarity
    func performAnalysisRequest(url: String, payload: Data) async throws -> String {
        // Implementation similar to above...
        return ""
    }
    
    func optimize(jsonString: String) -> AnyPublisher<RailwayAIResponse, Error> {
        let finalURL = baseURL.appendingPathComponent("optimize_scheduled")
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        authManager.attachAuthHeaders(to: &urlRequest)
        
        urlRequest.httpBody = jsonString.data(using: .utf8)
        self.lastRequestJSON = jsonString
        
        let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
        try? jsonString.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(120, scheduler: DispatchQueue.main)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let rawBody = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                
                print("\n" + String(repeating: "⚡️", count: 40))
                print("📡 [AI RAW REQUEST] TO: \(finalURL.absoluteString)")
                print("HTTP STATUS: \(httpResponse.statusCode)")
                print("RAW RESPONSE BODY:")
                print(rawBody)
                print(String(repeating: "⚡️", count: 40) + "\n")
                
                if httpResponse.statusCode == 401 {
                    DispatchQueue.main.async { self.token = nil }
                }
                
                if httpResponse.statusCode != 200 {
                    print("❌ [AI RAW ERROR] \(httpResponse.statusCode) at \(finalURL.absoluteString): \(rawBody)")
                    throw NSError(domain: "Server Error \(httpResponse.statusCode): \(rawBody)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: RailwayAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func optimizeWithScenario(scenarioPath: String) -> AnyPublisher<RailwayAIResponse, Error> {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("optimize"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180.0 // PIGNOLO PROTOCOL: Augmented timeout for complex scenarios
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        authManager.attachAuthHeaders(to: &urlRequest)
        
        let request = OptimizeRequestWithScenario(scenario_path: scenarioPath)
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode == 404 {
                    throw NSError(domain: "Scenario non trovato", code: 404)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Ottimizzazione (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: RailwayAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    

}
