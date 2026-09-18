//
//  StormMapView.swift
//  SparkSatelliteWeather
//

import SwiftUI
import MapKit
import CoreLocation
import UIKit

/// Shown only when connectivity == .good.
struct StormMapView: View {

    @Environment(\.sparkColors) private var colors

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
            .foregroundStyle(colors.textInverse)
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
                                    .tint(colors.ctaCyan)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: Self.mapHeight)
                        .clipShape(RoundedRectangle(cornerRadius: SparkTheme.Radius.sm, style: .continuous))
                        .allowsHitTesting(false)
                    } else {
                        ProgressView()
                            .tint(colors.ctaCyan)
                    }
                }
                if !frames.isEmpty {
                    rainMapSliderView
                }
                HStack(spacing: 6) {
                    if let time = selectedFrameTime {
                        Text(Self.timeFormatter.string(from: time))
                            .font(SparkTheme.Typography.micro)
                            .foregroundStyle(colors.textOnDark)
                    }
                    Text("·")
                        .foregroundStyle(colors.textOnDark.opacity(0.7))
                    Text("Radar · RainViewer")
                        .font(SparkTheme.Typography.micro)
                        .foregroundStyle(colors.textOnDark.opacity(0.8))
                }
            } else {
                Text("No location found")
                    .font(SparkTheme.Typography.body)
                    .foregroundStyle(colors.textInverse)
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
                .foregroundStyle(colors.textOnDark)
            SparkCyanSlider(
                value: Binding(
                    get: { count > 0 ? Double(selectedFrameIndex) : 0 },
                    set: { selectedFrameIndex = min(count - 1, max(0, Int($0.rounded()))) }
                ),
                range: 0...max(0, range),
                accent: colors.ctaCyan,
                track: colors.textOnDark.opacity(0.35)
            )
            Text("Newer")
                .font(SparkTheme.Typography.micro)
                .foregroundStyle(colors.textOnDark)
        }
    }

    private func updateMapPosition() {
        guard let coord = coordinate else { return }
        let region = MKCoordinateRegion(center: coord, span: Self.mapSpan)
        mapPosition = .region(region)
    }
}

/// Cyan thumb only (`SparkColors.ctaCyan`); track uses a neutral theme line on both sides.
private struct SparkCyanSlider: UIViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var accent: Color
    var track: Color

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(max(range.upperBound, range.lowerBound))
        if slider.value != Float(value) {
            slider.value = Float(value)
        }
        slider.minimumTrackTintColor = UIColor(track)
        slider.maximumTrackTintColor = UIColor(track)
        slider.thumbTintColor = UIColor(accent)
    }

    final class Coordinator: NSObject {
        private var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: UISlider) {
            value.wrappedValue = Double(sender.value)
        }
    }
}
