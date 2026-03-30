//
//  Connectivity.swift
//  SparkSatelliteWeather
//
//  Uses the system’s view of the current path (NWPathMonitor). Apple’s Network framework
//  does not expose a separate “satellite” interface type; it uses isUltraConstrained for
//  constrained/satellite paths. We map that to .low; status bar shows "Status: Low data".
//

import Foundation
import Network

enum Connectivity {
    case good
    case low
    case none
    
    /// Launch arg `-SimulateConstrainedPath good|low|none` to test without real hardware.
    private static var simulatedConnectivity: Connectivity? {
        guard let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-SimulateConstrainedPath"),
              ProcessInfo.processInfo.arguments.count > idx + 1 else { return nil }
        switch ProcessInfo.processInfo.arguments[idx + 1].lowercased() {
        case "good": return .good
        case "low": return .low
        case "none": return Connectivity.none
        default: return nil
        }
    }
    
    /// Derives connectivity from the current path. Relies on NWPath.isUltraConstrained as the
    /// system signal for constrained/satellite links (no separate satellite type in the public API).
    init(networkPath: NWPath) {
        if let simulated = Self.simulatedConnectivity {
            self = simulated
            return
        }
        
        guard networkPath.status == .satisfied else {
            self = .none
            return
        }
        if networkPath.isUltraConstrained {
            self = .low
            return
        }
        self = .good
    }
}
