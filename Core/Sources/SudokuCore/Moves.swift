import Foundation

/// One player action. A game's list of moves is enough to rebuild the board
/// at any point (time machine), find per-cell thinking time (heatmap) and
/// race a ghost.
public struct Move: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case place, note, erase, hint
    }

    public var cell: Int
    /// Digit placed or toggled as a note; 0 for erase.
    public var value: Int
    public var kind: Kind
    /// Elapsed game seconds when the move was made.
    public var t: Int

    public init(cell: Int, value: Int, kind: Kind, t: Int) {
        self.cell = cell
        self.value = value
        self.kind = kind
        self.t = t
    }
}

public enum Replay {
    public struct State: Equatable, Sendable {
        public var values: [Int]
        public var notes: [Set<Int>]
    }

    /// Rebuilds the board after the first `count` moves (all moves if nil).
    /// Note: automatic removal of peer notes after a correct placement is a
    /// UI preference and is not reproduced here; values are always exact.
    public static func state(puzzle: [Int], moves: [Move], upTo count: Int? = nil) -> State {
        var values = puzzle
        var notes = [Set<Int>](repeating: [], count: puzzle.count)
        let n = min(count ?? moves.count, moves.count)
        for m in moves.prefix(n) {
            switch m.kind {
            case .place, .hint:
                values[m.cell] = m.value
                notes[m.cell] = []
            case .note:
                if notes[m.cell].contains(m.value) {
                    notes[m.cell].remove(m.value)
                } else {
                    notes[m.cell].insert(m.value)
                }
            case .erase:
                values[m.cell] = 0
                notes[m.cell] = []
            }
        }
        return State(values: values, notes: notes)
    }
}
