import SudokuCore
import SwiftUI

/// A game start the player has asked for (possibly pending confirmation).
private enum PendingStart: Equatable {
    case level(Difficulty)
    case zen(Difficulty)
    case daily

    var title: String {
        switch self {
        case .level(let d): return "New \(d.rawValue) Game"
        case .zen(let d): return "New Zen \(d.rawValue) Game"
        case .daily: return "Start Today's Puzzle"
        }
    }
}

private enum Screen {
    case home, game
}

/// Root: owns the game, theme and shared sheets, and switches between Home and the board.
struct ContentView: View {
    @State private var game = Game()
    @State private var screen: Screen = .home
    @State private var pending: PendingStart?
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showDaily = false

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Pref.haptics) private var haptics = true
    @AppStorage(Pref.theme) private var themeName = Theme.classic.id
    @AppStorage(Pref.glass) private var glassEnabled = true

    private var theme: Theme { Theme.named(themeName) }
    private var isZen: Bool { game.mode == .zen && screen == .game }

    var body: some View {
        ZStack {
            switch screen {
            case .home:
                HomeView(
                    game: game,
                    onContinue: continueGame,
                    onNewGame: { level, zen in request(zen ? .zen(level) : .level(level)) },
                    onDaily: { showDaily = true },
                    onStats: { showStats = true },
                    onSettings: { showSettings = true }
                )
                .transition(.opacity)
            case .game:
                GameScreen(
                    game: game,
                    onHome: { goHome() },
                    onSettings: { showSettings = true }
                )
                .transition(.opacity)
            }
        }
        .background { AmbientBackground(theme: theme, glass: glassEnabled, zen: isZen) }
        .environment(\.theme, theme)
        .environment(\.glassEnabled, glassEnabled)
        .tint(theme.accent)
        .preferredColorScheme(theme.scheme)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                game.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.pause() }
        }
        .sensoryFeedback(trigger: game.eventID) { _, _ in
            guard haptics else { return nil }
            if game.mode == .zen {
                // Gentle, never alarming.
                switch game.lastEvent {
                case .place, .erase, .mistake, .over: return .impact(flexibility: .soft, intensity: 0.5)
                case .complete: return .success
                case .none: return nil
                }
            }
            switch game.lastEvent {
            case .place, .erase: return .impact(weight: .light)
            case .mistake, .over: return .error
            case .complete: return .success
            case .none: return nil
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().tint(theme.accent).preferredColorScheme(theme.scheme)
        }
        .sheet(isPresented: $showStats) {
            StatsView(stats: game.stats).tint(theme.accent).preferredColorScheme(theme.scheme)
        }
        .sheet(isPresented: $showDaily) {
            DailyView(game: game) {
                showDaily = false
                // Let the sheet finish dismissing before a confirmation dialog appears.
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    request(.daily)
                }
            }
            .environment(\.theme, theme)
            .environment(\.glassEnabled, glassEnabled)
            .tint(theme.accent)
            .preferredColorScheme(theme.scheme)
        }
        .confirmationDialog(
            pending?.title ?? "Start a new game?",
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(pending?.title ?? "Start", role: .destructive) {
                if let p = pending { start(p) }
            }
        } message: {
            Text("Your unfinished game will be lost.")
        }
    }

    // MARK: Navigation

    private func show(_ s: Screen) {
        withAnimation(.easeInOut(duration: 0.25)) { screen = s }
    }

    private func goHome() {
        game.pause()
        show(.home)
    }

    private func continueGame() {
        game.resume()
        show(.game)
    }

    // MARK: Starting games

    private func request(_ p: PendingStart) {
        // Today's daily already underway: just go back to it.
        if p == .daily && game.isTodaysDailyActive {
            continueGame()
            return
        }
        if game.isInProgress { pending = p } else { start(p) }
    }

    private func start(_ p: PendingStart) {
        switch p {
        case .level(let d): game.newGame(d)
        case .zen(let d): game.newGame(d, mode: .zen)
        case .daily: game.startDaily()
        }
        show(.game)
    }
}
