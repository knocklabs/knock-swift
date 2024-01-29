//
//  KnockAPIService.swift
//  KnockSample
//
//  Created by Matt on 01/29/2023.
//

import Foundation


internal class KnockAPIService: NSObject {
    
    func makeRequest<T:Codable>(method: String, path: String, queryItems: [URLQueryItem]?, body: Encodable?) async throws -> T {
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        guard var URL = URL(string: "\(KnockEnvironment.shared.baseUrl)\(path)") else {
            throw Knock.NetworkError(title: "Invalid URL", description: "The URL: \(KnockEnvironment.shared.baseUrl)\(path) is invalid", code: 0)
        }
        
        if queryItems != nil {
            URL = URL.appending(queryItems: queryItems!)
        }
        
        var request = URLRequest(url: URL)
        request.httpMethod = method
        
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        if body != nil {
            let encoder = JSONEncoder()
            let data = try! encoder.encode(body!)
            request.httpBody = data
        }
        
        // Headers
        
        request.addValue("knock-swift@\(Knock.clientVersion)", forHTTPHeaderField: "User-Agent")
        
        request.addValue("Bearer \(KnockEnvironment.shared.publishableKey)", forHTTPHeaderField: "Authorization")
        if let userToken = KnockEnvironment.shared.userToken {
            request.addValue(userToken, forHTTPHeaderField: "X-Knock-User-Token")
        }
        
        // Make the request
        let (responseData, urlResponse) = try await session.data(for: request)
        let statusCode = (urlResponse as! HTTPURLResponse).statusCode
        if statusCode < 200 || statusCode > 299 {
            throw Knock.NetworkError(title: "Status code error", description: String(data: responseData, encoding: .utf8) ?? "Unknown error", code: statusCode)
        }
        
        return try decodeData(responseData)
    }
}

extension KnockAPIService {
    internal func get<T:Codable>(path: String, queryItems: [URLQueryItem]?) async throws -> T {
        try await makeRequest(method: "GET", path: path, queryItems: queryItems, body: nil)
    }
    
    internal func post<T:Codable>(path: String, body: Encodable?) async throws -> T  {
        try await makeRequest(method: "POST", path: path, queryItems: nil, body: body)
    }
    
    internal func put<T:Codable>(path: String, body: Encodable?) async throws -> T  {
        try await makeRequest(method: "PUT", path: path, queryItems: nil, body: body)
    }
    
    internal func delete<T:Codable>(path: String, body: Encodable?) async throws -> T {
        try await makeRequest(method: "DELETE", path: path, queryItems: nil, body: body)
    }
    
    internal func decodeData<T:Codable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        let result = try decoder.decode(T.self, from: data)
        return result
    }
}
