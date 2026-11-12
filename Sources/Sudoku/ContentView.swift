import SudokuCore
import SwiftUI

/// A game start the player has asked for (possibly pending confirmation).
private enum PendingStart: Equatable {
    case level(Difficulty)
    case zen(Difficulty)
    case daily
    case ghost(GhostSetup)

    var title: String {
        switch self {
        case .level(let d): return "New \(d.rawValue) Game"
        case .zen(let d): return "New Zen \(d.rawValue) Game"
        case .daily: return "Start Today's Puzzle"
        case .ghost: return "Race the Ghost"
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
    @State private var showHistory = false
    @State private var reviewRecord: GameRecord?

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Pref.haptics) private var haptics = true
    @AppStorage(Pref.theme) private var themeName = Theme.classic.id

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
                    onHistory: { showHistory = true },
                    onSettings: { showSettings = true }
                )
                .transition(.opacity)
            case .game:
                GameScreen(
                    game: game,
                    onHome: { goHome() },
                    onSettings: { showSettings = true },
                    onReview: { record in
                        // Let the alert finish dismissing before the sheet appears.
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            reviewRecord = record
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .background { AmbientBackground(theme: theme, zen: isZen) }
        .environment(\.theme, theme)
        .tint(theme.accent)
        .preferredColorScheme(theme.scheme)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                // Game time only runs on the board, never on the home screen.
                if screen == .game { game.tick() }
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
            themed(SettingsView())
        }
        .sheet(isPresented: $showStats) {
            themed(StatsView(stats: game.stats))
        }
        .sheet(isPresented: $showDaily) {
            themed(DailyView(game: game) {
                showDaily = false
                after(request: .daily)
            })
        }
        .sheet(isPresented: $showHistory) {
            themed(HistoryView(store: game.gameHistory) { setup in
                after(request: .ghost(setup))
            })
        }
        .sheet(item: $reviewRecord) { record in
            themed(NavigationStack {
                ReplayView(record: record) { setup in
                    reviewRecord = nil
                    after(request: .ghost(setup))
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { reviewRecord = nil }
                    }
                }
            })
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

    /// Applies the current theme to a sheet's content.
    private func themed<V: View>(_ view: V) -> some View {
        view
            .environment(\.theme, theme)
            .tint(theme.accent)
            .preferredColorScheme(theme.scheme)
            .background { AmbientBackground(theme: theme) }
    }

    /// Runs a start request after a sheet has finished dismissing.
    private func after(request p: PendingStart) {
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            request(p)
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
        case .ghost(let setup): game.startGhostRace(setup)
        }
        show(.game)
    }
}
