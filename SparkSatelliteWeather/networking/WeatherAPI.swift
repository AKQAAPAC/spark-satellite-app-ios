//
//  WeatherAPI.swift
//  SparkSatelliteWeather
//

import Foundation
import os

struct WeatherAPI {
    
    private static let log = Logger(subsystem: "com.akqa.SparkSatelliteWeather", category: "WeatherAPI")
    
    private static func weatherURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,wind_direction_10m,apparent_temperature"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }
    
    private static func weatherURLMinimal(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        return components?.url
    }
    
    enum Error: Swift.Error {
        case badURL
        case badResponse
    }
    
    /// Fetches current weather + daily + hourly forecast (one request) for the given coordinates.
    static func fetchWeather(latitude: Double, longitude: Double) async throws -> (current: CurrentWeather, daily: [DayForecast], hourly: [HourForecast]) {
        let lat = latitude
        let lon = longitude
        guard let url = weatherURL(latitude: lat, longitude: lon) else {
            Self.log.error("Invalid weather URL")
            throw Error.badURL
        }
        
        let (data, response) = try await NetworkURLSessionHTTPClient.get(from: url, timeout: 30)
        
        guard (200..<300).contains(response.statusCode) else {
            Self.log.error("Weather API HTTP \(response.statusCode)")
            throw Error.badResponse
        }
        
        let decoder = JSONDecoder()
        let parsed = try decoder.decode(OpenMeteoResponse.self, from: data)
        Self.log.debug("Weather: \(parsed.current.temperature2m)°C, code \(parsed.current.weatherCode)")
        
        let daily = parsed.daily?.toDayForecasts() ?? []
        let hourly = parsed.hourly?.toHourForecasts() ?? []
        return (parsed.current, daily, hourly)
    }
    
    /// Minimal fetch for satellite/low: current + daily only. No hourly – keeps the call light.
    static func fetchWeatherMinimal(latitude: Double, longitude: Double) async throws -> (current: CurrentWeather, daily: [DayForecast]) {
        guard let url = weatherURLMinimal(latitude: latitude, longitude: longitude) else {
            Self.log.error("Invalid minimal weather URL")
            throw Error.badURL
        }
        let (data, response) = try await NetworkURLSessionHTTPClient.get(from: url, timeout: 30)
        guard (200..<300).contains(response.statusCode) else {
            Self.log.error("Weather API HTTP \(response.statusCode)")
            throw Error.badResponse
        }
        let decoder = JSONDecoder()
        let parsed = try decoder.decode(OpenMeteoResponse.self, from: data)
        let daily = parsed.daily?.toDayForecasts() ?? []
        Self.log.debug("Minimal weather: \(parsed.current.temperature2m)°C")
        return (parsed.current, daily)
    }
}
