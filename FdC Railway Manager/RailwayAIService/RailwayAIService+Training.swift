import Foundation
import SwiftUI
import Combine

extension RailwayAIService {
    // MARK: - Training & Scenari Flow
    
    func generateScenario(area: String) -> AnyPublisher<Void, Error> {
        guard let token = self.token else {
            return Fail(error: NSError(domain: "Richiede login.", code: 401)).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: baseURL.appendingPathComponent("scenario/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authManager.attachAuthHeaders(to: &request)
        
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
        authManager.attachAuthHeaders(to: &request)
        
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
    

}
