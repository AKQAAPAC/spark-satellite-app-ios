//
//  RainViewerAPI.swift
//  SparkSatelliteWeather
//
//  Free radar map via RainViewer (no API key). Attribution required.
//  https://www.rainviewer.com/api/weather-maps-api.html
//

import Foundation

struct RainViewerAPI {
    
    private static let mapsURL = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
    
    /// Color scheme 2 = Universal Blue. Options: 1_1 = smooth, snow.
    private static let colorScheme = "2"
    private static let options = "1_1"
    private static let size = "512"
    /// Zoom 4 = more focused on location (smaller area than 3).
    private static let zoom = "4"
    
    struct MapsResponse: Codable {
        let host: String
        let radar: Radar?
        struct Radar: Codable {
            let past: [Frame]?
            struct Frame: Codable {
                let time: Int
                let path: String
            }
        }
    }
    
    /// A single radar frame with timestamp (UTC) and image URL for the given location.
    struct RadarFrame: Sendable {
        let time: Date
        let imageURL: URL
    }
    
    /// Returns all past radar frames (2 hours, ~10 min steps) for the given coordinates. Newest last.
    static func radarFrames(latitude: Double, longitude: Double) async -> [RadarFrame]? {
        do {
            let (data, _) = try await URLSession.shared.data(from: mapsURL)
            let decoded = try JSONDecoder().decode(MapsResponse.self, from: data)
            guard let frames = decoded.radar?.past, !frames.isEmpty else { return nil }
            let host = decoded.host
            let rest = "\(size)/\(zoom)/\(latitude)/\(longitude)/\(colorScheme)/\(options).png"
            return frames.compactMap { f in
                let pathPart = f.path.hasSuffix("/") ? f.path : f.path + "/"
                guard let url = URL(string: host + pathPart + rest) else { return nil }
                return RadarFrame(time: Date(timeIntervalSince1970: TimeInterval(f.time)), imageURL: url)
            }
        } catch {
            return nil
        }
    }
}
