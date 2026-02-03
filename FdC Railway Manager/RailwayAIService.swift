import Foundation
import Combine

@MainActor
class RailwayAIService: ObservableObject {
    static let shared = RailwayAIService()
    
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
        
        if let t = token {
            request.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        } else if let key = apiKey {
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            request.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
        }
        
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
        
        // PIGNOLO PROTOCOL: Sync credentials from AuthenticationManager if local ones are missing or expired
        let currentToken = AuthenticationManager.shared.jwtToken ?? self.token ?? ""
        let currentKey = AuthenticationManager.shared.apiKey ?? self.apiKey ?? ""
        
        let cleanToken = currentToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKey = currentKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // PIGNOLO PROTOCOL: Reverted priority - Trust fresh Session Token first
        if !cleanToken.isEmpty {
            print("🔑 [DEBUG] Auth: Preferring Session Token (User refresh)")
            urlRequest.setValue("Bearer \(cleanToken)", forHTTPHeaderField: "Authorization")
        } else if !cleanKey.isEmpty && cleanKey.hasPrefix("rw-") {
            print("🔑 [DEBUG] Auth: Using Global API Key")
            urlRequest.setValue(cleanKey, forHTTPHeaderField: "X-API-Key")
        } else {
             // Last resort fallback
             if !cleanKey.isEmpty {
                let finalKey = "rw-\(cleanKey)"
                print("🔑 [DEBUG] Auth: Using Raw API Key (auto-prefixing)")
                urlRequest.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
             } else {
                print("⚠️ [DEBUG] No Credentials found in AuthManager or Service!")
             }
        }
        
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
    
    // PIGNOLO PROTOCOL: Overload for pre-formatted JSON from RailwayGraphManager
    func optimize(jsonString: String) -> AnyPublisher<RailwayAIResponse, Error> {
        let finalURL = baseURL.appendingPathComponent("optimize_scheduled")
        
        var urlRequest = URLRequest(url: finalURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "accept")
        
        if let token = self.token, !token.isEmpty {
            print("🔑 [DEBUG] Sending raw request with Session Token")
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let key = self.apiKey, !key.isEmpty {
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            print("🔑 [DEBUG] Sending raw request with API Key (X-API-Key)")
            urlRequest.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
        }
        
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
    func createRequest(network: RailwayNetwork, trains: [Train], fixedTrainIds: Set<UUID> = [], conflicts: [ScheduleConflict]) -> RailwayAIRequest {
        stationMapping.removeAll()
        trainMapping.removeAll()
        trackMapping.removeAll()
        
        // 1. Map STATIONS (ID string -> Int)
        let sortedNodes = network.nodes.sorted(by: { $0.id < $1.id })
        let aiStations = sortedNodes.enumerated().map { index, node in
            stationMapping[node.id] = index
            let platforms = node.platforms ?? (node.type == .interchange ? 4 : 2)
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
                let trackId = uniqueTracks.count // START FROM 0, NOT 1000
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
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute, .second], from: date)
            let dateAt2000 = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: components.hour, minute: components.minute, second: components.second)) ?? date
            
            // PIGNOLO PROTOCOL: INCREASE PRECISION to 1 second to match local engine perfectly
            let roundedSeconds = floor(dateAt2000.timeIntervalSinceReferenceDate + 0.5)
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
            
            // PIGNOLO PROTOCOL: Calculate ACTUAL average velocity from physical schedule
            var actualVelocity = Double(train.maxSpeed) * 0.9 // Fallback
            if let firstDep = train.stops.first?.departure, let lastArr = train.stops.last?.arrival {
                let totalTripSeconds = lastArr.timeIntervalSince(firstDep)
                let totalDwellSeconds = train.stops.reduce(0.0) { $0 + Double($1.minDwellTime * 60) }
                let movingSeconds = totalTripSeconds - totalDwellSeconds
                
                var totalDist = 0.0
                for i in 0..<(train.stops.count - 1) {
                    if let path = network.findPathEdges(from: train.stops[i].stationId, to: train.stops[i+1].stationId) {
                        totalDist += path.reduce(0.0) { $0 + $1.distance }
                    }
                }
                
                if movingSeconds > 30 && totalDist > 0 {
                    let v = (totalDist / (movingSeconds / 3600))
                    actualVelocity = min(v, Double(train.maxSpeed))
                }
            }
            
            // PIGNOLO PROTOCOL: Fixed trains are NOT delayed (from the AI perspective they are hard constraints)
            let isFixed = fixedTrainIds.contains(train.id)
            let isDelayed = isFixed ? false : conflicts.contains(where: { $0.trainAId == train.id || $0.trainBId == train.id })
            
            // Average dwell for better AI modeling
            let avgDwell = train.stops.isEmpty ? 2 : Double(train.stops.reduce(0) { $0 + $1.minDwellTime }) / Double(train.stops.count)
            
            return RailwayAITrainInfo(
                id: index,
                priority: train.priority,
                position_km: 0.0,
                velocity_kmh: actualVelocity, 
                current_track: currentTrackId,
                destination_station: stationMapping[destId] ?? 0,
                delay_minutes: 0,
                is_delayed: isDelayed,
                origin_station: stationMapping[originId] ?? 0,
                scheduled_departure_time: timeFormatter.string(from: depTime),
                planned_route: routeIds,
                min_dwell_minutes: Int(round(avgDwell))
            )
        }
        
        let finalRequest = RailwayAIRequest(
            trains: aiTrains,
            tracks: uniqueTracks,
            stations: aiStations,
            max_iterations: 1000,
            ga_max_iterations: nil,
            ga_population_size: nil
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
