import Foundation
import Combine

// Extension to RailwayAIService for API Key validation
extension RailwayAIService {
    /// Verifica la validità della API Key e restituisce informazioni sull'utente
    func checkKeyStatus() -> AnyPublisher<KeyInfoResponse, Error> {
        guard let apiKey = self.apiKey, !apiKey.isEmpty else {
            return Fail(error: NSError(domain: "API Key non configurata", code: 401)).eraseToAnyPublisher()
        }
        
        let keyInfoURL = baseURL.appendingPathComponent("key-info")
        var request = URLRequest(url: keyInfoURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0
        
        // Use X-API-Key header
        let finalKey = apiKey.hasPrefix("rw-") ? apiKey : "rw-\(apiKey)"
        request.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
        
        RailwayAILogger.shared.log("Verifying API Key at \(keyInfoURL.absoluteString)", type: .info)
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let httpResponse = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                let body = String(data: output.data, encoding: .utf8) ?? ""
                RailwayAILogger.shared.log("Key Info Response (\(httpResponse.statusCode)): \(body.prefix(200))", type: httpResponse.statusCode == 200 ? .success : .error)
                
                if httpResponse.statusCode == 403 {
                    throw NSError(domain: "API Key scaduta o non valida", code: 403)
                }
                
                if httpResponse.statusCode != 200 {
                    throw NSError(domain: "Errore verifica chiave (\(httpResponse.statusCode)): \(body)", code: httpResponse.statusCode)
                }
                
                return output.data
            }
            .decode(type: KeyInfoResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
