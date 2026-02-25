import Foundation
import Combine

@MainActor
class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
    struct LineAnalysis: Codable {
        let maxFrequency: String?
        let recommendedFrequency: String?
        let optimalOffsetAB: Int? // In minutes
        
        // Extended fields from the AI V2 Analysis engine
        let travelTimeMin: Double?
        let crossingPointsCount: Int?
        let minHeadwayMin: Double?
        let optimalHeadwayMin: Double?
        let optimalOffsetMin: Double?
        let recommendation: String?
        
        enum CodingKeys: String, CodingKey {
            case maxFrequency = "max_frequency"
            case recommendedFrequency = "recommended_frequency"
            case optimalOffsetAB = "optimal_offset_ab"
            case travelTimeMin = "travel_time_min"
            case crossingPointsCount = "crossing_points_count"
            case minHeadwayMin = "min_headway_min"
            case optimalHeadwayMin = "optimal_headway_min"
            case optimalOffsetMin = "optimal_offset_min"
            case recommendation
        }
    }
    
    var baseURL = URL(string: "https://railway-ai.michelebigi.it/api/v1")!
    var token: String? = nil
    var apiKey: String? = nil
    
    private var stationMapping: [String: Int] = [:]
    private var trackMapping: [String: Int] = [:]
    private var trainMapping: [UUID: Int] = [:]
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case unauthorized
        case error(String)
    }
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    @Published var lastRequestJSON: String = "" // Per ispezione da iPad
    
    func syncCredentials(endpoint: String, apiKey: String, token: String? = nil) {
        var cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Robust Endpoint Sanitization: ensure /api/v1 is present
        if !cleanEndpoint.isEmpty {
            if !cleanEndpoint.contains("/api/v1") && !cleanEndpoint.contains("/token") {
                if cleanEndpoint.hasSuffix("/") {
                    cleanEndpoint += "api/v1"
                } else {
                    cleanEndpoint += "/api/v1"
                }
            }
        }
        
        if let url = URL(string: cleanEndpoint), !cleanEndpoint.isEmpty {
            self.baseURL = url
            // Update AuthManager with the base server URL (stripping /api/v1 if present)
            var baseServer = cleanEndpoint.replacingOccurrences(of: "/api/v1", with: "")
            if baseServer.hasSuffix("/") { baseServer.removeLast() }
            AuthenticationManager.shared.updateBaseURL(baseServer)
        }
        
        // Use API Key exactly as provided - only trim whitespace
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = cleanKey.isEmpty ? nil : cleanKey
        
        // If a new token is provided, use it (temporary session). 
        // Otherwise, if we are syncing without a token, ensure it's cleared.
        if let t = token, !t.isEmpty {
            self.token = t
        } else if token == nil {
            // Only clear if explicitly nil (not just omitted if we had a default which we don't here as it's an override)
            // Wait, the signature is token: String? = nil.
            // If called as syncCredentials(..., token: nil), we clear.
            self.token = nil
        }
        
        // Update AuthManager as well
        if let key = self.apiKey { AuthenticationManager.shared.setAPIKey(key) }
        if let t = self.token { AuthenticationManager.shared.setToken(t) } else { AuthenticationManager.shared.setToken("") }
        
        RailwayAILogger.shared.log("Sync Complete. Endpoint: \(self.baseURL)", type: .info)
        RailwayAILogger.shared.log("API Key: \(self.apiKey != nil ? "Presente" : "Assente"), Token: \(self.token != nil ? "Presente" : "Assente")", type: .info)
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
    }
    struct APIKeyResponse: Codable {
        let api_key: String
    }
    
    func login(username: String, password: String) -> AnyPublisher<String, Error> {
        // PIGNOLO PROTOCOL: With the new domain structure, the token endpoint is likely under /api/v1/token
        // We removed the aggressive logic that stripped /api/v1.
        let loginURL = baseURL.appendingPathComponent("token")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let allowed = CharacterSet.urlQueryAllowed
        func encode(_ s: String) -> String {
            return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
        }
        
        let bodyString = "username=\(encode(username))&password=\(encode(password))&grant_type=password"
        request.httpBody = bodyString.data(using: .utf8)
        
        RailwayAILogger.shared.log("Login Request -> \(loginURL.absoluteString)", type: .info)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let body = String(data: output.data, encoding: .utf8) ?? ""
                RailwayAILogger.shared.log("Login Response (\(httpResponse.statusCode)): \(body.prefix(100))", type: httpResponse.statusCode == 200 ? .success : .error)
                
                if httpResponse.statusCode != 200 {
                    if httpResponse.statusCode == 403 && body.contains("inactive") {
                        throw NSError(domain: "Account inattivo.", code: 403)
                    }
                    throw NSError(domain: "Codice \(httpResponse.statusCode): \(body)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .map { response in
                self.token = response.access_token
                RailwayAILogger.shared.log("Token JWT ottenuto.", type: .success)
                return response.access_token
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func verifyConnection() {
        // PIGNOLO PROTOCOL: Pre-sync check
        if baseURL.absoluteString.isEmpty || (token == nil && apiKey == nil) {
            self.connectionStatus = .disconnected
            return
        }
        
        self.connectionStatus = .connecting
        let endpoints = ["health", ""] // The server has /api/v1/health
        performCheck(at: endpoints)
    }

    private func performCheck(at endpoints: [String]) {
        guard !endpoints.isEmpty else { return }
        var currentEndpoints = endpoints
        let endpoint = currentEndpoints.removeFirst()
        
        var request = URLRequest(url: endpoint.isEmpty ? baseURL.deletingLastPathComponent() : baseURL.appendingPathComponent(endpoint))
        request.httpMethod = "GET"
        request.timeoutInterval = 7.0
        
        // Use central AuthManager to ensure Header Unico
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode < 500 {
                        self.connectionStatus = .connected
                        return
                    }
                }
                
                // If failed and more endpoints to try
                if !currentEndpoints.isEmpty {
                    self.performCheck(at: currentEndpoints)
                } else {
                    let errStr = error?.localizedDescription ?? "Server non raggiungibile"
                    self.connectionStatus = .error(errStr)
                    RailwayAILogger.shared.log("Health Check Error: \(errStr)", type: .error)
                }
            }
        }.resume()
    }
    
    func generateApiKey() -> AnyPublisher<String, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Nessun token attivo. Effettua il login prima.", code: 401)).eraseToAnyPublisher()
        }
        
        // PIGNOLO PROTOCOL: API Key generation
        let requestURL = baseURL.appendingPathComponent("generate-key")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("[Auth] Generating Permanent API Key at \(requestURL.absoluteString)...")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .timeout(.seconds(30), scheduler: DispatchQueue.main)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Generazione Key (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .tryMap { data in
                // Robust parsing: Try object, then try string
                if let keyObj = try? JSONDecoder().decode(APIKeyResponse.self, from: data) {
                    return keyObj.api_key
                } else if let rawString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !rawString.isEmpty {
                    if rawString.hasPrefix("\"") && rawString.hasSuffix("\"") {
                        return String(rawString.dropFirst().dropLast())
                    }
                    return rawString
                }
                throw NSError(domain: "Impossibile decodificare API Key dal server", code: 0)
            }
            .map { key in
                var finalKey = key
                if !finalKey.hasPrefix("rw-") && finalKey.count > 5 {
                    finalKey = "rw-\(key)"
                }
                self.apiKey = finalKey
                return finalKey
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
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
        AuthenticationManager.shared.attachAuthHeaders(to: &urlRequest)
        
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
    func analyzeLine(name: String, stationIds: [String], nodes: [RailwayNode], edges: [RailwayEdge]) async throws -> LineAnalysis {
        // 1. Resolve Station Names for the Prompt
        let stopNames = stationIds.compactMap { sid in
            nodes.first(where: { $0.id == sid })?.name
        }.joined(separator: ", ")
        
        print("🧠 [AI DEBUG] analyzeLine: stationsCount=\(stationIds.count), resolvedNames='\(stopNames)'")
        
        // Validation: If stops are empty, AI will hallucinate based on the whole network.
        // Fallback: If we have at least 2 stationIds but names are empty, the IDs might be mismatched.
        if stopNames.isEmpty && stationIds.count >= 2 {
            print("⚠️ [AI WARNING] Station IDs provided but names resolved to empty string. Checking ID mismatch...")
            for sid in stationIds.prefix(5) {
                print("   - ID Search: '\(sid)' exists in network? \(nodes.contains(where: { $0.id == sid }))")
            }
        }
        
        let prompt = """
        Analyze the railway line: "\(name)"
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
        // We filter the tracks to only include those relevant to the line if possible.
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
            AuthenticationManager.shared.attachAuthHeaders(to: &request)
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
                return try decoder.decode(LineAnalysis.self, from: data)
            } catch {
                print("❌ [AI DECODE ERROR] \(error)")
                throw error
            }
        } else {
            throw NSError(domain: "Invalid JSON response (Empty)", code: 0)
        }
    }
    
    // Helper to bridge async/await with the existing logic if needed, but here we just implemented it inline for clarity
    private func performAnalysisRequest(url: String, payload: Data) async throws -> String {
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
        
        AuthenticationManager.shared.attachAuthHeaders(to: &urlRequest)
        
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
        
        AuthenticationManager.shared.attachAuthHeaders(to: &urlRequest)
        
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
    
    // MARK: - Admin Panel Endpoints
    
    func listUsers() -> AnyPublisher<[AdminUser], Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede JWT admin. Effettua il login.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("admin/users"))
        request.httpMethod = "GET"
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Lista Utenti (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: [AdminUser].self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func addUser(username: String, password: String) -> AnyPublisher<Void, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede JWT admin.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("admin/users"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        let body = AddUserRequest(username: username, password: password)
        do {
            request.httpBody = try JSONEncoder().encode(body)
            if let json = String(data: request.httpBody!, encoding: .utf8) {
                print("[Admin] Add User Request: \(json)")
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        print("[Admin] Sending request to: \(request.url?.absoluteString ?? "UNKNOWN")")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let body = String(data: output.data, encoding: .utf8) ?? ""
                print("[Admin] Response Code: \(httpResponse.statusCode)")
                print("[Admin] Response Body: \(body)")
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    throw NSError(domain: "Errore Aggiunta Utente (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return ()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func removeUser(username: String) -> AnyPublisher<Void, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede JWT admin.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("admin/users").appendingPathComponent(username))
        request.httpMethod = "DELETE"
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Rimozione Utente (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return ()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Training & Scenari Flow
    
    func generateScenario(area: String) -> AnyPublisher<Void, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede login.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("scenario/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        let body = ScenarioGenerateRequest(area: area)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 202 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Generazione Scenario (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return ()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func train(scenarioPath: String) -> AnyPublisher<Void, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede login.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("train"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        AuthenticationManager.shared.attachAuthHeaders(to: &request)
        
        let body = TrainRequest(scenario_path: scenarioPath)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 202 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    throw NSError(domain: "Errore Avvio Training (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return ()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - WebSocket Monitoring
    
    private var webSocket: URLSessionWebSocketTask?
    @Published var wsMessages: [WSMessage] = []
    @Published var isWsConnected = false
    
    func connectMonitoring() {
        let wsURLString = baseURL.absoluteString
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "/api/v1", with: "") + "/ws/monitoring"
        
        guard let url = URL(string: wsURLString) else { return }
        
        print("[WS] Connecting to: \(url)")
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        isWsConnected = true
        receiveWSMessage()
    }
    
    func disconnectMonitoring() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isWsConnected = false
    }
    
    private func receiveWSMessage() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        do {
                            let wsMessage = try JSONDecoder().decode(WSMessage.self, from: data)
                            DispatchQueue.main.async {
                                self?.wsMessages.append(wsMessage)
                                // Keep only last 100 messages for performance
                                if (self?.wsMessages.count ?? 0) > 100 {
                                    self?.wsMessages.removeFirst()
                                }
                            }
                        } catch {
                            print("[WS] Error decoding: \(error)")
                        }
                    }
                default: break
                }
                self?.receiveWSMessage()
            case .failure(let error):
                print("[WS] Error: \(error)")
                self?.isWsConnected = false
            }
        }
    }
    
    private func getMinutesFromMidnight(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    /// Helper to convert current app state to RailwayAIRequest
    func createRequest(nodes: [RailwayNode], edges: [RailwayEdge], trains: [RailwayTrain], fixedTrainIds: Set<UUID> = [], activeAgentIds: Set<UUID>? = nil, temporalObstacles: [TemporalObstacle]? = nil, conflicts: [ScheduleConflict]) -> RailwayAIRequest {
        let aiStations = mapAIStations(nodes: nodes)
        let uniqueTracks = mapAIUniqueTracks(edges: edges)
        
        let focusTrains = (activeAgentIds == nil) ? trains : trains.filter { activeAgentIds!.contains($0.id) }
        let bgTrains = (activeAgentIds == nil) ? [] : trains.filter { !activeAgentIds!.contains($0.id) }
        
        let mergedObstacles = processTemporalObstacles(focusTrains: focusTrains, bgTrains: bgTrains, edges: edges, initialObstacles: temporalObstacles ?? [])
        let aiTrains = mapAITrains(focusTrains: focusTrains, nodes: nodes, edges: edges, fixedTrainIds: fixedTrainIds, conflicts: conflicts)
        
        let activeNumericIds: [Int]? = activeAgentIds?.compactMap { trainMapping[$0] }
        
        let finalRequest = RailwayAIRequest(
            trains: aiTrains,
            tracks: uniqueTracks,
            stations: aiStations,
            max_iterations: 1000,
            ga_max_iterations: nil,
            ga_population_size: nil,
            active_agent_ids: activeNumericIds,
            temporal_obstacles: mergedObstacles,
            current_time_minutes: self.getMinutesFromMidnight(for: Date())
        )
        
        self.lastRequestJSON = (try? String(data: JSONEncoder().encode(finalRequest), encoding: .utf8)) ?? ""
        return finalRequest
    }

    private func mapAIStations(nodes: [Node]) -> [RailwayAIStationInfo] {
        let sortedNodes = nodes.sorted(by: { $0.id < $1.id })
        return sortedNodes.enumerated().map { index, node in
            stationMapping[node.id] = index
            let platforms = node.platforms ?? (node.type == .interchange ? 4 : 2)
            return RailwayAIStationInfo(id: index, name: node.name, num_platforms: platforms)
        }
    }

    private func mapAIUniqueTracks(edges: [Edge]) -> [RailwayAITrackInfo] {
        var uniqueTracks: [RailwayAITrackInfo] = []
        var segmentToTrackId: [String: Int] = [:] 
        
        for edge in edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map{String($0)}.joined(separator: "-")
            
            if let trackId = segmentToTrackId[key] {
                trackMapping[edge.id.uuidString] = trackId
            } else {
                let trackId = uniqueTracks.count
                segmentToTrackId[key] = trackId
                trackMapping[edge.id.uuidString] = trackId
                uniqueTracks.append(createAITrackInfo(id: trackId, s1: s1, s2: s2, edge: edge))
            }
        }
        return uniqueTracks
    }

    private func createAITrackInfo(id: Int, s1: Int, s2: Int, edge: Edge) -> RailwayAITrackInfo {
        let isSingle = edge.trackType == .single || edge.trackType == .regional
        return RailwayAITrackInfo(
            id: id,
            station_ids: [s1, s2],
            length_km: edge.distance,
            is_single_track: isSingle,
            capacity: isSingle ? 1 : 2,
            max_speed_kmh: edge.maxSpeed
        )
    }

    private func processTemporalObstacles(focusTrains: [Train], bgTrains: [Train], edges: [Edge], initialObstacles: [TemporalObstacle]) -> [TemporalObstacle] {
        var rawObstacles = initialObstacles
        let focusTrackIds = identifyFocusTrackIds(focusTrains: focusTrains, edges: edges)
        
        for bgTrain in bgTrains {
            rawObstacles.append(contentsOf: createObstaclesForTrain(bgTrain, edges: edges, focusTrackIds: focusTrackIds))
        }
        
        return mergeObstacles(rawObstacles)
    }

    private func identifyFocusTrackIds(focusTrains: [Train], edges: [Edge]) -> Set<Int> {
        var ids = Set<Int>()
        for ft in focusTrains {
            guard ft.stops.count >= 2 else { continue }
            for i in 0..<(ft.stops.count - 1) {
                let s1 = ft.stops[i].stationId
                let s2 = ft.stops[i+1].stationId
                if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
                   let tId = trackMapping[edge.id.uuidString] {
                    ids.insert(tId)
                }
            }
        }
        return ids
    }

    private func createObstaclesForTrain(_ train: Train, edges: [Edge], focusTrackIds: Set<Int>) -> [TemporalObstacle] {
        var obstacles: [TemporalObstacle] = []
        guard train.stops.count >= 2 else { return [] }
        
        for i in 0..<(train.stops.count - 1) {
            let s1 = train.stops[i].stationId
            let s2 = train.stops[i+1].stationId
            guard let dep = train.stops[i].departure, let arr = train.stops[i+1].arrival else { continue }
            
            if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
               let tId = trackMapping[edge.id.uuidString], focusTrackIds.contains(tId) {
                obstacles.append(contentsOf: buildObstacle(trackId: tId, dep: dep, arr: arr, trainName: train.name))
            }
        }
        return obstacles
    }

    private func buildObstacle(trackId: Int, dep: Date, arr: Date, trainName: String) -> [TemporalObstacle] {
        let startMin = getMinutesFromMidnight(for: dep)
        let endMin = getMinutesFromMidnight(for: arr)
        if startMin <= endMin {
            return [TemporalObstacle(track_id: trackId, start_minute: startMin, end_minute: endMin, reason: "Traffico: \(trainName)")]
        } else {
            return [
                TemporalObstacle(track_id: trackId, start_minute: startMin, end_minute: 1440, reason: "Traffico: \(trainName) (Pre-Midnight)"),
                TemporalObstacle(track_id: trackId, start_minute: 0, end_minute: endMin, reason: "Traffico: \(trainName) (Post-Midnight)")
            ]
        }
    }

    private func mapAITrains(focusTrains: [Train], nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict]) -> [RailwayAITrainInfo] {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return focusTrains.enumerated().map { index, train in
            trainMapping[train.id] = index
            return createAITrainInfo(index: index, train: train, nodes: nodes, edges: edges, fixedTrainIds: fixedTrainIds, conflicts: conflicts, formatter: timeFormatter)
        }
    }

    private func createAITrainInfo(index: Int, train: Train, nodes: [Node], edges: [Edge], fixedTrainIds: Set<UUID>, conflicts: [ScheduleConflict], formatter: DateFormatter) -> RailwayAITrainInfo {
        let routeIds = calculateRouteIds(for: train, edges: edges)
        let depTime = normalizeDate(train.departureTime)
        let actualVelocity = calculateVelocity(for: train, nodes: nodes, edges: edges)
        
        let isFixed = fixedTrainIds.contains(train.id)
        let isDelayed = isFixed ? false : conflicts.contains(where: { $0.trainAId == train.id || $0.trainBId == train.id })
        let avgDwell = train.stops.isEmpty ? 2 : Double(train.stops.reduce(0) { $0 + $1.minDwellTime }) / Double(train.stops.count)
        
        return RailwayAITrainInfo(
            id: index,
            priority: train.priority,
            position_km: 0.0,
            velocity_kmh: actualVelocity,
            current_track: routeIds.first ?? 0,
            destination_station: stationMapping[train.stops.last?.stationId ?? ""] ?? 0,
            delay_minutes: 0,
            is_delayed: isDelayed,
            origin_station: stationMapping[train.stops.first?.stationId ?? ""] ?? 0,
            scheduled_departure_time: formatter.string(from: depTime),
            planned_route: routeIds,
            min_dwell_minutes: Int(round(avgDwell))
        )
    }

    private func calculateRouteIds(for train: Train, edges: [Edge]) -> [Int] {
        var routeIds: [Int] = []
        guard train.stops.count >= 2 else { return [] }
        for i in 0..<(train.stops.count - 1) {
            let s1 = train.stops[i].stationId
            let s2 = train.stops[i+1].stationId
            if let edge = edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }),
               let tId = trackMapping[edge.id.uuidString] {
                routeIds.append(tId)
            }
        }
        return routeIds
    }

    private func calculateVelocity(for train: Train, nodes: [Node], edges: [Edge]) -> Double {
        guard let firstDep = train.stops.first?.departure, let lastArr = train.stops.last?.arrival else {
            return Double(train.maxSpeed) * 0.9
        }
        
        let totalTripSeconds = lastArr.timeIntervalSince(firstDep)
        let totalDwellSeconds = train.stops.reduce(0.0) { $0 + Double($1.minDwellTime * 60) }
        let movingSeconds = totalTripSeconds - totalDwellSeconds
        
        var totalDist = 0.0
        if train.stops.count >= 2 {
            for i in 0..<(train.stops.count - 1) {
                if let path = NetworkModel.findPathEdges(from: train.stops[i].stationId, to: train.stops[i+1].stationId, nodes: nodes, edges: edges) {
                    totalDist += path.reduce(0.0) { $0 + $1.distance }
                }
            }
        }
        
        if movingSeconds > 30 && totalDist > 0 {
            return min(totalDist / (movingSeconds / 3600.0), Double(train.maxSpeed))
        }
        return Double(train.maxSpeed) * 0.9
    }

    private func normalizeDate(_ date: Date?) -> Date {
        let calendar = Calendar.current
        let d = date ?? Date()
        let components = calendar.dateComponents([.hour, .minute, .second], from: d)
        let dateAt2000 = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? d
        return Date(timeIntervalSinceReferenceDate: floor(dateAt2000.timeIntervalSinceReferenceDate + 0.5))
    }
    
    private func saveRequestToFile(_ request: RailwayAIRequest) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(formatter)
            
            let data = try encoder.encode(request)
            let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
            try data.write(to: URL(fileURLWithPath: path))
            print("[PIGNOLO] Request salvata in: \(path)")
        } catch {
            print("[PIGNOLO] Errore salvataggio file: \(error)")
        }
    }
    
    /// Translates integer results back to original UUIDs
    func getTrainUUID(optimizerId: Int) -> UUID? {
        return trainMapping.first(where: { $0.value == optimizerId })?.key
    }
    
    private func mergeObstacles(_ obstacles: [TemporalObstacle]) -> [TemporalObstacle] {
        var byTrack: [Int: [TemporalObstacle]] = [:]
        for o in obstacles { byTrack[o.track_id, default: []].append(o) }
        
        var result: [TemporalObstacle] = []
        for (trackId, group) in byTrack {
            let sorted = group.sorted { $0.start_minute < $1.start_minute }
            if sorted.isEmpty { continue }
            
            var current = sorted[0]
            for i in 1..<sorted.count {
                let next = sorted[i]
                if next.start_minute <= current.end_minute {
                    current = TemporalObstacle(
                        track_id: trackId,
                        start_minute: current.start_minute,
                        end_minute: max(current.end_minute, next.end_minute),
                        reason: "Merged Traffic"
                    )
                } else {
                    result.append(current)
                    current = next
                }
            }
            result.append(current)
        }
        return result
    }
    
    func getTrainMapping() -> [UUID: Int] {
        return trainMapping
    }
}
