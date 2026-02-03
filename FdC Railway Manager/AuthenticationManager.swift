
//
//  AuthenticationManager.swift
//  RailwayApp
//
//  Created for RailwayAI Agent Integration.
//

import Foundation
import Combine

public enum AuthError: Error {
    case invalidCredentials
    case serverError(String)
    case decodingError
    case missingToken
    case inactiveAccount // Handles code 403 "Account is inactive"
}

public class AuthenticationManager {
    public static let shared = AuthenticationManager()
    
    // Configuration
    private var baseURL = "http://railway-ai.michelebigi.it:8080" 
    public private(set) var apiKey: String?
    public private(set) var jwtToken: String?
    
    private init() {}
    
    /// Updates the base URL dynamically from settings
    public func updateBaseURL(_ url: String) {
        let clean = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            self.baseURL = clean
            print("AuthManager: BaseURL updated to \(clean)")
        }
    }
    
    /// Checks if we have valid credentials
    public var isAuthenticated: Bool {
        return apiKey != nil || jwtToken != nil
    }
    
    /// Sets a permanent API Key manually (if already obtained).
    public func setAPIKey(_ key: String) {
        self.apiKey = key
        print("AuthManager: API Key set manually.")
    }
    /// Sets a JWT Token manually (if loaded from storage).
    public func setToken(_ token: String) {
        self.jwtToken = token
        print("AuthManager: JWT Token set manually.")
    }
    
    // MARK: - Login Flow
    
    /// Logs in using username/password to get a temporary JWT token.
    public func login(username: String, password: String, completion: @escaping (Result<String, AuthError>) -> Void) {
        // INSTRUCTION COMPLIANCE: Always perform network login to ensure token validity.
        // Try fallback if primary endpoint failed in previous logs (remote Docker uses /api/v1/login/access-token often)
        let endpoint = baseURL.contains("/api/v1") ? "\(baseURL)/login/access-token" : "\(baseURL)/token"
        guard let url = URL(string: endpoint) else {
            completion(.failure(.serverError("URL non valido: \(endpoint)")))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Use URLComponents to safely encode username and password
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]
        request.httpBody = bodyComponents.query?.data(using: .utf8)
        
        print("AuthManager: Attempting login at \(endpoint)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(.failure(.serverError(error?.localizedDescription ?? "Unknown error")))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 403 {
                    completion(.failure(.inactiveAccount))
                    return
                }
                if httpResponse.statusCode != 200 {
                    let body = String(data: data, encoding: .utf8) ?? "No Body"
                    print("AuthManager Login Error [\(httpResponse.statusCode)]: \(body)")
                    completion(.failure(.invalidCredentials))
                    return
                }
            }
            
            // Decode Token
            struct TokenResponse: Decodable {
                let access_token: String
                let token_type: String
            }
            
            do {
                let tokenObj = try JSONDecoder().decode(TokenResponse.self, from: data)
                self?.jwtToken = tokenObj.access_token
                print("AuthManager: Login successful. JWT Token obtained.")
                completion(.success(tokenObj.access_token))
            } catch {
                print("AuthManager: Decoding error: \(error)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - API Key Generation Flow
    
    /// Generates a permanent API Key. Requires prior login (JWT).
    public func generatePermanentKey(completion: @escaping (Result<String, AuthError>) -> Void) {
        guard let token = self.jwtToken else {
            completion(.failure(.missingToken))
            return
        }
        
        // INSTRUCTION COMPLIANCE: "generate_key" or "generate-key"
        // Let's use the one confirmed by recent server snapshots
        let endpoint = "\(baseURL)/api/v1/generate-key"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // NO BODY REQUIRED per openapi.json
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                let errStr = error?.localizedDescription ?? "Network error"
                print("AuthManager Key Error: \(errStr)")
                completion(.failure(.serverError(errStr)))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    print("AuthManager: Token invalid or expired (401). Clearing credentials.")
                    self?.jwtToken = nil
                    completion(.failure(.invalidCredentials))
                    return
                }
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    let body = String(data: data, encoding: .utf8) ?? "No Body"
                    print("AuthManager Key Error [\(httpResponse.statusCode)]: \(body)")
                    completion(.failure(.serverError("Server returned \(httpResponse.statusCode)")))
                    return
                }
            }
            
            struct KeyResponse: Decodable {
                let api_key: String
            }
            
            do {
                // Try decoding as object first
                if let keyObj = try? JSONDecoder().decode(KeyResponse.self, from: data) {
                    self?.apiKey = keyObj.api_key
                } else if let rawString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !rawString.isEmpty {
                    // Try decoding as plain string (e.g. "rw-xyz") or double-quoted string
                    if rawString.hasPrefix("\"") && rawString.hasSuffix("\"") {
                        self?.apiKey = String(rawString.dropFirst().dropLast())
                    } else {
                        self?.apiKey = rawString
                    }
                }
                
                if let key = self?.apiKey {
                    // Normalize prefix if needed (PIGNOLO PROTOCOL)
                    if !key.hasPrefix("rw-") && key.count > 5 {
                        self?.apiKey = "rw-\(key)"
                    }
                    print("AuthManager: Permanent API Key Generated: \(self?.apiKey ?? "ERROR")")
                    completion(.success(self?.apiKey ?? ""))
                } else {
                    print("AuthManager: Failed to parse API Key from response.")
                    completion(.failure(.decodingError))
                }
            } catch {
                print("AuthManager Key Decoding Error: \(error)")
                let body = String(data: data, encoding: .utf8) ?? "No Body"
                print("AuthManager Key Body: \(body)")
                completion(.failure(.decodingError))
            }
        }.resume()
    }
    
    // MARK: - Registration Flow (Admin)
    
    /// Registers a new user. Requires Admin authentication.
    public func registerNewUser(username: String, password: String, completion: @escaping (Result<Bool, AuthError>) -> Void) {
        let endpoint = "\(baseURL)/api/v1/register"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Admin Auth (Either API Key or Token)
        if let key = apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        } else if let token = jwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(true))
            } else {
                completion(.failure(.serverError("Registration failed")))
            }
        }.resume()
    }
    
    /// Helper to attach headers to any request
    public func attachAuthHeaders(to request: inout URLRequest) {
        if let key = apiKey, !key.isEmpty {
            // PIGNOLO PROTOCOL: Send both X-API-Key and Bearer Authorization for API Keys
            let finalKey = key.hasPrefix("rw-") ? key : "rw-\(key)"
            request.setValue(finalKey, forHTTPHeaderField: "X-API-Key")
            request.setValue("Bearer \(finalKey)", forHTTPHeaderField: "Authorization")
            print("AuthManager: Attached API Key \(finalKey.prefix(6))...")
        } else if let token = jwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("AuthManager: Attached JWT Token \(token.prefix(10))...")
        } else {
            print("AuthManager: No credentials to attach (ApiKey and Token are nil).")
        }
    }
}
