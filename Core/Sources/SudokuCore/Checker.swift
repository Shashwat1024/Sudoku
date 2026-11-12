import Foundation

/// Finds mistakes on the player's board by comparing with the solution and
/// using the move log to pick the earliest one still on the board.
public enum Checker {
    public struct Mistake: Equatable, Sendable {
        public var cell: Int
        /// A peer cell holding the same digit, if the mistake already clashes.
        public var conflictsWith: Int?
        public var digit: Int
    }

    public static func wrongCells(values: [Int], solution: [Int]) -> [Int] {
        (0..<81).filter { values[$0] != 0 && values[$0] != solution[$0] }
    }

    /// The wrong cell that was filled in earliest (by last placement time).
    public static func earliestMistake(moves: [Move], values: [Int], solution: [Int]) -> Mistake? {
        let wrong = wrongCells(values: values, solution: solution)
        guard !wrong.isEmpty else { return nil }

        func lastPlacement(_ cell: Int) -> Int {
            moves.lastIndex { $0.cell == cell && ($0.kind == .place || $0.kind == .hint) } ?? Int.max
        }
        let cell = wrong.min { a, b in
            let la = lastPlacement(a), lb = lastPlacement(b)
            return la != lb ? la < lb : a < b
        }!
        let clash = Grid.peers[cell].first { values[$0] == values[cell] }
        return Mistake(cell: cell, conflictsWith: clash, digit: values[cell])
    }
}
