//
//  NetworkURLSessionHTTPClient.swift
//  SparkSatelliteWeather
//

import Foundation

/// A simple client for requesting data using URLSession, which has enabled allowing access on constrained networks
struct NetworkURLSessionHTTPClient {
    static func get(from url: URL, timeout: TimeInterval) async throws -> (Data, HTTPURLResponse) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        // Allow access on constrained networks
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true

        // iOS 26.4+ recommended for Spark satellite; allowsUltraConstrainedNetworkAccess for HTTPS on ultra-constrained paths
        if #available(iOS 26.4, *) {
            configuration.allowsUltraConstrainedNetworkAccess = true
        }
        
        let session = URLSession(configuration: configuration)
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        return (data, httpResponse)
    }
}


