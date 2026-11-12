import Foundation

/// Validates a hand-entered or scanned puzzle before it can be played.
public enum PuzzleCheck {
    public enum Status: Equatable, Sendable {
        /// Exactly one solution; playable.
        case valid(solution: [Int])
        /// Two givens in the same row, column or box share a digit.
        case conflicts
        case noSolution
        /// More than one solution, so mistakes can't be judged reliably.
        case multipleSolutions
        /// A uniquely solvable puzzle needs at least 17 clues.
        case tooFewClues(Int)
    }

    public struct Analysis: Equatable, Sendable {
        public var status: Status
        /// Cells involved in a row/column/box clash.
        public var conflicts: Set<Int>
        public var clues: Int
    }

    public static let minimumClues = 17

    public static func conflictingCells(_ g: [Int]) -> Set<Int> {
        var bad = Set<Int>()
        for i in 0..<81 where g[i] != 0 {
            for p in Grid.peers[i] where g[p] == g[i] {
                bad.insert(i)
                bad.insert(p)
            }
        }
        return bad
    }

    public static func analyze(_ g: [Int]) -> Analysis {
        guard g.count == 81, g.allSatisfy({ (0...9).contains($0) }) else {
            return Analysis(status: .noSolution, conflicts: [], clues: 0)
        }
        let clues = g.filter { $0 != 0 }.count
        let conflicts = conflictingCells(g)
        if !conflicts.isEmpty { return Analysis(status: .conflicts, conflicts: conflicts, clues: clues) }
        if clues < minimumClues { return Analysis(status: .tooFewClues(clues), conflicts: [], clues: clues) }

        var copy = g
        switch SudokuEngine.countSolutions(&copy, limit: 2) {
        case 0:
            return Analysis(status: .noSolution, conflicts: [], clues: clues)
        case 1:
            guard let solution = SudokuEngine.solve(g) else {
                return Analysis(status: .noSolution, conflicts: [], clues: clues)
            }
            return Analysis(status: .valid(solution: solution), conflicts: [], clues: clues)
        default:
            return Analysis(status: .multipleSolutions, conflicts: [], clues: clues)
        }
    }
}
