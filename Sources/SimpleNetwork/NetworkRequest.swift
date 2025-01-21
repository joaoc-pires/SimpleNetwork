//
//  NetworkRequest.swift
//  
//
//  Created by Joao Pires on 02/09/2023.
//

import Foundation

public protocol NetworkRequest {
    var url: String { get }
    var method: HTTPMethod { get }
    var body: Data? { get }
    var eTag: String? { get }
    var customHeaders: [String : String]? { get }
    var sessionDelegate: (URLSessionDelegate & URLSessionTaskDelegate)? { get }
}

public extension NetworkRequest {
    var body : Data? { nil }
    var customHeaders : [String : String]? { nil }
}
