import Foundation
import Testing
@testable import SudokuCore

@Suite struct DailyTests {
    @Test func weekdayAndDifficultyRotation() {
        // 2026-11-12 is a Thursday.
        #expect(DailyPuzzle.weekday(ofKey: "2026-11-12") == 5)
        #expect(DailyPuzzle.difficulty(forKey: "2026-11-12") == .hard)
        #expect(DailyPuzzle.difficulty(forKey: "2026-11-09") == .easy)    // Monday
        #expect(DailyPuzzle.difficulty(forKey: "2026-11-14") == .expert)  // Saturday
        #expect(DailyPuzzle.difficulty(forKey: "2026-11-15") == .master)  // Sunday
    }

    @Test func addDaysCrossesMonthYearAndLeapBoundaries() {
        #expect(DailyPuzzle.addDays(1, toKey: "2026-12-31") == "2027-01-01")
        #expect(DailyPuzzle.addDays(-1, toKey: "2026-03-01") == "2026-02-28")
        #expect(DailyPuzzle.addDays(-1, toKey: "2028-03-01") == "2028-02-29")
        #expect(DailyPuzzle.addDays(30, toKey: "2026-11-12") == "2026-12-12")
        #expect(DailyPuzzle.addDays(1, toKey: "garbage") == nil)
    }

    @Test func dateKeyUsesTheGivenTimeZone() {
        // 2026-11-12 23:30 UTC is already the 13th in Kolkata (UTC+5:30).
        let date = Date(timeIntervalSince1970: 1_794_526_200)
        let utc = TimeZone(identifier: "UTC")!
        let ist = TimeZone(identifier: "Asia/Kolkata")!
        #expect(DailyPuzzle.dateKey(for: date, timeZone: utc) == "2026-11-12")
        #expect(DailyPuzzle.dateKey(for: date, timeZone: ist) == "2026-11-13")
    }

    @Test func samePuzzleForTheSameDateAndDifferentOtherwise() {
        let a = DailyPuzzle.make(forKey: "2026-11-09")
        let b = DailyPuzzle.make(forKey: "2026-11-09")
        let c = DailyPuzzle.make(forKey: "2026-11-10")
        #expect(a.puzzle == b.puzzle)
        #expect(a.solution == b.solution)
        #expect(a.difficulty == .easy)
        #expect(a.puzzle != c.puzzle)
        var copy = a.puzzle
        #expect(SudokuEngine.countSolutions(&copy, limit: 2) == 1)
    }

    @Test func streaks() {
        let done: Set<String> = ["2026-11-08", "2026-11-09", "2026-11-10", "2026-11-12"]
        // Today (12th) is done, 11th is missing: streak is 1.
        #expect(DailyStreak.current(completed: done, today: "2026-11-12") == 1)
        // Today not done yet, yesterday (the 10th) is done: run 8,9,10 = 3.
        #expect(DailyStreak.current(completed: done, today: "2026-11-11") == 3)
        // Two days missing: streak is broken.
        #expect(DailyStreak.current(completed: done, today: "2026-11-14") == 0)
        #expect(DailyStreak.best(completed: done) == 3)
        #expect(DailyStreak.best(completed: []) == 0)
        #expect(DailyStreak.current(completed: [], today: "2026-11-12") == 0)
    }

    @Test func streakAcrossMonthBoundary() {
        let done: Set<String> = ["2026-10-30", "2026-10-31", "2026-11-01"]
        #expect(DailyStreak.current(completed: done, today: "2026-11-01") == 3)
        #expect(DailyStreak.best(completed: done) == 3)
    }
}
