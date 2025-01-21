//
//  File.swift
//  
//
//  Created by Joao Pires on 02/09/2023.
//

import Foundation
import OSLog

final public class NetworkService {
    
    private var log: Logger
    
    private class BasicRequest: NetworkRequest {
        var url: String
        
        var method: HTTPMethod { .get }
        
        var eTag: String?
        
        var sessionDelegate: (URLSessionTaskDelegate)?
        
        init(url: String) {
            self.url = url
        }
        
        func getETagDataIfAvailable(_ response: HTTPURLResponse, _ data: Data) -> Data? {
            nil
        }
    }
    
    public init() {
        log = Logger(subsystem: "SimpleNetwork", category: "NetworkService")
    }

    
    public func fire(request: NetworkRequest, ignoreEtag: Bool = false, completion: @escaping (Result<Data, NetworkError>) -> (Void)) {
        log.info("creating session at '\(request.url)'")
        let urlString = "\(request.url.replacingOccurrences(of: "http://", with: "https://"))"
        guard let callURL = URL(string: urlString) else {
            log.error("failed to create sessions at '\(request.url)', '\(NetworkError.invalidURL)'")
            completion(.failure(.invalidURL))
            return
        }
        var urlRequest = URLRequest(url: callURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if !ignoreEtag, let etag = request.eTag {
            urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config, delegate: request.sessionDelegate, delegateQueue: nil)
        let task = urlSession.dataTask(with: urlRequest) { data, response, error in
            if let error = error as NSError?, error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                self.log.info("failed session at '\(urlString)' with error '\(error)', '\(error.localizedDescription)'")
                completion(.failure(.noData))
                return
            }
            guard let data = data, let response = response as? HTTPURLResponse, error == nil else {
                self.log.info("failed session at '\(urlString)' with no data")
                completion(.failure(.noData))
                return
            }
            guard (200 ... 299) ~= response.statusCode || response.statusCode == 304 else {
                self.log.error("request at '\(request.url)' return code \(response.statusCode)")
                completion(.failure(.serverFailure(withHTTPCode: response.statusCode, rawData: data)))
                return
            }
            if let cachedData = request.getETagDataIfAvailable(response, data) {
                self.log.info("sending cached data for session at '\(urlString)'")
                completion(.success(cachedData))
                return
            }
            self.log.info("successfully finished session at '\(urlString)'")
            completion(.success(data))
        }
        log.info("starting session at '\(urlString)'")
        task.resume()
    }
    
    
    public func fire(at requestURL: String, ignoreEtag: Bool = false, completion: @escaping (Result<Data, NetworkError>) -> (Void)) {
        let request = BasicRequest(url: requestURL)
        fire(request: request, ignoreEtag: ignoreEtag, completion: completion)
    }
    
    
    public func fire(request: NetworkRequest, ignoreEtag: Bool = false) async throws(NetworkError) -> Data {
        log.info("creating session at '\(request.url)'")
        let urlString = "\(request.url.replacingOccurrences(of: "http://", with: "https://"))"
        guard let callURL = URL(string: urlString) else {
            log.error("failed to create sessions at '\(request.url)', '\(NetworkError.invalidURL)'")
            throw .invalidURL
        }
        var urlRequest = URLRequest(url: callURL)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if !ignoreEtag, let etag = request.eTag {
            urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config, delegate: request.sessionDelegate, delegateQueue: nil)
        let result: (data: Data, response: URLResponse)
        do {
            result = try await urlSession.data(for: urlRequest)
        }
        catch {
            if let error = error as NSError?, error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                self.log.info("failed session at '\(urlString)' with error '\(error)', '\(error.localizedDescription)'")
                throw .noData
            }
            else {
                throw .custom(message: "unknown error")
            }
        }
        guard let response = result.response as? HTTPURLResponse else {
            self.log.info("failed session at '\(urlString)' with no data")
            throw .noData
        }
        guard (200 ... 299) ~= response.statusCode || response.statusCode == 304 else {
            self.log.error("request at '\(request.url)' return code \(response.statusCode)")
            throw .serverFailure(withHTTPCode: response.statusCode, rawData: result.data)
        }
        if response.statusCode == 304 {
            if let cachedData = request.getETagDataIfAvailable(response, result.data) {
                self.log.info("sending cached data for session at '\(urlString)'")
                return cachedData
            }
            else {
                self.log.info("failed to fetch cached data, starting new session at '\(urlString)' ignoring ETag")
                return try await fire(request: request, ignoreEtag: true)
            }
        }
        else {
            self.log.info("successfully finished session at '\(urlString)'")
            return result.data
        }
    }
    
    
    public func fire(at requestURL: String, ignoreEtag: Bool = false) async throws -> Data {
        try await fire(request: BasicRequest(url: requestURL), ignoreEtag: ignoreEtag)
    }

    
}
