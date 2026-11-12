import Foundation
import Testing
@testable import SudokuCore

@Suite struct InsightsTests {
    @Test func heatmapCreditsTheGapBeforeEachMoveToItsCell() {
        let moves = [
            Move(cell: 5, value: 1, kind: .place, t: 4),    // 4s before first move
            Move(cell: 9, value: 2, kind: .place, t: 5),    // 1s
            Move(cell: 5, value: 0, kind: .erase, t: 15),   // 10s more on cell 5
        ]
        let times = Heatmap.cellTimes(moves: moves)
        #expect(times[5] == 14)
        #expect(times[9] == 1)
        #expect(times.reduce(0, +) == 15)
        #expect(Heatmap.cellTimes(moves: []).allSatisfy { $0 == 0 })
    }

    @Test func stateAtTimeIncludesMovesUpToThatSecond() {
        let blank = [Int](repeating: 0, count: 81)
        let moves = [
            Move(cell: 0, value: 1, kind: .place, t: 2),
            Move(cell: 1, value: 2, kind: .place, t: 5),
            Move(cell: 2, value: 3, kind: .place, t: 9),
        ]
        #expect(Replay.state(puzzle: blank, moves: moves, atTime: 1).values.filter { $0 != 0 }.isEmpty)
        #expect(Replay.state(puzzle: blank, moves: moves, atTime: 5).values[1] == 2)
        #expect(Replay.state(puzzle: blank, moves: moves, atTime: 5).values[2] == 0)
        #expect(Replay.state(puzzle: blank, moves: moves, atTime: 99).values[2] == 3)
    }

    @Test func completionFraction() {
        var rng = SplitMix64(seed: "completion")
        let (puzzle, solution) = SudokuEngine.generate(.easy, using: &rng)
        #expect(Completion.fraction(values: puzzle, puzzle: puzzle, solution: solution) == 0)
        #expect(Completion.fraction(values: solution, puzzle: puzzle, solution: solution) == 1)
        var half = puzzle
        let empties = (0..<81).filter { puzzle[$0] == 0 }
        for i in empties.prefix(empties.count / 2) { half[i] = solution[i] }
        let f = Completion.fraction(values: half, puzzle: puzzle, solution: solution)
        #expect(f > 0.4 && f < 0.6)
    }

    @Test func ghostCodeRoundTrips() {
        var rng = SplitMix64(seed: "ghost")
        let (puzzle, _) = SudokuEngine.generate(.medium, using: &rng)
        let moves = [
            Move(cell: 0, value: 7, kind: .place, t: 3),
            Move(cell: 80, value: 4, kind: .note, t: 61),
            Move(cell: 40, value: 0, kind: .erase, t: 62),
            Move(cell: 12, value: 9, kind: .hint, t: 3600),
        ]
        let payload = GhostCode.Payload(puzzle: puzzle, moves: moves, seconds: 3700)
        let text = GhostCode.encode(payload)
        #expect(text.hasPrefix("SDK1:"))
        #expect(GhostCode.decode(text) == payload)
        // Surrounding whitespace from copy/paste is tolerated.
        #expect(GhostCode.decode("  \n" + text + "\n") == payload)
    }

    @Test func ghostCodeRejectsGarbage() {
        #expect(GhostCode.decode("") == nil)
        #expect(GhostCode.decode("hello") == nil)
        #expect(GhostCode.decode("SDK1:123:ABC:") == nil)
        let ok = GhostCode.encode(.init(puzzle: [Int](repeating: 0, count: 81), moves: [], seconds: 1))
        #expect(GhostCode.decode(ok) != nil)
        #expect(GhostCode.decode(ok + "XYZ") == nil)                       // bad move length
        #expect(GhostCode.decode(ok.replacingOccurrences(of: "SDK1", with: "SDK2")) == nil)
        let badCell = ok + "99" + "1" + "p" + "001"
        #expect(GhostCode.decode(badCell) == nil)                          // cell out of range
    }

    @Test func ghostCodeRejectsSignsNonAsciiAndOutOfOrderTimes() {
        let blank = [Int](repeating: 0, count: 81)
        let ok = GhostCode.encode(.init(puzzle: blank, moves: [], seconds: 5))
        // Negative time via a leading minus in the base-36 field.
        #expect(GhostCode.decode(ok + "00" + "1" + "p" + "-01") == nil)
        #expect(GhostCode.decode(ok.replacingOccurrences(of: ":005:", with: ":-05:")) == nil)
        // Non-ASCII digit (circled 3) in a puzzle cell.
        let circled = "SDK1:" + "\u{2462}" + String(repeating: "0", count: 80) + ":005:"
        #expect(GhostCode.decode(circled) == nil)
        // Out-of-order timestamps.
        let backwards = ok + "00" + "1" + "p" + "00A" + "01" + "2" + "p" + "003"
        #expect(GhostCode.decode(backwards) == nil)
        // Same two moves in order are fine.
        let forwards = ok + "00" + "1" + "p" + "003" + "01" + "2" + "p" + "00A"
        #expect(GhostCode.decode(forwards)?.moves.count == 2)
    }

    @Test func solveReturnsTheUniqueSolution() {
        var rng = SplitMix64(seed: "solve")
        let (puzzle, solution) = SudokuEngine.generate(.hard, using: &rng)
        #expect(SudokuEngine.solve(puzzle) == solution)
    }

    @Test func solveRejectsConflictingGivens() {
        var board = [Int](repeating: 0, count: 81)
        board[0] = 5
        board[1] = 5   // same row, same digit
        #expect(SudokuEngine.solve(board) == nil)
        #expect(SudokuEngine.solve([1, 2, 3]) == nil)
    }
}
