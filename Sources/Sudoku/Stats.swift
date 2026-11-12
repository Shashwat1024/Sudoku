import SudokuCore
import Foundation
import Observation

struct LevelStats: Codable, Sendable {
    var started = 0
    var won = 0
    var bestTime: Int?
    var totalTime = 0

    var averageTime: Int? { won > 0 ? totalTime / won : nil }
}

private struct StatsData: Codable {
    var levels: [String: LevelStats] = [:]
    var streak = 0
    var bestStreak = 0
}

@MainActor
@Observable
final class Stats {
    private(set) var levels: [String: LevelStats] = [:]
    private(set) var streak = 0
    private(set) var bestStreak = 0

    private let key = "sudoku.stats"

    init() { load() }

    func level(_ d: Difficulty) -> LevelStats { levels[d.rawValue] ?? LevelStats() }

    var totalStarted: Int { levels.values.reduce(0) { $0 + $1.started } }
    var totalWon: Int { levels.values.reduce(0) { $0 + $1.won } }

    func recordStart(_ d: Difficulty) {
        var l = level(d)
        l.started += 1
        levels[d.rawValue] = l
        save()
    }

    /// Returns true if this is a new best time for the level.
    @discardableResult
    func recordWin(_ d: Difficulty, seconds: Int, eligibleForBest: Bool) -> Bool {
        var l = level(d)
        l.won += 1
        l.totalTime += seconds
        var isBest = false
        if eligibleForBest, l.bestTime == nil || seconds < l.bestTime! {
            isBest = true
            l.bestTime = seconds
        }
        levels[d.rawValue] = l
        streak += 1
        bestStreak = max(bestStreak, streak)
        save()
        return isBest
    }

    func recordLoss() {
        streak = 0
        save()
    }

    func reset() {
        levels = [:]
        streak = 0
        bestStreak = 0
        save()
    }

    private func save() {
        let data = StatsData(levels: levels, streak: streak, bestStreak: bestStreak)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(StatsData.self, from: data)
        else { return }
        levels = s.levels
        streak = s.streak
        bestStreak = s.bestStreak
    }
}
