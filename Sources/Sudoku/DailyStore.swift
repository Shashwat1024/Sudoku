import Foundation
import Observation
import SudokuCore

struct DailyResult: Codable, Equatable, Sendable {
    var seconds: Int
    var hints: Int
    var mistakes: Int
}

/// Which daily puzzles have been completed, and how.
@MainActor
@Observable
final class DailyStore {
    private(set) var results: [String: DailyResult] = [:]

    private let storeKey = "sudoku.daily"

    init() { load() }

    var completedKeys: Set<String> { Set(results.keys) }

    func isCompleted(_ key: String) -> Bool { results[key] != nil }

    /// Keeps the better result if a day is replayed (a hint-free run beats a hinted one,
    /// otherwise the faster time wins).
    func record(key: String, seconds: Int, hints: Int, mistakes: Int) {
        let new = DailyResult(seconds: seconds, hints: hints, mistakes: mistakes)
        if let old = results[key] {
            if hints == 0 && (old.hints > 0 || seconds < old.seconds) { results[key] = new }
        } else {
            results[key] = new
        }
        save()
    }

    func currentStreak(today: String = DailyPuzzle.todayKey()) -> Int {
        DailyStreak.current(completed: completedKeys, today: today)
    }

    var bestStreak: Int { DailyStreak.best(completed: completedKeys) }

    private func save() {
        if let data = try? JSONEncoder().encode(results) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let r = try? JSONDecoder().decode([String: DailyResult].self, from: data)
        else { return }
        results = r
    }
}
