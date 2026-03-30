//
//  ContentView.swift
//  SparkSatelliteWeather
//

import SwiftUI
import CoreLocation

struct ContentView: View {

    @State private var viewModel: WeatherViewModel

    init() {
        let vm = WeatherViewModel()
        NetworkPathService.shared.register(observer: vm)
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        ZStack {
            Color("background").ignoresSafeArea()
            VStack(alignment: .center, spacing: 32) {
                statusBarView
                weatherCardView
                hourlyForecastView
                detailsSectionView
                Spacer()
            }
            .padding(.top, 60)
            .padding(.bottom, 20)
        }
        .task {
            // Location + weather once on appear (same as Android ViewModel init). Refresh uses a fresh fix.
            await viewModel.requestWeather(forceRefreshLocation: false)
        }
    }
    
    private var statusBarView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.connectivity.description)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            refreshColumn
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.2))
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    
    private var refreshColumn: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button(action: {
                Task { await viewModel.requestWeather(forceRefreshLocation: true) }
            }) {
                Text("Refresh")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .underline()
            }
            .buttonStyle(.plain)
            if let at = viewModel.lastWeatherFetchAt {
                Text(at.formatted(date: .abbreviated, time: .standard))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
    
    private var weatherCardView: some View {
        Group {
            if viewModel.noLocation {
                noLocationCardView
            } else if viewModel.connectivity == .none {
                noConnectionCardView
            } else if viewModel.weatherLoadError {
                weatherErrorView
            } else if let day = viewModel.selectedDayForecast {
                firstCardContent(selectedDay: day)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .frame(minHeight: 160)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
    
    private func firstCardContent(selectedDay: DayForecast) -> some View {
        let isToday = viewModel.isShowingToday
        let current = viewModel.currentWeather
        let hours = viewModel.displayHours
        let precipValues = hours.compactMap(\.precipitationProbability)
        let precipLow = precipValues.min()
        let precipHigh = precipValues.max()
        let windValues = hours.compactMap(\.windSpeed10m)
        let windLow = windValues.min()
        let windHigh = windValues.max()
        return HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 6) {
                ForEach(viewModel.dailyForecasts, id: \.date) { day in
                    weekDayCell(day: day, isSelected: viewModel.selectedDate == day.date || (viewModel.selectedDate == nil && day.date == viewModel.todayDateString))
                        .onTapGesture { viewModel.selectDay(day.date) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                Text(viewModel.noLocation ? "No location found" : (viewModel.locationService.placeName ?? "Current location"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: WeatherCondition.sfSymbolName(for: selectedDay.weatherCode))
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.95))
                Text(String(format: "%.0f°", isToday && current != nil ? current!.temperature2m : selectedDay.maxTemp))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)
                Text(String(format: "High %.0f° · Low %.0f°", selectedDay.maxTemp, selectedDay.minTemp))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                if let low = precipLow, let high = precipHigh {
                    Text(low == high ? "\(low)% precipitation" : "Precip \(low)–\(high)%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                if let low = windLow, let high = windHigh {
                    Text(low == high ? String(format: "%.0f km/h wind", low) : String(format: "Wind %.0f–%.0f km/h", low, high))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 16)
        .foregroundStyle(.white)
    }
    
    private func weekDayCell(day: DayForecast, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(day.dayLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 40, alignment: .leading)
            Image(systemName: WeatherCondition.sfSymbolName(for: day.weatherCode))
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 20, alignment: .center)
            Spacer()
            Text(String(format: "%.0f° / %.0f°", day.maxTemp, day.minTemp))
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.2)) : nil)
        .contentShape(Rectangle())
    }
    
    private var noLocationCardView: some View {
        Text("No location found")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(24)
    }
    
    private var noConnectionCardView: some View {
        Text("No connection. Weather when cellular or satellite is available.")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(24)
    }
    
    private var hourlyForecastView: some View {
        Group {
            if viewModel.connectivity == .none {
                Text("No connection.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if viewModel.displayHours.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(viewModel.displayHours.enumerated()), id: \.element.time) { index, hour in
                                hourTile(hour: hour, isNow: viewModel.isShowingToday && index == 0)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 100)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private func hourTile(hour: HourForecast, isNow: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(isNow ? "Now" : hour.hourLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Image(systemName: WeatherCondition.sfSymbolName(for: hour.weatherCode))
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: 28, alignment: .center)
            Text(String(format: "%.0f°", hour.temperature))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            if let precip = hour.precipitationProbability {
                Text("\(precip)%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if let wind = hour.windSpeed10m {
                Text(String(format: "%.0f km/h", wind))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
    }
    
    private var detailsSectionView: some View {
        Group {
            if viewModel.noLocation {
                detailsPlaceholderView("No location found")
            } else if viewModel.connectivity == .none {
                detailsPlaceholderView("No network. Weather will update when connected.")
            } else if viewModel.connectivity == .low {
                detailsPlaceholderView("Rain map available when status is Good data.")
            } else {
                stormMapView
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
    }
    
    /// Visible only when connectivity == .good.
    private var stormMapView: some View {
        StormMapView(coordinate: viewModel.locationService.lastCoordinate)
    }
    
    private var weatherErrorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "cloud.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Unable to load weather")
                .font(.system(size: 16, weight: .medium))
        }
        .padding(24)
        .foregroundStyle(.secondary)
    }
    
    private func detailsPlaceholderView(_ text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.15))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding()
        }
    }
    
}

#Preview {
    ContentView()
}
