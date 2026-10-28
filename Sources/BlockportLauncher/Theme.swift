import SwiftUI

/// Colours and metrics shared by the launcher views.
enum Theme {
    static let accent = Color(red: 0.16, green: 0.62, blue: 0.31)
    static let accentBright = Color(red: 0.36, green: 0.80, blue: 0.43)
    static let gold = Color(red: 0.95, green: 0.70, blue: 0.24)
    static let danger = Color(red: 0.86, green: 0.22, blue: 0.20)
    static let sky = [Color(red: 0.11, green: 0.16, blue: 0.29), Color(red: 0.20, green: 0.36, blue: 0.55)]
    static let grass = [Color(red: 0.30, green: 0.62, blue: 0.24), Color(red: 0.25, green: 0.54, blue: 0.21)]
    static let dirt = [Color(red: 0.45, green: 0.31, blue: 0.20), Color(red: 0.39, green: 0.27, blue: 0.17), Color(red: 0.34, green: 0.23, blue: 0.15)]
    static let stone = [Color(red: 0.36, green: 0.37, blue: 0.40), Color(red: 0.31, green: 0.32, blue: 0.35)]

    static let cornerRadius: CGFloat = 12
    static let heroWidth: CGFloat = 320
    static let contentPadding: CGFloat = 28
    static let windowSize = CGSize(width: 880, height: 580)
}
