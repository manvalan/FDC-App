import Foundation
import Combine

class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
    var baseURL = URL(string: "https://railway-ai.michelebigi.it/api/v1")!
    var token: String? = nil
    var apiKey: String? = nil
    
    private var stationMapping: [String: Int] = [:]
    private var trackMapping: [String: Int] = [:]
    private var trainMapping: [UUID: Int] = [:]
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case unauthorized
        case error(String)
    }
    
    @Published var connectionStatus: ConnectionStatus = .disconnected {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
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
        
        if let t = token {
            self.token = t
        }
        
        // Update AuthManager as well
        if let key = self.apiKey { AuthenticationManager.shared.setAPIKey(key) }
        if let t = self.token { AuthenticationManager.shared.setToken(t) }
        
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
        guard token != nil || apiKey != nil else {
            self.connectionStatus = .disconnected
            return
        }
        
        self.connectionStatus = .connecting
        
        // Use a more generic endpoint for connection health check
        // PIGNOLO PROTOCOL: Use /health for simple ping, or /users/me if authenticated?
        // Let's use /health or just root path if that fails. For now, appending /health is safer for Python APIs.
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
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
                    RailwayAILogger.shared.log("Health Check Status: \(httpResponse.statusCode)", type: httpResponse.statusCode < 400 ? .success : .warning)
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
        // PIGNOLO PROTOCOL: Switching to the robust 'optimize_scheduled' endpoint as per technical specs.
        let finalURL = baseURL.appendingPathComponent("optimize_scheduled")
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        if let token = self.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = self.apiKey, !key.isEmpty {
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            urlRequest.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
            urlRequest.setValue("Bearer \(finalKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            // PIGNOLO PROTOCOL: Dates are already formatted as "HH:mm:ss" in the Request object.
            
            urlRequest.httpBody = try encoder.encode(request)
            if let json = String(data: urlRequest.httpBody!, encoding: .utf8) {
                print("[AI] Optimization Request (Scheduled): \(json)")
                self.lastRequestJSON = json // Salva per ispezione UI
                
                // Salva anche su file per persistenza debug
                let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
                try? json.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
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
                
                if httpResponse.statusCode == 401 {
                    self.token = nil
                }
                
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                    print("❌ [AI ERROR] \(httpResponse.statusCode) at \(finalURL.absoluteString): \(body)")
                    throw NSError(domain: "Server Error \(httpResponse.statusCode): \(body)", code: httpResponse.statusCode)
                }
                print("✅ [AI SUCCESS] \(httpResponse.statusCode) from \(finalURL.absoluteString)")
                return output.data
            }
            .decode(type: RailwayAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // PIGNOLO PROTOCOL: Overload for pre-formatted JSON from RailwayGraphManager
    func optimize(jsonString: String) -> AnyPublisher<RailwayAIResponse, Error> {
        let finalURL = baseURL.appendingPathComponent("optimize_scheduled")
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        if let token = self.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = self.apiKey, !key.isEmpty {
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            urlRequest.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
            urlRequest.setValue("Bearer \(finalKey)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonString.data(using: .utf8)
        
        // Debug & Logging
        print("[AI] Optimization Request (Raw JSON): \(jsonString)")
        self.lastRequestJSON = jsonString
        
        let path = "/Users/michelebigi/Documents/Develop/XCode/FdC/FdC Railway Manager/last_ai_request.json"
        try? jsonString.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        
        return URLSession.shared.dataTaskPublisher(for: urlRequest)
            .timeout(120, scheduler: DispatchQueue.main)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                if httpResponse.statusCode == 401 {
                    self.token = nil
                }
                
                if httpResponse.statusCode != 200 {
                    let body = String(data: output.data, encoding: .utf8) ?? "Nessun corpo risposta"
                    print("❌ [AI ERROR] \(httpResponse.statusCode) at \(finalURL.absoluteString): \(body)")
                    throw NSError(domain: "Server Error \(httpResponse.statusCode): \(body)", code: httpResponse.statusCode)
                }
                print("✅ [AI SUCCESS] \(httpResponse.statusCode) from \(finalURL.absoluteString)")
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
        stationMapping.removeAll()
        trainMapping.removeAll()
        trackMapping.removeAll()
        
        // 1. Map STATIONS (ID string -> Int)
        let sortedNodes = network.nodes.sorted(by: { $0.id < $1.id })
        let aiStations = sortedNodes.enumerated().map { index, node in
            stationMapping[node.id] = index
            let platforms = node.platforms ?? (node.type == .interchange ? 2 : 1)
            return RailwayAIStationInfo(id: index, name: node.name, num_platforms: platforms)
        }
        
        // 2. Map UNIQUE TRACKS (Group edges between same stations)
        var uniqueTracks: [RailwayAITrackInfo] = []
        var segmentToTrackId: [String: Int] = [:] // Key: "minId-maxId"
        
        for edge in network.edges {
            let s1 = stationMapping[edge.from] ?? 0
            let s2 = stationMapping[edge.to] ?? 0
            let key = [s1, s2].sorted().map{String($0)}.joined(separator: "-")
            
            if let trackId = segmentToTrackId[key] {
                // Link this edge UUID to the existing track ID
                trackMapping[edge.id.uuidString] = trackId
            } else {
                let trackId = 1000 + uniqueTracks.count
                segmentToTrackId[key] = trackId
                trackMapping[edge.id.uuidString] = trackId
                
                let isSingle = edge.trackType == .single || edge.trackType == .regional
                let capacity = isSingle ? 1 : 2
                
                let track = RailwayAITrackInfo(
                    id: trackId,
                    station_ids: [s1, s2],
                    length_km: edge.distance,
                    is_single_track: isSingle,
                    capacity: capacity
                )
                uniqueTracks.append(track)
            }
        }
        
        // Formatter for "HH:mm:ss"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        func normalize(_ date: Date?) -> Date? {
            guard let date = date else { return nil }
            let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
            let d = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: comps.hour, minute: comps.minute, second: comps.second)) ?? date
            let roundedSeconds = floor((d.timeIntervalSinceReferenceDate + 30) / 60) * 60
            return Date(timeIntervalSinceReferenceDate: roundedSeconds)
        }
        
        // 3. Map TRAINS
        let aiTrains = trains.enumerated().map { index, train in
            trainMapping[train.id] = index
            
            let originId = train.stops.first?.stationId ?? ""
            let destId = train.stops.last?.stationId ?? ""
            
            // Build planned_route as a list of track IDs
            var routeIds: [Int] = []
            for i in 0..<(train.stops.count - 1) {
                let s1 = train.stops[i].stationId
                let s2 = train.stops[i+1].stationId
                if let edge = network.edges.first(where: { ($0.from == s1 && $0.to == s2) || ($0.from == s2 && $0.to == s1) }) {
                    if let tId = trackMapping[edge.id.uuidString] {
                        routeIds.append(tId)
                    }
                }
            }
            
            let depTime = normalize(train.departureTime) ?? Date()
            let currentTrackId = routeIds.first ?? 0
            
            return RailwayAITrainInfo(
                id: index,
                priority: train.priority,
                position_km: 0.0,
                velocity_kmh: Double(train.maxSpeed),
                current_track: currentTrackId,
                destination_station: stationMapping[destId] ?? 0,
                delay_minutes: 0,
                is_delayed: false,
                origin_station: stationMapping[originId] ?? 0,
                scheduled_departure_time: timeFormatter.string(from: depTime),
                planned_route: routeIds,
                min_dwell_minutes: train.stops.map { $0.minDwellTime }.max() ?? 3
            )
        }
        
        let finalRequest = RailwayAIRequest(
            trains: aiTrains,
            tracks: uniqueTracks,
            stations: aiStations,
            max_iterations: 1000,
            ga_max_iterations: 150,
            ga_population_size: 50
        )
        
        self.lastRequestJSON = (try? String(data: JSONEncoder().encode(finalRequest), encoding: .utf8)) ?? ""
        
        return finalRequest
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
    
    // Alias for compatibility
    func getTrainId(optimizerId: Int) -> UUID? {
        return getTrainUUID(optimizerId: optimizerId)
    }
    
    func getTrainMapping() -> [UUID: Int] {
        return trainMapping
    }
}
