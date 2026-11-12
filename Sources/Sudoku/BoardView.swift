import SudokuCore
import SwiftUI

struct BoardView: View {
    let game: Game
    let showMistakes: Bool
    let highlightSame: Bool
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
                                CellView(
                                    game: game, index: r * 9 + c, size: cell,
                                    showMistakes: showMistakes, highlightSame: highlightSame
                                )
                                .frame(width: cell, height: cell)
                                .contentShape(Rectangle())
                                .onTapGesture { game.select(r * 9 + c) }
                            }
                        }
                    }
                }
                .opacity(game.isPaused || game.isGenerating ? 0 : 1)

                GridLines(thick: false).stroke(theme.line, lineWidth: 0.5)
                    .allowsHitTesting(false)
                GridLines(thick: true).stroke(theme.lineThick, lineWidth: 2)
                    .allowsHitTesting(false)

                if game.isGenerating {
                    BoardCover {
                        ProgressView()
                        Text("Generating puzzle…").font(.subheadline).foregroundStyle(.secondary)
                    }
                } else if game.isPaused {
                    BoardCover {
                        Image(systemName: "pause.circle").font(.system(size: 48))
                        Text("Paused").font(.title2.bold())
                        Text("Tap to resume").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .onTapGesture { game.resume() }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Opaque panel drawn over the board (pause, generating, and later states).
struct BoardCover<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Rectangle().fill(theme.background ?? Color.clear)
            Rectangle().fill(.background).opacity(theme.background == nil ? 1 : 0)
            VStack(spacing: 8) { content }
                .padding(28)
                .glassSurface(RoundedRectangle(cornerRadius: 28, style: .continuous), interactive: false)
        }
        .contentShape(Rectangle())
    }
}

struct CellView: View {
    let game: Game
    let index: Int
    let size: CGFloat
    let showMistakes: Bool
    let highlightSame: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        let value = game.values[index]
        ZStack {
            background
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: size * 0.52, weight: game.isGiven(index) ? .medium : .regular))
                    .foregroundStyle(textColor)
            } else if !game.notes[index].isEmpty {
                notesGrid
            }
        }
    }

    private var background: some View {
        var color = Color.clear
        if let s = game.selected {
            if s == index {
                color = theme.accent.opacity(0.35)
            } else if highlightSame && game.values[s] != 0 && game.values[s] == game.values[index] {
                color = theme.accent.opacity(0.22)
            } else if game.isPeer(s, index) {
                color = theme.peer
            }
        }
        if let info = game.hintInfo {
            switch info.kind {
            case .mistake:
                if info.cells.contains(index) { color = Color.red.opacity(0.30) }
            case .technique, .guess:
                if info.target == index {
                    color = Color.orange.opacity(0.50)
                } else if info.cells.contains(index) {
                    color = Color.orange.opacity(0.25)
                }
            case .ok:
                break
            }
        }
        return Rectangle().fill(color)
    }

    private var textColor: Color {
        if showMistakes && game.isWrong(index) { return .red }
        return game.isGiven(index) ? theme.given : theme.accent
    }

    private var notesGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let n = r * 3 + c + 1
                        Text(game.notes[index].contains(n) ? "\(n)" : " ")
                            .font(.system(size: size * 0.26))
                            .foregroundStyle(.secondary)
                            .frame(width: size / 3, height: size / 3)
                    }
                }
            }
        }
    }
}

struct GridLines: Shape {
    let thick: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = rect.width / 9
        for i in 0...9 where (i % 3 == 0) == thick {
            let x = CGFloat(i) * step
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
            p.move(to: CGPoint(x: 0, y: x))
            p.addLine(to: CGPoint(x: rect.width, y: x))
        }
        return p
    }
}
