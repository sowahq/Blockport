import BlockportShared

/// A named combination of render sharpness and frame rate, so the main
/// screen offers one choice instead of several technical settings.
enum PerformancePreset: String, CaseIterable, Identifiable {
    case quality, balanced, performance, saver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quality: String(localized: "Quality")
        case .balanced: String(localized: "Balanced")
        case .performance: String(localized: "Performance")
        case .saver: String(localized: "Battery Saver")
        }
    }

    var detail: String {
        switch self {
        case .quality: String(localized: "Retina sharpness, up to 120 fps")
        case .balanced: String(localized: "High sharpness, up to 120 fps")
        case .performance: String(localized: "Medium sharpness, 60 fps")
        case .saver: String(localized: "Low sharpness, 30 fps")
        }
    }

    var symbol: String {
        switch self {
        case .quality: "sparkles"
        case .balanced: "scalemass"
        case .performance: "bolt"
        case .saver: "leaf"
        }
    }

    var renderScale: Double? {
        switch self {
        case .quality: nil
        case .balanced: 1.5
        case .performance: 1.25
        case .saver: 1
        }
    }

    var frameRate: Int? {
        switch self {
        case .quality, .balanced: nil
        case .performance: 60
        case .saver: 30
        }
    }

    /// The preset `settings` matches, or `nil` for custom settings.
    static func matching(_ settings: LaunchSettings) -> PerformancePreset? {
        allCases.first { $0.renderScale == settings.renderScale && $0.frameRate == settings.frameRate }
    }

    func apply(to settings: inout LaunchSettings) {
        settings.renderScale = renderScale
        settings.frameRate = frameRate
    }
}
