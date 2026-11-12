import Testing
@testable import SudokuCore

@Suite struct CheckerTests {
    private func sample() -> (puzzle: [Int], solution: [Int]) {
        var rng = SplitMix64(seed: "checker")
        return SudokuEngine.generate(.easy, using: &rng)
    }

    /// A digit that is wrong for `cell` (differs from the solution).
    private func wrongDigit(_ solution: [Int], _ cell: Int) -> Int {
        solution[cell] == 1 ? 2 : 1
    }

    @Test func noMistakesOnCorrectBoard() {
        let (puzzle, solution) = sample()
        #expect(Checker.earliestMistake(moves: [], values: puzzle, solution: solution) == nil)
        #expect(Checker.earliestMistake(moves: [], values: solution, solution: solution) == nil)
    }

    @Test func picksTheEarliestWrongPlacement() {
        let (puzzle, solution) = sample()
        let empties = (0..<81).filter { puzzle[$0] == 0 }
        let a = empties[0], b = empties[1]
        var values = puzzle
        values[a] = wrongDigit(solution, a)
        values[b] = wrongDigit(solution, b)
        // b was placed first, a second.
        let moves = [
            Move(cell: b, value: values[b], kind: .place, t: 1),
            Move(cell: a, value: values[a], kind: .place, t: 2),
        ]
        #expect(Checker.earliestMistake(moves: moves, values: values, solution: solution)?.cell == b)
    }

    @Test func replacedWrongDigitUsesLatestPlacementForOrdering() {
        let (puzzle, solution) = sample()
        let empties = (0..<81).filter { puzzle[$0] == 0 }
        let a = empties[0], b = empties[1]
        var values = puzzle
        values[a] = wrongDigit(solution, a)
        values[b] = wrongDigit(solution, b)
        // a was first placed early, but re-placed (wrongly) after b.
        let moves = [
            Move(cell: a, value: values[a], kind: .place, t: 1),
            Move(cell: b, value: values[b], kind: .place, t: 2),
            Move(cell: a, value: values[a], kind: .place, t: 3),
        ]
        #expect(Checker.earliestMistake(moves: moves, values: values, solution: solution)?.cell == b)
    }

    @Test func reportsClashWithPeer() {
        let (puzzle, solution) = sample()
        // Find an empty cell with a given peer, and copy that peer's digit into it.
        guard let cell = (0..<81).first(where: { puzzle[$0] == 0 && Grid.peers[$0].contains { puzzle[$0] != 0 } }),
              let peer = Grid.peers[cell].first(where: { puzzle[$0] != 0 })
        else { Issue.record("no suitable cell"); return }
        var values = puzzle
        values[cell] = puzzle[peer]
        let m = Checker.earliestMistake(
            moves: [Move(cell: cell, value: values[cell], kind: .place, t: 1)],
            values: values, solution: solution
        )
        #expect(m?.cell == cell)
        #expect(m?.conflictsWith != nil)
    }
}
