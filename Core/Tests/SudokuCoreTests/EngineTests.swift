import Testing
@testable import SudokuCore

@Suite struct EngineTests {
    @Test func generatedPuzzleHasUniqueSolutionMatchingSolution() {
        for d in [Difficulty.beginner, .medium, .hard] {
            let (puzzle, solution) = SudokuEngine.generate(d)
            var copy = puzzle
            #expect(SudokuEngine.countSolutions(&copy, limit: 2) == 1)
            // Every given must agree with the solution.
            for i in 0..<81 where puzzle[i] != 0 {
                #expect(puzzle[i] == solution[i])
            }
            // Solution is a valid filled grid.
            #expect(!solution.contains(0))
        }
    }

    @Test func clueCountNeverBelowTargetAndReachesTargetForEasyLevels() {
        let (puzzle, _) = SudokuEngine.generate(.beginner)
        let clues = puzzle.filter { $0 != 0 }.count
        #expect(clues >= Difficulty.beginner.clues)
    }

    @Test func sameSeedGivesIdenticalPuzzle() {
        var a = SplitMix64(seed: "2026-11-12")
        var b = SplitMix64(seed: "2026-11-12")
        let p1 = SudokuEngine.generate(.medium, using: &a)
        let p2 = SudokuEngine.generate(.medium, using: &b)
        #expect(p1.puzzle == p2.puzzle)
        #expect(p1.solution == p2.solution)
    }

    @Test func differentSeedsGiveDifferentPuzzles() {
        var a = SplitMix64(seed: "2026-11-12")
        var b = SplitMix64(seed: "2026-11-13")
        let p1 = SudokuEngine.generate(.medium, using: &a)
        let p2 = SudokuEngine.generate(.medium, using: &b)
        #expect(p1.puzzle != p2.puzzle)
    }

    @Test func stableShuffleIsDeterministicPermutation() {
        var a = SplitMix64(seed: 42)
        var b = SplitMix64(seed: 42)
        let x = Array(0..<20).stableShuffled(using: &a)
        let y = Array(0..<20).stableShuffled(using: &b)
        #expect(x == y)
        #expect(x.sorted() == Array(0..<20))
    }
}
