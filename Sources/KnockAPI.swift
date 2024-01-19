//
//  Net.swift
//  KnockSample
//
//  Created by Diego on 26/04/23.
//

import Foundation

class KnockAPI {
    private let publishableKey: String
    private let userToken: String?
    public var hostname = "https://api.knock.app"
    private var apiBasePath: String {
        "\(hostname)/v1"
    }
    
    static let clientVersion = "0.1.0"
    
    init(publishableKey: String, userToken: String? = nil, hostname: String? = nil) {
        self.publishableKey = publishableKey
        self.userToken = userToken
        
        if let customHostname = hostname {
            self.hostname = customHostname
        }
    }
    
    // MARK: Decode functions, they encapsulate making the request and decoding the data
    
    func decodeFromGet<T:Codable>(_ type: T.Type, path: String, queryItems: [URLQueryItem]?, then handler: @escaping (Result<T, Error>) -> Void) {
        get(path: path, queryItems: queryItems) { (result) in
            self.decodeData(result, handler: handler)
        }
    }
    
    func decodeFromPost<T:Codable>(_ type: T.Type, path: String, body: Encodable?, then handler: @escaping (Result<T, Error>) -> Void) {
        post(path: path, body: body) { (result) in
            self.decodeData(result, handler: handler)
        }
    }
    
    func decodeFromPut<T:Codable>(_ type: T.Type, path: String, body: Encodable?, then handler: @escaping (Result<T, Error>) -> Void) {
        put(path: path, body: body) { (result) in
            self.decodeData(result, handler: handler)
        }
    }
    
    func decodeFromDelete<T:Codable>(_ type: T.Type, path: String, body: Encodable?, then handler: @escaping (Result<T, Error>) -> Void) {
        delete(path: path, body: body) { (result) in
            self.decodeData(result, handler: handler)
        }
    }
    
    private func decodeData<T:Codable>(_ result: Result<Data, Error>, handler: @escaping (Result<T, Error>) -> Void) {
        switch result {
        case .success(let data):
            let decoder = JSONDecoder()
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            
            decoder.dateDecodingStrategy = .formatted(formatter)
            
            do {
                let resultType = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async {
                    handler(.success(resultType))
                }
            }
            catch let error {
                if let dataString = String(data: data, encoding: .utf8) {
                    print("error decoding data: \(dataString)")
                }
                else {
                    print("error processing undecodable data")
                }
                
                DispatchQueue.main.async {
                    handler(.failure(error))
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                handler(.failure(error))
            }
        }
    }
    
    // MARK: Method wrappers to adjust where to put the parameters (query or body)
    
    private func get(path: String, queryItems: [URLQueryItem]?, then handler: @escaping (Result<Data, Error>) -> Void) {
        makeGeneralRequest(method: "GET", path: path, queryItems: queryItems, body: nil, then: handler)
    }
    
    private func post(path: String, body: Encodable?, then handler: @escaping (Result<Data, Error>) -> Void) {
        makeGeneralRequest(method: "POST", path: path, queryItems: nil, body: body, then: handler)
    }
    
    private func put(path: String, body: Encodable?, then handler: @escaping (Result<Data, Error>) -> Void) {
        makeGeneralRequest(method: "PUT", path: path, queryItems: nil, body: body, then: handler)
    }
    
    private func delete(path: String, body: Encodable?, then handler: @escaping (Result<Data, Error>) -> Void) {
        makeGeneralRequest(method: "DELETE", path: path, queryItems: nil, body: body, then: handler)
    }
    
    // MARK: Actual code to make the request
    
    /**
     Make the http request. The completion `then` handler is executed asyncronously on the main thread.
     
     - Attention: Currently, there's no retry policy. Here would be a good plate to implement it, for instance X number of retries and an exponential timeout on each one. Also, first check if the path or request is allowed to be retried (is it safe to retry or does it support an idempotency token?)
     
     - Parameters:
        - method: GET, POST, PUT, DELETE
        - path: the absolute path (host [+ port] + relative path)
        - queryItems: optional array of `URLQueryItem`
        - body: optional array of parameters to pass in the body of the request
        - then: the code to execute when the response is received
     */
    private func makeGeneralRequest(method: String, path: String, queryItems: [URLQueryItem]?, body: Encodable?, then handler: @escaping (Result<Data, Error>) -> Void) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
        guard var URL = URL(string: "\(apiBasePath)\(path)") else {return}
        
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
        
        request.addValue("knock-swift@\(KnockAPI.clientVersion)", forHTTPHeaderField: "User-Agent")
        
        request.addValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        if let userToken = userToken {
            request.addValue(userToken, forHTTPHeaderField: "X-Knock-User-Token")
        }
        
        // Make the request
        
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if (error == nil) {
                // Success
                let statusCode = (response as! HTTPURLResponse).statusCode
                
                if let data = data {
                    if statusCode < 200 || statusCode > 299 {
                        DispatchQueue.main.async {
                            handler(.failure(NetworkError(title: "Status code error", description: String(data: data, encoding: .utf8) ?? "Unknown error", code: statusCode)))
                        }
                    }
                    
                    DispatchQueue.main.async {
                        handler(.success(data))
                    }
                }
                else {
                    DispatchQueue.main.async {
                        handler(.failure(NetworkError(title: "Unknown Error", description: "Error, data == nil", code: statusCode)))
                    }
                }
            }
            else {
                DispatchQueue.main.async {
                    handler(.failure(error!))
                }
            }
        })
        task.resume()
        session.finishTasksAndInvalidate()
    }
}

public protocol NetworkErrorProtocol: LocalizedError {
    var title: String? { get }
    var code: Int { get }
}

public struct NetworkError: NetworkErrorProtocol {
    public var title: String?
    public var code: Int
    public var errorDescription: String? { return _description }
    public var failureReason: String? { return _description }
    
    private var _description: String
    
    public init(title: String?, description: String, code: Int) {
        self.title = title ?? "Error"
        self._description = description
        self.code = code
    }
}
