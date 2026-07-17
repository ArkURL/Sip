//
//  SipTheme.swift
//  Sip
//
//  Lightweight visual tokens — keep the app native, with a soft “water” accent.
//

import SwiftUI

enum SipTheme {
    /// Primary water accent (matches app icon / marketing cyan).
    static let accent = Color.cyan

    /// Slightly deeper teal for gradients and emphasis.
    static let accentDeep = Color(red: 0.12, green: 0.62, blue: 0.68)

    /// Goal-reached: same family as accent, not pure system green.
    static let success = Color(red: 0.22, green: 0.72, blue: 0.55)

    static var ringGradient: AngularGradient {
        AngularGradient(
            colors: [
                accent.opacity(0.85),
                accentDeep,
                accent,
                accent.opacity(0.9)
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    static var successRingGradient: AngularGradient {
        AngularGradient(
            colors: [
                success.opacity(0.75),
                accentDeep.opacity(0.9),
                success,
                success.opacity(0.85)
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    static let cornerRadius: CGFloat = 10
    static let chipRadius: CGFloat = 8
}
