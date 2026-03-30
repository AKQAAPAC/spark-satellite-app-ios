//
//  LocationService.swift
//  SparkSatelliteWeather
//

import Foundation
import CoreLocation

/// Provides current GPS location and reverse-geocoded place name. Requested on app start and on Refresh only; no continuous updates.
@Observable
final class LocationService: NSObject {
    
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<(CLLocationCoordinate2D, String?)?, Never>?
    private var authContinuation: CheckedContinuation<Void, Never>?
    
    /// Last known coordinate (e.g. after requestLocation). Used for API calls.
    private(set) var lastCoordinate: CLLocationCoordinate2D?
    
    /// Place name from reverse geocoding (e.g. "Auckland"). nil until resolved.
    private(set) var placeName: String?
    
    /// Authorization status for location.
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    
    override init() {
        super.init()
        manager.delegate = self
        // Align with Android Fused `PRIORITY_HIGH_ACCURACY` (not kilometer-scale cell/Wi‑Fi).
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /// Requests current location, then reverse-geocodes to a place name. Returns (coordinate, placeName); placeName may be nil. Returns nil if location unavailable.
    /// When `forceRefresh` is false, returns last known coordinate first if available (matches Android `getCurrentLocation(forceRefresh = false)`).
    func requestLocation(forceRefresh: Bool = false) async -> (CLLocationCoordinate2D, String?)? {
        guard CLLocationManager.locationServicesEnabled() else { return nil }
        
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                authContinuation = cont
            }
            return await requestLocation(forceRefresh: forceRefresh)
        case .denied, .restricted:
            return nil
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            return nil
        }
        
        if !forceRefresh, let last = lastCoordinate {
            return (last, placeName)
        }
        
        return await withCheckedContinuation { cont in
            locationContinuation = cont
            manager.requestLocation()
        }
    }
    
    private func resolveLocationContinuation(with location: CLLocation?, error: Error?) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        if let loc = location {
            let coord = loc.coordinate
            lastCoordinate = coord
            Task {
                let name = await reverseGeocode(coord)
                await MainActor.run { placeName = name }
                cont.resume(returning: (coord, name))
            }
        } else {
            if let coord = lastCoordinate {
                cont.resume(returning: (coord, placeName))
            } else {
                cont.resume(returning: nil)
            }
        }
    }
    
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return nil }
            return Self.formatPlaceName(place)
        } catch {
            return nil
        }
    }
    
    /// Builds a readable location string without country, e.g. "Ponsonby, Auckland".
    private static func formatPlaceName(_ place: CLPlacemark) -> String? {
        let locality = place.locality
        let subLocality = place.subLocality
        let administrativeArea = place.administrativeArea
        var parts: [String] = []
        if let sub = subLocality, !sub.isEmpty {
            parts.append(sub)
        }
        if let loc = locality, !loc.isEmpty, loc != subLocality {
            parts.append(loc)
        }
        if let area = administrativeArea, !area.isEmpty, area != locality {
            parts.append(area)
        }
        return parts.isEmpty ? (place.name ?? locality ?? administrativeArea) : parts.joined(separator: ", ")
    }
}

extension LocationService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            resolveLocationContinuation(with: locations.last, error: nil)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resolveLocationContinuation(with: nil, error: error)
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard manager.authorizationStatus != .notDetermined, let cont = authContinuation else { return }
            authContinuation = nil
            cont.resume()
        }
    }
}
