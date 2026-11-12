import Foundation

/// The daily puzzle: one deterministic puzzle per calendar date, the same on
/// every device. Dates are "yyyy-MM-dd" keys in the player's local time zone.
public enum DailyPuzzle {
    private static let utc: TimeZone = TimeZone(identifier: "UTC") ?? .gmt

    private static func utcCalendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    private static func parse(_ key: String) -> (y: Int, m: Int, d: Int)? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return (p[0], p[1], p[2])
    }

    private static func noonUTC(_ key: String) -> Date? {
        guard let p = parse(key) else { return nil }
        return utcCalendar().date(from: DateComponents(year: p.y, month: p.m, day: p.d, hour: 12))
    }

    public static func dateKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        let comps = c.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    public static func todayKey() -> String { dateKey(for: Date()) }

    /// Calendar weekday of a date key: 1 = Sunday ... 7 = Saturday.
    public static func weekday(ofKey key: String) -> Int? {
        noonUTC(key).map { utcCalendar().component(.weekday, from: $0) }
    }

    /// The key `n` days after (or before, if negative) another key.
    public static func addDays(_ n: Int, toKey key: String) -> String? {
        guard let d = noonUTC(key),
              let r = utcCalendar().date(byAdding: .day, value: n, to: d)
        else { return nil }
        return dateKey(for: r, timeZone: utc)
    }

    /// Mon easy, Tue/Wed medium, Thu/Fri hard, Sat expert, Sun master.
    public static func difficulty(forKey key: String) -> Difficulty {
        switch weekday(ofKey: key) ?? 2 {
        case 1: return .master
        case 2: return .easy
        case 3, 4: return .medium
        case 5, 6: return .hard
        default: return .expert
        }
    }

    public static func make(forKey key: String) -> (difficulty: Difficulty, puzzle: [Int], solution: [Int]) {
        let d = difficulty(forKey: key)
        // The version tag lets us change the algorithm later without silently
        // reusing old seeds.
        var rng = SplitMix64(seed: "sudoku-daily-v1-\(key)")
        let g = SudokuEngine.generate(d, using: &rng)
        return (d, g.puzzle, g.solution)
    }
}

public enum DailyStreak {
    /// Consecutive completed days ending today (or yesterday, if today isn't done yet).
    public static func current(completed: Set<String>, today: String) -> Int {
        var day = today
        if !completed.contains(day) {
            guard let y = DailyPuzzle.addDays(-1, toKey: today) else { return 0 }
            day = y
        }
        var n = 0
        while completed.contains(day) {
            n += 1
            guard let prev = DailyPuzzle.addDays(-1, toKey: day) else { break }
            day = prev
        }
        return n
    }

    /// Longest run of consecutive completed days.
    public static func best(completed: Set<String>) -> Int {
        let keys = completed.sorted()
        guard !keys.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<keys.count {
            if DailyPuzzle.addDays(1, toKey: keys[i - 1]) == keys[i] { run += 1 } else { run = 1 }
            best = max(best, run)
        }
        return best
    }
}
