//
//  WeatherData.swift
//  SparkSatelliteWeather
//
//  Open-Meteo API DTOs (OpenMeteoResponse, HourlyWeather, DailyWeather, CurrentWeather),
//  domain models for display (DayForecast, HourForecast), and WeatherCondition (labels + SF Symbol names).
//

import Foundation

/// Response from Open-Meteo forecast API (current + daily + hourly).
struct OpenMeteoResponse: Codable {
    let latitude: Double
    let longitude: Double
    let current: CurrentWeather
    let daily: DailyWeather?
    let hourly: HourlyWeather?
}

/// Hourly forecast arrays from API.
struct HourlyWeather: Codable {
    let time: [String]
    let temperature2m: [Double]
    let weatherCode: [Int]
    let precipitationProbability: [Int?]?
    let windSpeed10m: [Double?]?
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
        case precipitationProbability = "precipitation_probability"
        case windSpeed10m = "wind_speed_10m"
    }
    
    func toHourForecasts() -> [HourForecast] {
        let count = min(time.count, temperature2m.count, weatherCode.count)
        let precip = precipitationProbability ?? []
        let wind = windSpeed10m ?? []
        return (0..<count).map { i in
            HourForecast(
                time: time[i],
                temperature: temperature2m[i],
                weatherCode: weatherCode[i],
                precipitationProbability: precip.indices.contains(i) ? precip[i] : nil,
                windSpeed10m: wind.indices.contains(i) ? wind[i] : nil
            )
        }
    }
}

/// Single hour forecast for display.
struct HourForecast {
    let time: String       // "2025-02-16T14:00"
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int?
    let windSpeed10m: Double?
    
    /// Short label in 12-hour AM/PM style: "10AM", "2PM", etc.
    var hourLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone.current
        guard let d = formatter.date(from: time) else { return time }
        let out = DateFormatter()
        out.dateFormat = "ha"
        out.timeZone = TimeZone.current
        out.locale = Locale(identifier: "en_US_POSIX")
        return out.string(from: d)
    }
    
    /// Parsed date in the given timezone (for comparison).
    func date(in timeZone: TimeZone = TimeZone(identifier: "Pacific/Auckland")!) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = timeZone
        return formatter.date(from: time)
    }
    
    /// Remaining hours for today starting from the current hour (first slot is "now").
    static func remainingHoursToday(from all: [HourForecast], timeZone: TimeZone = TimeZone(identifier: "Pacific/Auckland")!) -> [HourForecast] {
        var cal = Calendar.current
        cal.timeZone = timeZone
        let now = Date()
        let startOfCurrentHour = cal.date(bySetting: .second, value: 0, of: now).flatMap { cal.date(bySetting: .minute, value: 0, of: $0) } ?? now
        return all.filter { hour in
            guard let d = hour.date(in: timeZone) else { return false }
            return d >= startOfCurrentHour && cal.isDate(d, inSameDayAs: now)
        }
    }
    
    /// All 24 hours for a specific date (00:00–23:00), sorted by time.
    static func hoursForDate(_ dateString: String, from all: [HourForecast]) -> [HourForecast] {
        let prefix = dateString + "T"
        return all
            .filter { $0.time.hasPrefix(prefix) }
            .sorted { $0.time < $1.time }
    }
}

/// Daily forecast arrays from API (same-length arrays).
struct DailyWeather: Codable {
    let time: [String]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let weatherCode: [Int]
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case weatherCode = "weather_code"
    }
    
    /// Convert to a list of day items (today + next 6 days).
    func toDayForecasts() -> [DayForecast] {
        let count = min(time.count, temperature2mMax.count, temperature2mMin.count, weatherCode.count)
        return (0..<count).map { i in
            DayForecast(
                date: time[i],
                maxTemp: temperature2mMax[i],
                minTemp: temperature2mMin[i],
                weatherCode: weatherCode[i]
            )
        }
    }
}

/// Single day forecast for display.
struct DayForecast {
    let date: String       // "2025-02-16"
    let maxTemp: Double
    let minTemp: Double
    let weatherCode: Int
    
    /// Short label: "Today", "Mon", "Tue", etc.
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        guard let d = formatter.date(from: date) else { return date }
        let cal = Calendar.current
        if cal.isDateInToday(d) { return "Today" }
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        dayFormatter.timeZone = TimeZone.current
        return dayFormatter.string(from: d)
    }
}

struct CurrentWeather: Codable {
    let time: String
    let temperature2m: Double
    let relativeHumidity2m: Int?
    let weatherCode: Int
    let windSpeed10m: Double?
    let windDirection10m: Int?
    let apparentTemperature: Double?
    
    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case weatherCode = "weather_code"
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
        case apparentTemperature = "apparent_temperature"
    }
}

/// WMO weather code → SF Symbol name for icons.
/// Full WMO code descriptions (for reference when mapping):
/// 0 Clear sky | 1 Mainly clear | 2 Partly cloudy | 3 Overcast
/// 45 Fog | 48 Depositing rime fog
/// 51 Light drizzle | 53 Moderate drizzle | 55 Dense drizzle | 56–57 Freezing drizzle
/// 61 Slight rain | 63 Moderate rain | 65 Heavy rain | 66–67 Freezing rain
/// 71,73,75 Snow fall | 77 Snow grains
/// 80 Slight rain showers | 81 Moderate rain showers | 82 Violent rain showers
/// 85–86 Snow showers | 95 Thunderstorm | 96,99 Thunderstorm with hail
enum WeatherCondition {
    static func sfSymbolName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...67: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}
