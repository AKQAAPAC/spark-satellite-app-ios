//
//  SparkTheme.swift
//  SparkSatelliteWeather
//
//  Tokens from Spark Generative Commerce design system
//  (Figma BAEZNkIwx845LdB2Msfhat — Primitives / Color / Spacing / Radius / Typography).
//

import SwiftUI

enum SparkTheme {

    enum Colors {
        /// spark/focus-bg — `#1A0831` (dark PLP page)
        static let bgCanvas = Color("SparkBgCanvas")
        /// color/bg/brand — `#400E7D`
        static let bgBrand = Color("SparkBgBrand")
        /// color/bg/plp-plan — `#350570`
        static let bgPlan = Color("SparkBgPlan")
        /// color/bg/primary-subtle — `#E6DDFD`
        static let bgPrimarySubtle = Color("SparkBgPrimarySubtle")
        /// color/text/inverse
        static let textInverse = Color("SparkTextInverse")
        /// spark/primary-subtle on dark plan cards
        static let textOnDark = Color("SparkTextOnDark")
        /// color/cta/cyan — `#2DF4E4`
        static let ctaCyan = Color("SparkCtaCyan")
        /// color/cta/submit — `#8950DA`
        static let ctaSubmit = Color("SparkCtaSubmit")
        /// Selected / current-state wash. `color/cta/cyan` on `color/bg/plp-plan`.
        static let selectedFill = Color("SparkCtaCyan").opacity(0.28)
    }

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

extension View {
    func sparkPlanCard(radius: CGFloat = SparkTheme.Radius.md, padding: CGFloat = SparkTheme.Spacing.card) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(SparkTheme.Colors.bgPlan)
            )
    }
}
