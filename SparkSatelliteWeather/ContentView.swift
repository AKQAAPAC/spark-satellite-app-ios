//
//  ContentView.swift
//  SparkSatelliteWeather
//

import SwiftUI
import CoreLocation

struct ContentView: View {

    @AppStorage(SparkAppearance.storageKey) private var appearanceRaw = SparkAppearance.dark.rawValue
    @State private var viewModel: WeatherViewModel

    private var appearance: SparkAppearance {
        SparkAppearance.fromStorage(appearanceRaw)
    }

    private var colors: SparkColors {
        SparkColors.palette(appearance)
    }

    init() {
        let vm = WeatherViewModel()
        NetworkPathService.shared.register(observer: vm)
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        ZStack {
            colors.bgCanvas.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .center, spacing: SparkTheme.Spacing.sm) {
                    statusBarView
                    weatherCardView
                    hourlyForecastView
                    detailsSectionView
                    themeToggle
                }
                .padding(.top, SparkTheme.Spacing.sm)
                .padding(.bottom, SparkTheme.Spacing.md)
            }
        }
        .sparkAppearance(appearance)
        .task {
            // Location + weather once on appear (same as Android ViewModel init). Refresh uses a fresh fix.
            await viewModel.requestWeather(forceRefreshLocation: false)
        }
    }
    
    private var statusBarView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: SparkTheme.Spacing.xs) {
                Text(viewModel.connectivity.description)
                    .font(SparkTheme.Typography.planLabel)
                    .foregroundStyle(colors.textInverse)
            }
            Spacer()
            refreshColumn
        }
        .padding(.horizontal, SparkTheme.Spacing.md)
        .padding(.vertical, SparkTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous)
                .fill(colors.bgPlan)
        )
        .padding(.horizontal, SparkTheme.Spacing.lg)
    }
    
    private var refreshColumn: some View {
        VStack(alignment: .trailing, spacing: SparkTheme.Spacing.xs) {
            Button(action: {
                Task { await viewModel.requestWeather(forceRefreshLocation: true) }
            }) {
                Text("Refresh")
                    .font(SparkTheme.Typography.planLabel)
                    .foregroundStyle(colors.bgBrand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, SparkTheme.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(colors.ctaCyan)
                    )
            }
            .buttonStyle(.plain)
            if let at = viewModel.lastWeatherFetchAt {
                Text(at.formatted(date: .abbreviated, time: .standard))
                    .font(SparkTheme.Typography.micro)
                    .foregroundStyle(colors.textOnDark)
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
                    .tint(colors.ctaCyan)
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity)
                    .sparkPlanCard()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, SparkTheme.Spacing.lg)
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
        return HStack(alignment: .top, spacing: SparkTheme.Spacing.sm) {
            VStack(spacing: 2) {
                ForEach(viewModel.dailyForecasts, id: \.date) { day in
                    weekDayCell(day: day, isSelected: viewModel.selectedDate == day.date || (viewModel.selectedDate == nil && day.date == viewModel.todayDateString))
                        .onTapGesture { viewModel.selectDay(day.date) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: SparkTheme.Spacing.xs) {
                Text(viewModel.noLocation ? "No location found" : (viewModel.locationService.placeName ?? "Current location"))
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(colors.textOnDark)
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: WeatherCondition.sfSymbolName(for: selectedDay.weatherCode))
                    .font(.system(size: 28))
                    .foregroundStyle(colors.textOnDark)
                    .frame(width: 28, height: 28)
                Text(String(format: "%.0f°", isToday && current != nil ? current!.temperature2m : selectedDay.maxTemp))
                    .font(SparkTheme.Typography.display)
                    .foregroundStyle(colors.textOnDark)
                Text(String(format: "Low %.0f° · High %.0f°", selectedDay.minTemp, selectedDay.maxTemp))
                    .font(SparkTheme.Typography.sectionDesc)
                    .foregroundStyle(colors.textInverse.opacity(0.85))
                if let low = precipLow, let high = precipHigh {
                    Text(low == high ? "\(low)% precipitation" : "Precip \(low)–\(high)%")
                        .font(SparkTheme.Typography.sectionDesc)
                        .foregroundStyle(colors.textInverse.opacity(0.85))
                }
                if let low = windLow, let high = windHigh {
                    Text(low == high ? String(format: "%.0f km/h wind", low) : String(format: "Wind %.0f–%.0f km/h", low, high))
                        .font(SparkTheme.Typography.sectionDesc)
                        .foregroundStyle(colors.textInverse.opacity(0.85))
                }
            }
            .frame(width: 128, alignment: .trailing)
        }
        .sparkPlanCard(padding: SparkTheme.Spacing.md)
    }
    
    private func weekDayCell(day: DayForecast, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Text(day.dayLabel)
                .font(SparkTheme.Typography.sectionDesc)
                .foregroundStyle(colors.textInverse.opacity(0.9))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Image(systemName: WeatherCondition.sfSymbolName(for: day.weatherCode))
                .font(.system(size: 14))
                .foregroundStyle(colors.textOnDark)
                .frame(width: 16, height: 16, alignment: .center)
            Text(String(format: "%.0f°–%.0f°", day.minTemp, day.maxTemp))
                .font(SparkTheme.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(colors.textInverse)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.leading, 10)
        .padding(.trailing, SparkTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: SparkTheme.Spacing.sm, style: .continuous)
                .fill(isSelected ? colors.selectedFill : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private var noLocationCardView: some View {
        Text("No location found")
            .font(SparkTheme.Typography.body)
            .foregroundStyle(colors.textOnDark)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .sparkPlanCard()
    }
    
    private var noConnectionCardView: some View {
        Text("No connection. Weather when cellular or satellite is available.")
            .font(SparkTheme.Typography.body)
            .foregroundStyle(colors.textOnDark)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .sparkPlanCard()
    }
    
    private var hourlyForecastView: some View {
        Group {
            if viewModel.connectivity == .none {
                Text("No connection.")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(colors.textInverse.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SparkTheme.Spacing.md)
            } else if viewModel.displayHours.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: SparkTheme.Spacing.sm) {
                        ForEach(Array(viewModel.displayHours.enumerated()), id: \.element.time) { index, hour in
                            hourTile(hour: hour, isNow: viewModel.isShowingToday && index == 0)
                        }
                    }
                    .padding(.horizontal, SparkTheme.Spacing.lg)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func hourTile(hour: HourForecast, isNow: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(isNow ? "Now" : hour.hourLabel)
                .font(SparkTheme.Typography.caption)
                .foregroundStyle(colors.textInverse.opacity(0.9))
            Image(systemName: WeatherCondition.sfSymbolName(for: hour.weatherCode))
                .font(.system(size: 18))
                .foregroundStyle(colors.textOnDark)
                .frame(width: 20, height: 20, alignment: .center)
            Text(String(format: "%.0f°", hour.temperature))
                .font(SparkTheme.Typography.planLabel)
                .foregroundStyle(colors.textOnDark)
            if let precip = hour.precipitationProbability {
                Text("\(precip)%")
                    .font(SparkTheme.Typography.micro)
                    .foregroundStyle(colors.textInverse.opacity(0.8))
            }
            if let wind = hour.windSpeed10m {
                Text(String(format: "%.0f km/h", wind))
                    .font(SparkTheme.Typography.micro)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(colors.textInverse.opacity(0.8))
            }
        }
        .frame(width: 62)
        .padding(.vertical, SparkTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous)
                .fill(colors.bgPlan)
        )
        .overlay {
            if isNow {
                RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous)
                    .fill(colors.selectedFill)
            }
        }
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
        .padding(.horizontal, SparkTheme.Spacing.lg)
    }
    
    /// Visible only when connectivity == .good.
    private var stormMapView: some View {
        StormMapView(coordinate: viewModel.locationService.lastCoordinate)
    }
    
    private var weatherErrorView: some View {
        VStack(spacing: SparkTheme.Spacing.sm) {
            Image(systemName: "cloud.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(colors.textOnDark)
                .frame(width: 36, height: 36)
            Text("Unable to load weather")
                .font(SparkTheme.Typography.productName)
        }
        .foregroundStyle(colors.textInverse)
        .frame(maxWidth: .infinity)
        .sparkPlanCard()
    }
    
    private var themeToggle: some View {
        HStack(spacing: SparkTheme.Spacing.md) {
            themeTabItem(.light, symbol: "sun.max")
            themeTabItem(.dark, symbol: "moon")
        }
        .padding(12)
        .background(
            Capsule(style: .continuous)
                .fill(colors.bgBrand)
        )
        .padding(.top, SparkTheme.Spacing.xs)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Switches between light and dark Spark themes")
    }

    private func themeTabItem(_ value: SparkAppearance, symbol: String) -> some View {
        let isActive = appearance == value
        return Button {
            appearanceRaw = value.rawValue
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .frame(width: 44, height: 44)
                .background {
                    if isActive {
                        Circle()
                            .fill(colors.ctaSubmit)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == .light ? "Light theme" : "Dark theme")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func detailsPlaceholderView(_ text: String) -> some View {
        Text(text)
            .font(SparkTheme.Typography.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(colors.textInverse)
            .frame(maxWidth: .infinity)
            .sparkPlanCard()
    }
    
}

#Preview {
    ContentView()
        .sparkAppearance(.dark)
}
