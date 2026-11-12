import SudokuCore
import SwiftUI

/// Landing screen: continue the unfinished game, start a new one, or play the daily puzzle.
struct HomeView: View {
    let game: Game
    let trainer: TrainerStore
    let onContinue: () -> Void
    let onNewGame: (Difficulty, Bool) -> Void
    let onScan: () -> Void
    let onDaily: () -> Void
    let onLearn: () -> Void
    let onStats: () -> Void
    let onHistory: () -> Void
    let onSettings: () -> Void

    @Environment(\.theme) private var theme
    @State private var showNewGame = false

    var body: some View {
        ZStack {
            if showNewGame {
                NewGameView(onStart: onNewGame, onScan: onScan) {
                    withAnimation(.easeInOut(duration: 0.2)) { showNewGame = false }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                menu
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
    }

    private var menu: some View {
        VStack(spacing: 16) {
            header
            Spacer(minLength: 0)
            if game.hasUnfinishedGame { continueCard }
            newGameCard
            dailyCard
            learnCard
            Spacer(minLength: 0)
            bottomBar
        }
        .padding()
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 36))
                .foregroundStyle(theme.accent)
            Text("Sudoku")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text("No ads. Just puzzles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var continueCard: some View {
        Button(action: onContinue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Continue", systemImage: "play.fill").font(.headline)
                    Spacer()
                    Text(modeLabel).font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: game.progress)
                HStack {
                    Text("\(Int((game.progress * 100).rounded()))% complete")
                    Spacer()
                    if game.mode != .zen { Text(game.timeString).monospacedDigit() }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous), tint: theme.accent)
        }
        .buttonStyle(.plain)
    }

    private var modeLabel: String {
        switch game.mode {
        case .classic: return game.difficulty.rawValue
        case .daily: return "Daily · \(game.difficulty.rawValue)"
        case .zen: return "Zen · \(game.difficulty.rawValue)"
        }
    }

    private var newGameCard: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showNewGame = true }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Game").font(.headline)
                    Text("Choose from six difficulty levels")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var dailyCard: some View {
        let key = DailyPuzzle.todayKey()
        let level = DailyPuzzle.difficulty(forKey: key)
        let done = game.daily.isCompleted(key)
        let streak = game.daily.currentStreak()
        return Button(action: onDaily) {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.seal.fill" : "flame.fill")
                    .font(.title)
                    .foregroundStyle(done ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Puzzle").font(.headline)
                    Text(done ? "Completed · \(streak)-day streak" : "Today: \(level.rawValue)\(streak > 0 ? " · \(streak)-day streak" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var learnCard: some View {
        let total = Technique.allCases.count
        return Button(action: onLearn) {
            HStack(spacing: 14) {
                Image(systemName: "graduationcap.fill")
                    .font(.title)
                    .foregroundStyle(Color.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Learn Techniques").font(.headline)
                    Text("\(trainer.mastered) of \(total) mastered · lessons and quizzes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                pill("Stats", "chart.bar", action: onStats)
                pill("History", "clock.arrow.circlepath", action: onHistory)
                pill("Settings", "gearshape", action: onSettings)
            }
        }
        .padding(.bottom, 8)
    }

    private func pill(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.medium))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(.primary)
                .glassSurface(Capsule())
        }
        .buttonStyle(.plain)
    }
}
