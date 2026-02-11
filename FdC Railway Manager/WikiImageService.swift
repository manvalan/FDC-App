import Foundation
import Combine
import UIKit

class WikiImageService: ObservableObject {
    static let shared = WikiImageService()
    
    @Published var currentImageURL: URL?
    @Published var isLoading = false
    
    private var cache: [String: URL] = []
    
    func searchImage(for query: String) {
        // Clean up query for search (e.g. "ETR 1000")
        let cleanedQuery = query.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespaces) ?? query
        
        // Check cache first
        if let cached = cache[cleanedQuery] {
            self.currentImageURL = cached
            return
        }
        
        self.isLoading = true
        self.currentImageURL = nil
        
        // 1. First try: Flexible Search in File Namespace
        searchWikimedia(term: "\(cleanedQuery) train", limit: 1) { [weak self] url in
            DispatchQueue.main.async {
                if let url = url {
                    self?.cache[cleanedQuery] = url
                    self?.currentImageURL = url
                    self?.isLoading = false
                } else {
                    // 2. Fallback: Try specific pattern suggested by user (File:ETR_XXX_in_station.jpg)
                    // Note: This is less likely to hit but we try it as requested
                    self?.tryDirectFileFetch(filename: "File:\(cleanedQuery)_in_station.jpg")
                }
            }
        }
    }
    
    private func searchWikimedia(term: String, limit: Int, completion: @escaping (URL?) -> Void) {
        // Endpoint: https://commons.wikimedia.org/w/api.php
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        
        // Query parameters for search
        // action=query&generator=search&gsrsearch=ETR%20500&gsrnamespace=6&prop=pageimages&pithumbsize=500&format=json
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: term),
            URLQueryItem(name: "gsrnamespace", value: "6"), // 6 = File namespace
            URLQueryItem(name: "gsrlimit", value: "\(limit)"),
            URLQueryItem(name: "pithumbsize", value: "600")
        ]
        
        guard let url = components.url else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let query = json["query"] as? [String: Any],
                   let pages = query["pages"] as? [String: Any] {
                    
                    // Get first page result
                    for (_, value) in pages {
                        if let page = value as? [String: Any],
                           let thumbnail = page["thumbnail"] as? [String: Any],
                           let source = thumbnail["source"] as? String,
                           let url = URL(string: source) {
                            completion(url)
                            return
                        }
                    }
                }
            } catch {
                print("JSON Parsing error: \(error)")
            }
            
            completion(nil)
        }.resume()
    }
    
    private func tryDirectFileFetch(filename: String, completion: ((URL?) -> Void)? = nil) {
        // Implementation of the user's specific request pattern
        // action=query&titles=File:Name.jpg&prop=pageimages&format=json
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "titles", value: filename),
            URLQueryItem(name: "pithumbsize", value: "600")
        ]
        
        guard let url = components.url else {
            completion?(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            var foundURL: URL? = nil
            defer {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    if let u = foundURL {
                        self?.currentImageURL = u // Update main state if found
                    }
                    completion?(foundURL)
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let pages = query["pages"] as? [String: Any] else { return }
            
            for (_, value) in pages {
                if let page = value as? [String: Any],
                   let thumbnail = page["thumbnail"] as? [String: Any],
                   let source = thumbnail["source"] as? String {
                    foundURL = URL(string: source)
                    return
                }
            }
        }.resume()
    }
}
