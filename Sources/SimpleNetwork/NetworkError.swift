//
//  NetworkError.swift
//
//
//  Created by Joao Pires on 02/09/2023.
//

import Foundation

public enum NetworkError: Error {
    case noInternet
    case serverFailure(withHTTPCode: Int, rawData: Data)
    case failedToParse(body: String)
    case failedtoRefreshToken
    case aborted
    case maxAttemptsExceeded
    case noData
    case custom(message: String)
    case invalidURL
    case cached
}
