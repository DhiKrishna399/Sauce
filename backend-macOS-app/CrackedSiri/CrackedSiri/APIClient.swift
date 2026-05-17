//
//  APIClient.swift
//  CrackedSiri
//

import Foundation

class APIClient {
    let baseURL: URL
    
    init(baseURL: String = "http://localhost:3000") {
        self.baseURL = URL(string: baseURL)!
    }
    
    func analyze(
        imageBase64: String,
        query: String,
        mode: String
    ) async throws -> GuideResponse {
        let request = AnalyzeRequest(
            imageBase64: imageBase64,
            query: query,
            mode: mode,
            context: nil
        )
        
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("/analyze"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(GuideResponse.self, from: data)
    }
    
    func analyzeAction(
        imageBase64: String,
        query: String
    ) async throws -> ActionResponse {
        let request = AnalyzeRequest(
            imageBase64: imageBase64,
            query: query,
            mode: "action",
            context: nil
        )
        
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("/analyze"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(ActionResponse.self, from: data)
    }
    
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("/health")
        let (_, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return (200...299).contains(httpResponse.statusCode)
    }
    
    func getCallStatus(callId: String) async throws -> CallStatusResponse {
        let url = baseURL.appendingPathComponent("/call/\(callId)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(CallStatusResponse.self, from: data)
    }
}
