import Foundation
import SwiftUI
import Combine

extension RailwayAIService {
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
    

}
