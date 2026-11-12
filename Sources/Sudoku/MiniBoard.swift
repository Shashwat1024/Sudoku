import SwiftUI

/// A read-only board for replays and heatmaps (not tied to a live `Game`).
struct MiniBoard: View {
    let puzzle: [Int]
    let values: [Int]
    var notes: [Set<Int>]?
    /// Cell to outline (e.g. the move just made).
    var highlight: Int?
    /// Per-cell heat 0...1; when set, cells are tinted by it.
    var heat: [Double]?
    /// Cells forming a highlighted pattern (technique examples and quizzes).
    var patternCells: Set<Int> = []
    /// The cell a deduction would fill, shown stronger than the pattern.
    var target: Int?
    /// Candidates to show struck out in red, per cell.
    var eliminated: [Int: Set<Int>] = [:]
    /// Size of pencil-mark digits relative to the cell.
    var noteScale: CGFloat = 0.26
    /// Editing support (scan review): tap handler, selection, clashes, shaky reads.
    var onTap: ((Int) -> Void)?
    var selected: Int?
    var conflicts: Set<Int> = []
    var uncertain: Set<Int> = []

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                Rectangle().fill(theme.board)
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { c in
                                cellView(r * 9 + c, size: cell)
                                    .frame(width: cell, height: cell)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap?(r * 9 + c) }
                            }
                        }
                    }
                }
                GridLines(thick: false).stroke(theme.line, lineWidth: 0.5)
                GridLines(thick: true).stroke(theme.lineThick, lineWidth: 2)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let value = values[i]
        let given = puzzle[i] != 0
        return ZStack {
            Rectangle().fill(background(i))
            if i == highlight {
                Rectangle().strokeBorder(theme.accent, lineWidth: 2)
            }
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: size * 0.52, weight: given ? .medium : .regular))
                    .foregroundStyle(given ? theme.given : theme.accent)
            } else if let n = notes?[i], !n.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<3, id: \.self) { c in
                                let d = r * 3 + c + 1
                                let gone = eliminated[i]?.contains(d) ?? false
                                Text(n.contains(d) ? "\(d)" : " ")
                                    .font(.system(size: size * noteScale, weight: gone ? .bold : .regular))
                                    .foregroundStyle(gone ? Color.red : Color.secondary)
                                    .frame(width: size / 3, height: size / 3)
                            }
                        }
                    }
                }
            }
        }
    }

    private func background(_ i: Int) -> Color {
        if conflicts.contains(i) { return Color.red.opacity(0.35) }
        if i == selected { return theme.accent.opacity(0.35) }
        if uncertain.contains(i) { return Color.yellow.opacity(0.40) }
        if let heat, puzzle[i] == 0 {
            // sqrt spreads the low end so quick cells are still distinguishable.
            let h = max(0, min(1, heat[i])).squareRoot()
            return theme.accent.opacity(0.06 + 0.74 * h)
        }
        if i == target { return Color.orange.opacity(0.50) }
        if patternCells.contains(i) { return Color.orange.opacity(0.25) }
        return .clear
    }
}
