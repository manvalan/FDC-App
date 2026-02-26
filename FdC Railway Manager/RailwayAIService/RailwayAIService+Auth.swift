import Foundation
import SwiftUI
import Combine

extension RailwayAIService {
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

    func performCheck(at endpoints: [String]) {
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
    

}
