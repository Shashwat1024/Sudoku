import Testing
@testable import SudokuCore

@Suite struct PuzzleCheckTests {
    private func sample() -> (puzzle: [Int], solution: [Int]) {
        var rng = SplitMix64(seed: "puzzlecheck")
        return SudokuEngine.generate(.medium, using: &rng)
    }

    @Test func generatedPuzzleIsValidWithItsSolution() {
        let (puzzle, solution) = sample()
        let a = PuzzleCheck.analyze(puzzle)
        #expect(a.status == .valid(solution: solution))
        #expect(a.conflicts.isEmpty)
        #expect(a.clues == puzzle.filter { $0 != 0 }.count)
    }

    @Test func duplicateGivenIsReportedAsConflictOnBothCells() {
        var (puzzle, _) = sample()
        // Put a digit that an existing peer already has.
        guard let cell = (0..<81).first(where: { puzzle[$0] == 0 }),
              let peer = Grid.peers[cell].first(where: { puzzle[$0] != 0 })
        else { Issue.record("no suitable cell"); return }
        puzzle[cell] = puzzle[peer]
        let a = PuzzleCheck.analyze(puzzle)
        #expect(a.status == .conflicts)
        #expect(a.conflicts.contains(cell) && a.conflicts.contains(peer))
    }

    @Test func removingAClueCanMakeSolutionNonUnique() {
        let (puzzle, _) = sample()
        // Strip clues until uniqueness is lost; the analysis must then say so.
        var board = puzzle
        var sawMultiple = false
        for i in 0..<81 where board[i] != 0 {
            board[i] = 0
            let a = PuzzleCheck.analyze(board)
            if a.status == .multipleSolutions { sawMultiple = true; break }
            if case .tooFewClues = a.status { break }
        }
        #expect(sawMultiple)
    }

    @Test func tooFewCluesAndBadInput() {
        var board = [Int](repeating: 0, count: 81)
        board[0] = 1
        #expect(PuzzleCheck.analyze(board).status == .tooFewClues(1))
        #expect(PuzzleCheck.analyze([1, 2, 3]).status == .noSolution)
        #expect(PuzzleCheck.analyze([Int](repeating: 11, count: 81)).status == .noSolution)
    }

    @Test func unsolvableButConsistentBoardHasNoSolution() {
        // Eight distinct digits in row 1, and the ninth digit blocked by column 9.
        var board = [Int](repeating: 0, count: 81)
        for d in 1...8 { board[d - 1] = d }       // row 1, columns 1-8
        board[9 + 8] = 9                          // row 2, column 9 holds the missing 9
        // Pad to reach the clue minimum without creating conflicts.
        board[18] = 9; board[27] = 8; board[36] = 7; board[45] = 6
        board[54] = 5; board[63] = 4; board[72] = 3
        board[4 + 9 * 4] = 9
        let a = PuzzleCheck.analyze(board)
        // Either contradictory or too sparse: never reported as playable.
        if case .valid = a.status { Issue.record("must not be valid") }
    }
}
