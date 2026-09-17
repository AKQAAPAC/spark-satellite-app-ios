//
//  StormMapView.swift
//  SparkSatelliteWeather
//

import SwiftUI
import MapKit
import CoreLocation

/// Shown only when connectivity == .good.
struct StormMapView: View {

    var coordinate: CLLocationCoordinate2D?

    private static let mapHeight: CGFloat = 148
    private static let mapSpan = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone.current
        return f
    }()

    @State private var frames: [RainViewerAPI.RadarFrame] = []
    @State private var selectedFrameIndex: Int = 0
    @State private var mapPosition: MapCameraPosition = .automatic
    private var currentFrameURL: URL? {
        guard frames.indices.contains(selectedFrameIndex) else { return frames.last?.imageURL }
        return frames[selectedFrameIndex].imageURL
    }

    private var selectedFrameTime: Date? {
        guard frames.indices.contains(selectedFrameIndex) else { return frames.last?.time }
        return frames[selectedFrameIndex].time
    }

    var body: some View {
        VStack(spacing: SparkTheme.Spacing.sm) {
            HStack {
                Text("Today Rain Map")
                    .font(SparkTheme.Typography.productName)
                Spacer()
            }
            .foregroundStyle(SparkTheme.Colors.textInverse)
            if coordinate != nil {
                ZStack(alignment: .center) {
                    Map(position: $mapPosition, interactionModes: .zoom)
                        .mapStyle(.imagery)
                        .frame(height: Self.mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous))
                    if let url = currentFrameURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .opacity(0.82)
                            case .failure:
                                EmptyView()
                            case .empty:
                                ProgressView()
                                    .tint(SparkTheme.Colors.ctaCyan)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: Self.mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous))
                        .allowsHitTesting(false)
                    } else {
                        ProgressView()
                            .tint(SparkTheme.Colors.ctaCyan)
                    }
                }
                if !frames.isEmpty {
                    rainMapSliderView
                }
                HStack(spacing: 6) {
                    if let time = selectedFrameTime {
                        Text(Self.timeFormatter.string(from: time))
                            .font(SparkTheme.Typography.micro)
                            .foregroundStyle(SparkTheme.Colors.textOnDark)
                    }
                    Text("·")
                        .foregroundStyle(SparkTheme.Colors.textOnDark.opacity(0.7))
                    Text("Radar · RainViewer")
                        .font(SparkTheme.Typography.micro)
                        .foregroundStyle(SparkTheme.Colors.textOnDark.opacity(0.8))
                }
            } else {
                Text("No location found")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(SparkTheme.Colors.textInverse)
                    .frame(height: Self.mapHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .sparkPlanCard()
        .onAppear { updateMapPosition() }
        .onChange(of: coordinate?.latitude) { updateMapPosition() }
        .onChange(of: coordinate?.longitude) { updateMapPosition() }
        .task(id: coordinate.map { "\($0.latitude)-\($0.longitude)" } ?? "nil") {
            guard let coord = coordinate else {
                frames = []
                return
            }
            let list = await RainViewerAPI.radarFrames(latitude: coord.latitude, longitude: coord.longitude) ?? []
            frames = list
            selectedFrameIndex = max(0, list.count - 1)
        }
    }

    private var rainMapSliderView: some View {
        let count = frames.count
        let range = Double(max(0, count - 1))
        return HStack(spacing: 12) {
            Text("Older")
                .font(SparkTheme.Typography.micro)
                .foregroundStyle(SparkTheme.Colors.textOnDark)
            Slider(
                value: Binding(
                    get: { count > 0 ? Double(selectedFrameIndex) : 0 },
                    set: { selectedFrameIndex = min(count - 1, max(0, Int($0.rounded()))) }
                ),
                in: 0...max(0, range)
            )
            .tint(SparkTheme.Colors.ctaCyan)
            Text("Newer")
                .font(SparkTheme.Typography.micro)
                .foregroundStyle(SparkTheme.Colors.textOnDark)
        }
    }

    private func updateMapPosition() {
        guard let coord = coordinate else { return }
        let region = MKCoordinateRegion(center: coord, span: Self.mapSpan)
        mapPosition = .region(region)
    }
}
