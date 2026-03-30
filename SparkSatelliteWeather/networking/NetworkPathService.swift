//
//  NetworkPathService.swift
//  SparkSatelliteWeather
//

import Foundation
import Network

protocol NetworkPathServiceObserver: AnyObject {
    func networkPathDidUpdate(with path: NWPath)
}

final class NetworkPathService {
    static let shared = NetworkPathService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkPathService")
    private var observers: [NetworkPathServiceObserver] = []

    private init() {
        
        monitor.pathUpdateHandler = { [weak self] path in
            self?.observers.forEach { observer in
                observer.networkPathDidUpdate(with: path)
            }
        }
        monitor.start(queue: queue)
    }
    
    func register(observer: NetworkPathServiceObserver) {
        self.observers.append(observer)
    }
}
