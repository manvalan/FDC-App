import Foundation
import Combine

class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
    var baseURL = URL(string: "http://82.165.138.64:8080/api/v1")!
    var token: String? = nil
    var apiKey: String? = nil
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case unauthorized
        case error(String)
    }
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    /// PIGNOLO PROTOCOL: Synchronizes credentials from AppState
    func syncCredentials(endpoint: String, apiKey: String, token: String? = nil) {
        var cleanEndpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Robust Endpoint Sanitization: ensure /api/v1 is present
        if !cleanEndpoint.isEmpty {
            if !cleanEndpoint.contains("/api/v1") {
                if cleanEndpoint.hasSuffix("/") {
                    cleanEndpoint += "api/v1"
                } else {
                    cleanEndpoint += "/api/v1"
                }
            }
        }
        
        if let url = URL(string: cleanEndpoint), !cleanEndpoint.isEmpty {
            self.baseURL = url
        }
        
        // Use API Key exactly as provided - only trim whitespace
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = cleanKey.isEmpty ? nil : cleanKey
        
        if let t = token {
            self.token = t
        }
        
        print("[Auth] Sync Complete. Endpoint: \(self.baseURL)")
        print("[Auth] API Key: \(self.apiKey != nil ? "(Presente)" : "(Assente)"), Token: \(self.token != nil ? "Presente" : "Assente")")
    }
    
    struct TokenResponse: Codable {
        let access_token: String
        let token_type: String
    }
    
    struct APIKeyResponse: Codable {
        let api_key: String
    }
    
    func login(username: String, password: String) -> AnyPublisher<String, Error> {
        // PIGNOLO PROTOCOL: /token is at the root of the API server.
        // We assume baseURL is like http://host:port/api/v1
        // We attempt to find the root by stripping "api/v1" if present, otherwise we go up twice.
        var loginURL = baseURL
        let urlString = loginURL.absoluteString
        if urlString.contains("/api/v1") {
            if let root = URL(string: urlString.replacingOccurrences(of: "/api/v1", with: "")) {
                loginURL = root
            }
        } else {
            loginURL = loginURL.deletingLastPathComponent()
            if loginURL.pathComponents.contains("api") {
                loginURL = loginURL.deletingLastPathComponent()
            }
        }
        
        if !loginURL.absoluteString.hasSuffix("/") {
            loginURL = loginURL.appendingPathComponent("")
        }
        loginURL = loginURL.appendingPathComponent("token")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let allowed = CharacterSet.urlQueryAllowed
        func encode(_ s: String) -> String {
            return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
        }
        
        let bodyString = "username=\(encode(username))&password=\(encode(password))&grant_type=password"
        request.httpBody = bodyString.data(using: .utf8)
        
        print("[Auth] Requesting Token from: \(loginURL)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? ""
                    if httpResponse.statusCode == 403 && body.contains("inactive") {
                        throw NSError(domain: "Account inattivo. Contatta l'amministratore per l'attivazione.", code: 403)
                    }
                    throw NSError(domain: "Errore Login (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .map { response in
                self.token = response.access_token
                return response.access_token
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func verifyConnection() {
        guard token != nil || apiKey != nil else {
            self.connectionStatus = .disconnected
            return
        }
        
        self.connectionStatus = .connecting
        
        // Use a more generic endpoint for connection health check
        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        if let t = token {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        } else if let key = apiKey {
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            request.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    print("[Auth] Health Check Status: \(httpResponse.statusCode)")
                    // 200, 403, 404, 405 are all "server alive and auth potentially accepted"
                    // 401 is specifically "not authorized"
                    if httpResponse.statusCode == 401 {
                        self.connectionStatus = .unauthorized
                    } else if httpResponse.statusCode >= 200 && httpResponse.statusCode < 500 {
                        self.connectionStatus = .connected
                    } else {
                        self.connectionStatus = .error("Status: \(httpResponse.statusCode)")
                    }
                } else {
                    let errStr = error?.localizedDescription ?? "Server non raggiungibile"
                    self.connectionStatus = .error(errStr)
                    print("[Auth] Health Check Error: \(errStr)")
                }
            }
        }.resume()
    }
    
    func generateApiKey() -> AnyPublisher<String, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Nessun token attivo. Effettua il login prima.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("generate-key"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("[Auth] Generating Permanent API Key...")
        
        return URLSession.shared.dataTaskPublisher(for: request)
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
            .decode(type: APIKeyResponse.self, decoder: JSONDecoder())
            .map { response in
                self.apiKey = response.api_key
                return response.api_key
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func optimize(request: RailwayAIRequest, useV2: Bool = false) -> AnyPublisher<RailwayAIResponse, Error> {
        let endpoint = useV2 ? "v2/optimize" : "optimize"
        // Ensure we don't double path components if baseURL already has v1
        var finalURL = baseURL.deletingLastPathComponent().appendingPathComponent(endpoint)
        if !baseURL.absoluteString.contains("/api/") {
             finalURL = baseURL.appendingPathComponent(endpoint)
        }
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = self.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = self.apiKey {
            urlRequest.setValue(key.hasPrefix("rw-") ? key : "rw-\(key)", forHTTPHeaderField: "X-API-Key")
        }
        
        do {
            let encoder = JSONEncoder()
            // Date encoding strategy for FDC Style
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            encoder.dateEncodingStrategy = .formatted(formatter)
            
            urlRequest.httpBody = try encoder.encode(request)
            if let json = String(data: urlRequest.httpBody!, encoding: .utf8) {
                print("[AI] Optimization Request (\(endpoint)): \(json)")
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(120, scheduler: DispatchQueue.main)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                    print("[AI ERROR] \(httpResponse.statusCode): \(body)")
                    throw NSError(domain: "Server Error \(httpResponse.statusCode): \(body)", code: httpResponse.statusCode)
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
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = self.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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
    
    /// Helper to convert current app state to RailwayAIRequest
    func createRequest(network: RailwayNetwork, trains: [Train], conflicts: [ScheduleConflict]) -> RailwayAIRequest {
        let stations = network.nodes.map { $0.id }
        var availablePlatforms: [String: [Int]] = [:]
        for node in network.nodes {
            let p = node.platforms ?? (node.type == .interchange ? 2 : 1)
            availablePlatforms[node.id] = Array(1...p)
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let aiConflicts = conflicts.map { c in
            let trainA = trains.first(where: { $0.id == c.trainAId })
            let trainB = trains.first(where: { $0.id == c.trainBId })
            
            func mapTrain(_ t: Train?, arrival: Date?, departure: Date?) -> RailwayAITrainInfo {
                return RailwayAITrainInfo(
                    train_id: t?.id.uuidString ?? UUID().uuidString,
                    arrival: arrival.map { dateFormatter.string(from: $0) },
                    departure: departure.map { dateFormatter.string(from: $0) },
                    platform: nil,
                    current_speed_kmh: Double(t?.maxSpeed ?? 100),
                    priority: t?.priority ?? 5
                )
            }
            
            // Approximate arrival/departure for these trains at this location from the schedules
            // For simplicity, we use the conflict window
            let tInfoA = mapTrain(trainA, arrival: c.timeStart, departure: c.timeEnd)
            let tInfoB = mapTrain(trainB, arrival: c.timeStart, departure: c.timeEnd)
            
            return RailwayAIConflictInput(
                conflict_type: c.locationType == .station ? "platform_conflict" : "line_conflict",
                location: c.locationId.replacingOccurrences(of: "STATION::", with: "").replacingOccurrences(of: "LINE::", with: ""),
                trains: [tInfoA, tInfoB],
                severity: "high",
                time_overlap_seconds: Int(c.timeEnd.timeIntervalSince(c.timeStart))
            )
        }
        
        return RailwayAIRequest(
            conflicts: aiConflicts,
            network: networkInfo,
            preferences: nil
        )
    }
    
    // MARK: - Advanced Optimizer (Integer Schema)
    
    private var stationMapping: [String: Int] = [:]
    private var trackMapping: [UUID: Int] = [:]
    private var trainMapping: [UUID: Int] = [:]
    
    func advancedOptimize(network: RailwayNetwork, trains: [Train]) -> AnyPublisher<OptimizerResponse, Error> {
        let request = createAdvancedRequest(network: network, trains: trains)
        
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("optimize_scheduled"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180.0 // Extended timeout for deep GA optimization
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        if let apiKey = self.apiKey, !apiKey.isEmpty {
            // PIGNOLO PROTOCOL: API Keys should have the "rw-" prefix
            let finalKey = apiKey.hasPrefix("rw-") ? apiKey : "rw-\(apiKey)"
            
            // DUAL-HEADER STRATEGY: Send in both common headers for maximum compatibility
            urlRequest.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
            urlRequest.setValue("Bearer \(finalKey)", forHTTPHeaderField: "Authorization")
            
            print("[Auth] Using API Key (Safe Mode): \(finalKey.prefix(7))...")
        } else if let token = self.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("[Auth] Using JWT Token: \(token.prefix(10))...")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            urlRequest.httpBody = try encoder.encode(request)
            
            if let jsonString = String(data: urlRequest.httpBody!, encoding: .utf8) {
                print("--------------------------------------------------")
                print("[OPTIMIZER DEBUG] REQUEST JSON:")
                print(jsonString)
                print("--------------------------------------------------")
            }
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(180, scheduler: DispatchQueue.main)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                    print("[OPTIMIZER ERROR] Status: \(httpResponse.statusCode)")
                    print("[OPTIMIZER ERROR] Body: \(body)")
                    
                    let errorMsg = "Errore Server (\(httpResponse.statusCode)): \(body)"
                    throw NSError(domain: errorMsg, code: httpResponse.statusCode)
                }
                return output.data
            }
            .decode(type: OptimizerResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func createAdvancedRequest(network: RailwayNetwork, trains: [Train]) -> OptimizerRequest {
        stationMapping.removeAll()
        trackMapping.removeAll()
        trainMapping.removeAll()
        
        // 1. Map only REAL stations (non-junctions)
        let stations = network.nodes.filter { $0.type != .junction }
        let sortedStations = stations.sorted(by: { $0.id < $1.id })
        let optimizerStations = sortedStations.enumerated().map { index, node in
            stationMapping[node.id] = index
            let platforms = node.platforms ?? (node.type == Node.NodeType.interchange ? 2 : 1)
            return OptimizerStation(id: index, name: node.name, num_platforms: platforms)
        }
        
        print("[AI Mapping] Macro-Stations mapped: \(optimizerStations.count)")
        
        // 2. Identify and create Macro-Tracks (Legs between stations)
        var macroTracks: [Set<String>: (index: Int, distance: Double, speed: Int, capacity: Int)] = [:]
        var optimizerTracks: [OptimizerTrack] = []
        
        func getMacroTrack(from: String, to: String) -> Int? {
            let pair = Set([from, to])
            if let existing = macroTracks[pair] { return existing.index }
            
            // Find full path to calculate mathematically precise macro-metrics
            guard let path = network.findPathEdges(from: from, to: to) else { return nil }
            
            let totalDist = path.reduce(0.0) { $0 + $1.distance }
            
            // MATH SYNC: Calculate total hours to traverse all small segments at their respective speeds
            let totalHours = path.reduce(0.0) { acc, edge in
                let segSpeed = Double(edge.maxSpeed)
                return acc + (edge.distance / segSpeed)
            }
            
            // Derive Effective Speed so that (totalDist / effectiveSpeed) == sum(dist_i / speed_i)
            // This ensures the AI sees the EXACT same travel time as the App's detailed simulation.
            let effectiveSpeed = totalHours > 0 ? (totalDist / totalHours) : 60.0
            
            // Capacity Bottleneck: If any segment is single track, the whole leg is single track
            let minCap = path.map { 
                ($0.trackType == .single || $0.trackType == .regional) ? 1 : ($0.capacity ?? 2)
            }.min() ?? 1
            
            let isSingle = path.contains { $0.trackType == .single || $0.trackType == .regional }
            
            let index = optimizerTracks.count
            macroTracks[pair] = (index, totalDist, Int(effectiveSpeed), minCap)
            
            let s1 = stationMapping[from] ?? 0
            let s2 = stationMapping[to] ?? 0
            
            let track = OptimizerTrack(id: index,
                                      length_km: totalDist,
                                      is_single_track: isSingle,
                                      capacity: minCap,
                                      station_ids: [s1, s2],
                                      max_speed: Int(effectiveSpeed))
            optimizerTracks.append(track)
            return index
        }
        
        // 3. Map Trains using Macro-Tracks
        let optimizerTrains = trains.enumerated().map { index, train in
            trainMapping[train.id] = index
            
            let stationIds = train.stops.map { $0.stationId }
            let routeStationIndices = stationIds.compactMap { stationMapping[$0] }
            let originId = routeStationIndices.first ?? 0
            let destinationId = routeStationIndices.last ?? 0
            
            // Format departure in UTC
            var scheduledDepartureTime: String? = nil
            if let depTime = train.departureTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                scheduledDepartureTime = formatter.string(from: depTime)
            }
            
            // MATH SYNC: Build the route using TRACK IDs (Macro-tracks), not station IDs
            var trackIds: [Int] = []
            if stationIds.count >= 2 {
                for i in 0..<(stationIds.count - 1) {
                    if let trackIndex = getMacroTrack(from: stationIds[i], to: stationIds[i+1]) {
                        trackIds.append(trackIndex)
                    }
                }
            }
            
            let currentTrack = trackIds.first ?? 0
            let minDwell = 3 // PIGNOLO PROTOCOL: Hardcoded 3.0m base dwell
            
            return OptimizerTrain(
                id: index,
                position_km: 0.0,
                velocity_kmh: Double(train.maxSpeed),
                current_track: currentTrack,
                destination_station: destinationId,
                delay_minutes: 0,
                priority: train.priority,
                is_delayed: false,
                origin_station: originId,
                scheduled_departure_time: scheduledDepartureTime,
                route: trackIds, // FIXED: Now sending track indices
                min_dwell_minutes: minDwell
            )
        }
        
        return OptimizerRequest(trains: optimizerTrains, 
                                tracks: optimizerTracks, 
                                stations: optimizerStations, 
                                max_iterations: 600, // 10 hours is sufficient for the network scale
                                ga_max_iterations: 300, // PIGNOLO PROTOCOL: Recommended for 59 stations
                                ga_population_size: 100) // PIGNOLO PROTOCOL: High precision
    }
    
    /// Translates integer results back to original UUIDs
    func getTrainId(optimizerId: Int) -> UUID? {
        return trainMapping.first(where: { $1 == optimizerId })?.key
    }
}
