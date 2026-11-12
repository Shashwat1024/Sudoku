import SudokuCore
import SwiftUI

/// The board screen. Navigation (home, settings) is handled by the parent.
struct GameScreen: View {
    let game: Game
    let onHome: () -> Void
    let onSettings: () -> Void
    let onReview: (GameRecord) -> Void

    @Environment(\.theme) private var theme

    @AppStorage(Pref.showMistakes) private var showMistakes = true
    @AppStorage(Pref.highlightSame) private var highlightSame = true
    @AppStorage(Pref.mistakeLimit) private var mistakeLimit = 0

    private var isZen: Bool { game.mode == .zen }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            statusBar.padding(.top, 12)
            if let ghost = game.ghostProgress {
                raceStrip(you: game.progress, ghost: ghost).padding(.top, 8)
            }
            Spacer(minLength: 12)
            BoardView(game: game, showMistakes: showMistakes, highlightSame: highlightSame)
            Spacer(minLength: 12)
            ControlsView(game: game)
            Spacer(minLength: 12)
            NumberPadView(game: game)
            Spacer(minLength: 8)
        }
        .padding()
        .sheet(isPresented: Binding(
            get: { game.hintInfo != nil },
            set: { if !$0 { game.dismissHint() } }
        )) {
            if let info = game.hintInfo {
                HintSheet(
                    info: info,
                    reveal: { game.revealHint() },
                    dismiss: { game.dismissHint() }
                )
                .tint(theme.accent)
                .preferredColorScheme(theme.scheme)
            }
        }
        .alert(
            resultTitle,
            isPresented: Binding(
                get: { (game.isComplete || game.isGameOver) && !game.resultAcknowledged },
                set: { if !$0 { game.acknowledgeResult() } }
            )
        ) {
            if game.isGameOver {
                Button("Try Again") { game.retry() }
            }
            Button("New Game") {
                game.newGame(game.difficulty, mode: game.mode == .zen ? .zen : .classic)
            }
            if let record = game.lastRecord {
                Button("Review") { onReview(record) }
            }
            Button("Home", role: .cancel) { onHome() }
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: Result alert

    private var resultTitle: String {
        if game.isGameOver { return "Game Over" }
        switch game.mode {
        case .zen: return "Beautifully done"
        case .daily: return "Daily complete!"
        case .classic: return "Solved!"
        }
    }

    private var resultMessage: String {
        var text = baseResultMessage
        if let race = game.ghostResult { text += " " + race }
        return text
    }

    private var baseResultMessage: String {
        if game.isGameOver { return "You reached the limit of \(mistakeLimit) mistakes." }
        switch game.mode {
        case .zen:
            return "\(game.difficulty.rawValue) solved. Take a breath."
        case .daily:
            let n = game.daily.currentStreak()
            let base = "\(game.difficulty.rawValue) in \(game.timeString)."
            // A puzzle finished after midnight no longer counts, so don't claim a streak.
            return n > 0 ? "\(base) That's a \(n)-day streak." : base
        case .classic:
            let m = game.mistakes
            return "\(game.difficulty.rawValue) in \(game.timeString) with \(m) mistake\(m == 1 ? "" : "s").\(game.lastWinWasBest ? " New best time!" : "")"
        }
    }

    // MARK: Bars

    private var modeTitle: String {
        switch game.mode {
        case .classic: return game.difficulty.rawValue
        case .daily: return "Daily · \(game.difficulty.rawValue)"
        case .zen: return "Zen · \(game.difficulty.rawValue)"
        }
    }

    private var topBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button { game.pause(); onHome() } label: {
                    Image(systemName: "house")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .glassSurface(Circle())
                }
                .buttonStyle(.plain)

                Text(modeTitle)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glassSurface(Capsule(), interactive: false)

                Spacer()

                Button { game.pause(); onSettings() } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .glassSurface(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Progress of you and the racing ghost, side by side.
    private func raceStrip(you: Double, ghost: Double) -> some View {
        VStack(spacing: 5) {
            raceRow("You", value: you, color: theme.accent)
            raceRow("Ghost", value: ghost, color: .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassSurface(RoundedRectangle(cornerRadius: 16, style: .continuous), interactive: false)
    }

    private func raceRow(_ name: String, value: Double, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.caption2).frame(width: 40, alignment: .leading)
            ProgressView(value: value).tint(color)
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption2.monospacedDigit())
                .frame(width: 34, alignment: .trailing)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if isZen {
                Label("No timer, no pressure", systemImage: "leaf.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(mistakeLimit > 0
                     ? "Mistakes: \(game.mistakes)/\(mistakeLimit)"
                     : "Mistakes: \(game.mistakes)")
                    .font(.subheadline)
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            Spacer()
            if !isZen {
                Text(game.timeString)
                    .font(.headline.monospacedDigit())
            }
            Button {
                if game.isPaused { game.resume() } else { game.pause() }
            } label: {
                Image(systemName: game.isPaused ? "play.fill" : "pause.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .disabled(game.isGenerating)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .glassSurface(Capsule(), interactive: false)
    }
}
