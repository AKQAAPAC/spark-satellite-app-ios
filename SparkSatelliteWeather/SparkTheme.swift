//
//  SparkTheme.swift
//  SparkSatelliteWeather
//
//  Tokens from Spark Generative Commerce design system
//  (Figma BAEZNkIwx845LdB2Msfhat — Primitives / Color / Spacing / Radius / Typography).
//

import SwiftUI
import UIKit

enum SparkAppearance: String {
    static let storageKey = "sparkColorScheme"

    case light
    case dark

    var colorScheme: ColorScheme { self == .light ? .light : .dark }

    static func fromStorage(_ raw: String) -> SparkAppearance {
        SparkAppearance(rawValue: raw) ?? .dark
    }
}

struct SparkColors: Equatable {
    let bgCanvas: Color
    let bgBrand: Color
    let bgPlan: Color
    let bgPrimarySubtle: Color
    let textInverse: Color
    let textOnDark: Color
    let ctaCyan: Color
    let ctaSubmit: Color

    var selectedFill: Color { ctaCyan.opacity(0.28) }

    static let light = SparkColors(
        bgCanvas: Color(sparkRed: 0xFF, green: 0xFF, blue: 0xFF),
        bgBrand: Color(sparkRed: 0x40, green: 0x0E, blue: 0x7D),
        bgPlan: Color(sparkRed: 0xEE, green: 0xED, blue: 0xF0),
        bgPrimarySubtle: Color(sparkRed: 0xE6, green: 0xDD, blue: 0xFD),
        textInverse: Color(sparkRed: 0x24, green: 0x24, blue: 0x2E),
        textOnDark: Color(sparkRed: 0x40, green: 0x0E, blue: 0x7D),
        ctaCyan: Color(sparkRed: 0x2D, green: 0xF4, blue: 0xE4),
        ctaSubmit: Color(sparkRed: 0x89, green: 0x50, blue: 0xDA)
    )

    static let dark = SparkColors(
        bgCanvas: Color(sparkRed: 0x1A, green: 0x08, blue: 0x31),
        bgBrand: Color(sparkRed: 0x40, green: 0x0E, blue: 0x7D),
        bgPlan: Color(sparkRed: 0x35, green: 0x05, blue: 0x70),
        bgPrimarySubtle: Color(sparkRed: 0xE6, green: 0xDD, blue: 0xFD),
        textInverse: Color(sparkRed: 0xFF, green: 0xFF, blue: 0xFF),
        textOnDark: Color(sparkRed: 0xE6, green: 0xDD, blue: 0xFD),
        ctaCyan: Color(sparkRed: 0x2D, green: 0xF4, blue: 0xE4),
        ctaSubmit: Color(sparkRed: 0x89, green: 0x50, blue: 0xDA)
    )

    static func palette(_ appearance: SparkAppearance) -> SparkColors {
        appearance == .light ? .light : .dark
    }
}

private struct SparkColorsKey: EnvironmentKey {
    static let defaultValue = SparkColors.dark
}

extension EnvironmentValues {
    var sparkColors: SparkColors {
        get { self[SparkColorsKey.self] }
        set { self[SparkColorsKey.self] = newValue }
    }
}

enum SparkTheme {

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let card: CGFloat = 18
    }

    enum Radius {
        static let sm: CGFloat = 16
        static let card: CGFloat = 21
        static let md: CGFloat = 24
        static let full: CGFloat = 999
    }

    /// SF Pro at the Figma type-scale sizes (Inter in the source file).
    enum Typography {
        /// Typography/PLP/Plan Price — 32 semibold
        static let display = Font.system(size: 32, weight: .semibold)
        /// Typography/Product/Name — 16 semibold
        static let productName = Font.system(.headline, design: .default).weight(.semibold)
        /// Typography/PLP/Plan Label — 14 semibold
        static let planLabel = Font.system(.subheadline, design: .default).weight(.semibold)
        /// Typography/Body/SM — 14 medium
        static let body = Font.system(.subheadline, design: .default).weight(.medium)
        /// Typography/PLP/Section Desc — 13 medium
        static let sectionDesc = Font.system(.footnote, design: .default).weight(.medium)
        /// 12 medium
        static let caption = Font.system(.caption, design: .default).weight(.medium)
        /// Typography/Label/Caption — 10 bold
        static let micro = Font.system(.caption2, design: .default).weight(.bold)
    }
}

private extension Color {
    init(sparkRed red: Int, green: Int, blue: Int) {
        self.init(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}

/// Keeps the system status bar (time, battery, signal) in sync with the in-app Spark theme.
enum SparkWindowAppearance {
    static func apply(_ appearance: SparkAppearance) {
        let style: UIUserInterfaceStyle = appearance == .dark ? .dark : .light
        DispatchQueue.main.async {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}

extension View {
    func sparkPlanCard(radius: CGFloat = SparkTheme.Radius.md, padding: CGFloat = SparkTheme.Spacing.card) -> some View {
        modifier(SparkPlanCardModifier(radius: radius, padding: padding))
    }

    func sparkAppearance(_ appearance: SparkAppearance) -> some View {
        let colors = SparkColors.palette(appearance)
        return self
            .environment(\.sparkColors, colors)
            .preferredColorScheme(appearance.colorScheme)
            .tint(colors.ctaCyan)
            .onAppear { SparkWindowAppearance.apply(appearance) }
            .onChange(of: appearance) { _, newValue in
                SparkWindowAppearance.apply(newValue)
            }
    }
}

private struct SparkPlanCardModifier: ViewModifier {
    @Environment(\.sparkColors) private var colors
    var radius: CGFloat
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(colors.bgPlan)
            )
    }
}
