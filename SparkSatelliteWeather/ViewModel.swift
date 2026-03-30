//
//  ViewModel.swift
//  SparkSatelliteWeather
//

import SwiftUI
import Network
import CoreLocation
import os

/// connectivity drives minimal vs full fetch and rain map visibility.
@Observable
final class WeatherViewModel: NetworkPathServiceObserver {

    static private let log = Logger(subsystem: "com.akqa.SparkSatelliteWeather", category: "WeatherViewModel")

    var connectivity: Connectivity = .good

    let locationService = LocationService()

    var noLocation: Bool = false

    var currentWeather: CurrentWeather?
    var dailyForecasts: [DayForecast] = []
    var hourlyForecasts: [HourForecast] = []
    var weatherLoadError: Bool = false

    var lastWeatherFetchAt: Date?

    var selectedDate: String?

    var todayDateString: String? {
        dailyForecasts.first?.date
    }

    var isShowingToday: Bool {
        guard let selected = selectedDate else { return true }
        return selected == todayDateString
    }

    var selectedDayForecast: DayForecast? {
        if let date = selectedDate {
            return dailyForecasts.first { $0.date == date }
        }
        return dailyForecasts.first
    }

    var displayHours: [HourForecast] {
        if isShowingToday {
            return HourForecast.remainingHoursToday(from: hourlyForecasts)
        }
        guard let date = selectedDate else { return [] }
        return HourForecast.hoursForDate(date, from: hourlyForecasts)
    }

    func selectDay(_ date: String) {
        selectedDate = date
    }

    func requestWeather(forceRefreshLocation: Bool = false) async {
        weatherLoadError = false
        noLocation = false
        let location = await locationService.requestLocation(forceRefresh: forceRefreshLocation)
        guard let loc = location else {
            noLocation = true
            currentWeather = nil
            dailyForecasts = []
            hourlyForecasts = []
            lastWeatherFetchAt = nil
            return
        }
        let lat = loc.0.latitude
        let lon = loc.0.longitude
        do {
            if connectivity == .none {
                let result = try await WeatherAPI.fetchWeatherMinimal(latitude: lat, longitude: lon)
                currentWeather = result.current
                dailyForecasts = result.daily
                hourlyForecasts = []
            } else {
                let result = try await WeatherAPI.fetchWeather(latitude: lat, longitude: lon)
                currentWeather = result.current
                dailyForecasts = result.daily
                hourlyForecasts = result.hourly
            }
            lastWeatherFetchAt = Date()
        } catch {
            Self.log.error("Failed to fetch weather: \(error)")
            weatherLoadError = true
            lastWeatherFetchAt = nil
        }
    }

    func networkPathDidUpdate(with path: NWPath) {
        connectivity = Connectivity(networkPath: path)
    }
}
