import SwiftUI

/// Lightweight palette so the extension has no asset-catalog color dependencies.
enum Theme {
    static let background = Color(red: 0.09, green: 0.10, blue: 0.14)
    static let surface = Color(red: 0.15, green: 0.16, blue: 0.21)
    static let accent = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let positive = Color(red: 0.30, green: 0.80, blue: 0.52)
    static let warning = Color(red: 0.98, green: 0.66, blue: 0.25)
    static let danger = Color(red: 0.93, green: 0.36, blue: 0.40)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)

    static let boardLight = Color(red: 0.86, green: 0.80, blue: 0.66)
    static let boardDark = Color(red: 0.42, green: 0.30, blue: 0.22)
    static let redPiece = Color(red: 0.86, green: 0.28, blue: 0.30)
    static let blackPiece = Color(red: 0.12, green: 0.12, blue: 0.16)
}
