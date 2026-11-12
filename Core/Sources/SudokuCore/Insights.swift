import Foundation

// MARK: - Heatmap

public enum Heatmap {
    /// Seconds of "thinking" attributed to each cell: the gap before each move is
    /// credited to the cell that move touched. Index = cell (0...80).
    public static func cellTimes(moves: [Move]) -> [Int] {
        var times = [Int](repeating: 0, count: 81)
        var previous = 0
        for m in moves {
            times[m.cell] += max(0, m.t - previous)
            previous = max(previous, m.t)
        }
        return times
    }
}

// MARK: - Time-based replay and progress

extension Replay {
    /// Board as it was `t` game-seconds in (all moves made at or before `t`).
    public static func state(puzzle: [Int], moves: [Move], atTime t: Int) -> State {
        let n = moves.prefix { $0.t <= t }.count
        return state(puzzle: puzzle, moves: moves, upTo: n)
    }
}

public enum Completion {
    /// Share of the empty cells holding the correct digit (0...1).
    public static func fraction(values: [Int], puzzle: [Int], solution: [Int]) -> Double {
        var empty = 0, correct = 0
        for i in 0..<81 where puzzle[i] == 0 {
            empty += 1
            if values[i] == solution[i] { correct += 1 }
        }
        return empty == 0 ? 1 : Double(correct) / Double(empty)
    }
}

// MARK: - Ghost sharing

/// Compact text form of a puzzle plus a recorded run, so a run can be shared
/// as plain text and raced on another device (no server involved).
public enum GhostCode {
    public struct Payload: Equatable, Sendable {
        public var puzzle: [Int]
        public var moves: [Move]
        public var seconds: Int

        public init(puzzle: [Int], moves: [Move], seconds: Int) {
            self.puzzle = puzzle
            self.moves = moves
            self.seconds = seconds
        }
    }

    private static let tag = "SDK1"
    private static let maxTime = 36 * 36 * 36 - 1   // 3 base-36 digits

    private static func kindChar(_ k: Move.Kind) -> Character {
        switch k {
        case .place: return "p"
        case .note: return "n"
        case .erase: return "e"
        case .hint: return "h"
        }
    }

    private static func kind(_ c: Character) -> Move.Kind? {
        switch c {
        case "p": return .place
        case "n": return .note
        case "e": return .erase
        case "h": return .hint
        default: return nil
        }
    }

    private static func base36(_ n: Int, width: Int) -> String {
        let s = String(min(max(n, 0), maxTime), radix: 36).uppercased()
        return String(repeating: "0", count: max(0, width - s.count)) + s
    }

    public static func encode(_ p: Payload) -> String {
        let puzzle = p.puzzle.map(String.init).joined()
        var moves = ""
        for m in p.moves {
            moves += String(format: "%02d", m.cell) + String(m.value) + String(kindChar(m.kind)) + base36(m.t, width: 3)
        }
        return "\(tag):\(puzzle):\(base36(p.seconds, width: 3)):\(moves)"
    }

    /// Plain ASCII digit only (`wholeNumberValue` also accepts things like "③").
    private static func asciiDigit(_ c: Character) -> Int? {
        guard c.isASCII, let v = c.wholeNumberValue else { return nil }
        return v
    }

    /// Unsigned base-36 (`Int(_, radix:)` would also accept a leading "-" or "+").
    private static func parseBase36(_ s: String) -> Int? {
        guard !s.isEmpty, s.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { return nil }
        return Int(s, radix: 36)
    }

    public static func decode(_ text: String) -> Payload? {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == tag else { return nil }

        let digits = Array(parts[1])
        guard digits.count == 81 else { return nil }
        var puzzle: [Int] = []
        for c in digits {
            guard let d = asciiDigit(c) else { return nil }
            puzzle.append(d)
        }
        guard let seconds = parseBase36(parts[2]) else { return nil }

        let chars = Array(parts[3])
        guard chars.count % 7 == 0 else { return nil }
        var moves: [Move] = []
        var lastT = 0
        var i = 0
        while i < chars.count {
            guard let tens = asciiDigit(chars[i]), let ones = asciiDigit(chars[i + 1]),
                  let value = asciiDigit(chars[i + 2]),
                  let kind = kind(chars[i + 3]),
                  let t = parseBase36(String(chars[(i + 4)..<(i + 7)]))
            else { return nil }
            let cell = tens * 10 + ones
            // Moves are chronological; anything else would break time-based replay.
            guard (0...80).contains(cell), t >= lastT else { return nil }
            lastT = t
            moves.append(Move(cell: cell, value: value, kind: kind, t: t))
            i += 7
        }
        return Payload(puzzle: puzzle, moves: moves, seconds: seconds)
    }
}
