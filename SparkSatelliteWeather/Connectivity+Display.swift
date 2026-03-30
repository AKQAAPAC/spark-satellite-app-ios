//
//  Connectivity+Display.swift
//  SparkSatelliteWeather
//

import SwiftUI

extension Connectivity {
    /// Status line for the status bar: "Status: Good/Low/No data".
    var description: String {
        switch self {
        case .good: return "Status: Good data"
        case .low: return "Status: Low data"
        case .none: return "Status: No data"
        }
    }
}
