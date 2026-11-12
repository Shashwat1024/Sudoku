import SwiftUI

struct Theme: Identifiable, Sendable {
    let id: String
    /// nil = follow the system light/dark setting.
    let scheme: ColorScheme?
    /// nil = default system background.
    let background: Color?
    let board: Color
    let accent: Color
    let given: Color
    let line: Color
    let lineThick: Color
    let peer: Color

    var name: String { id }

    /// Colour shown in the theme picker swatch.
    var swatch: Color { background ?? Color.gray.opacity(0.2) }

    static let classic = Theme(
        id: "Classic", scheme: nil, background: nil,
        board: .clear, accent: .blue, given: .primary,
        line: Color.secondary.opacity(0.5), lineThick: .primary,
        peer: Color.secondary.opacity(0.15)
    )

    static let paper = Theme(
        id: "Paper", scheme: .light,
        background: Color(red: 0.96, green: 0.92, blue: 0.83),
        board: Color(red: 0.99, green: 0.97, blue: 0.92),
        accent: Color(red: 0.62, green: 0.32, blue: 0.14),
        given: Color(red: 0.20, green: 0.15, blue: 0.10),
        line: Color(red: 0.62, green: 0.55, blue: 0.45).opacity(0.5),
        lineThick: Color(red: 0.30, green: 0.22, blue: 0.14),
        peer: Color(red: 0.62, green: 0.32, blue: 0.14).opacity(0.10)
    )

    static let sunset = Theme(
        id: "Sunset", scheme: .light,
        background: Color(red: 1.00, green: 0.91, blue: 0.85),
        board: Color(red: 1.00, green: 0.97, blue: 0.94),
        accent: Color(red: 0.88, green: 0.30, blue: 0.22),
        given: Color(red: 0.30, green: 0.15, blue: 0.15),
        line: Color(red: 0.75, green: 0.55, blue: 0.50).opacity(0.5),
        lineThick: Color(red: 0.45, green: 0.20, blue: 0.20),
        peer: Color(red: 0.95, green: 0.55, blue: 0.35).opacity(0.14)
    )

    static let ocean = Theme(
        id: "Ocean", scheme: .light,
        background: Color(red: 0.86, green: 0.94, blue: 0.98),
        board: Color(red: 0.96, green: 0.99, blue: 1.00),
        accent: Color(red: 0.00, green: 0.45, blue: 0.68),
        given: Color(red: 0.07, green: 0.20, blue: 0.30),
        line: Color(red: 0.45, green: 0.62, blue: 0.72).opacity(0.5),
        lineThick: Color(red: 0.08, green: 0.28, blue: 0.42),
        peer: Color(red: 0.00, green: 0.45, blue: 0.68).opacity(0.10)
    )

    static let midnight = Theme(
        id: "Midnight", scheme: .dark,
        background: Color(red: 0.04, green: 0.06, blue: 0.13),
        board: Color(red: 0.08, green: 0.11, blue: 0.21),
        accent: Color(red: 0.47, green: 0.66, blue: 1.00),
        given: Color(red: 0.88, green: 0.91, blue: 1.00),
        line: Color(red: 0.45, green: 0.52, blue: 0.75).opacity(0.35),
        lineThick: Color(red: 0.60, green: 0.68, blue: 0.95),
        peer: Color(red: 0.47, green: 0.66, blue: 1.00).opacity(0.10)
    )

    static let forest = Theme(
        id: "Forest", scheme: .dark,
        background: Color(red: 0.06, green: 0.12, blue: 0.09),
        board: Color(red: 0.09, green: 0.18, blue: 0.13),
        accent: Color(red: 0.45, green: 0.85, blue: 0.55),
        given: Color(red: 0.88, green: 0.96, blue: 0.88),
        line: Color(red: 0.45, green: 0.65, blue: 0.50).opacity(0.35),
        lineThick: Color(red: 0.60, green: 0.80, blue: 0.65),
        peer: Color(red: 0.45, green: 0.85, blue: 0.55).opacity(0.10)
    )

    static let slate = Theme(
        id: "Slate", scheme: .dark,
        background: Color(red: 0.11, green: 0.11, blue: 0.12),
        board: Color(red: 0.16, green: 0.16, blue: 0.18),
        accent: Color(red: 1.00, green: 0.62, blue: 0.20),
        given: Color(red: 0.93, green: 0.93, blue: 0.95),
        line: Color(red: 0.55, green: 0.55, blue: 0.60).opacity(0.35),
        lineThick: Color(red: 0.75, green: 0.75, blue: 0.80),
        peer: Color(red: 1.00, green: 0.62, blue: 0.20).opacity(0.10)
    )

    static let all: [Theme] = [.classic, .paper, .sunset, .ocean, .midnight, .forest, .slate]

    static func named(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .classic
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.classic
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
