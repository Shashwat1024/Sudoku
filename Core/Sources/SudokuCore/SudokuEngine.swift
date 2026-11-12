import Foundation

public enum Difficulty: String, CaseIterable, Identifiable, Codable, Comparable, Sendable {
    case beginner = "Beginner"
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case expert = "Expert"
    case master = "Master"

    public var id: String { rawValue }

    /// Position in `allCases`, easiest first.
    public var rank: Int { Self.allCases.firstIndex(of: self)! }

    public static func < (l: Difficulty, r: Difficulty) -> Bool { l.rank < r.rank }

    /// Target number of given clues (fewer = harder).
    public var clues: Int {
        switch self {
        case .beginner: return 46
        case .easy: return 40
        case .medium: return 34
        case .hard: return 30
        case .expert: return 26
        case .master: return 22
        }
    }
}

/// Pure puzzle logic. Grids are 81 Ints, row-major, 0 = empty.
public enum SudokuEngine {
    public static func candidates(_ g: [Int], _ i: Int) -> [Int] {
        let r = i / 9, c = i % 9
        var mask = 0
        for k in 0..<9 {
            mask |= 1 << g[r * 9 + k]
            mask |= 1 << g[k * 9 + c]
        }
        let br = r / 3 * 3, bc = c / 3 * 3
        for dr in 0..<3 {
            for dc in 0..<3 {
                mask |= 1 << g[(br + dr) * 9 + bc + dc]
            }
        }
        return (1...9).filter { mask & (1 << $0) == 0 }
    }

    /// Counts solutions up to `limit` (stops early once reached).
    public static func countSolutions(_ g: inout [Int], limit: Int) -> Int {
        var best = -1
        var bestCands: [Int] = []
        for i in 0..<81 where g[i] == 0 {
            let c = candidates(g, i)
            if c.isEmpty { return 0 }
            if best == -1 || c.count < bestCands.count {
                best = i
                bestCands = c
                if c.count == 1 { break }
            }
        }
        if best == -1 { return 1 }
        var total = 0
        for v in bestCands {
            g[best] = v
            total += countSolutions(&g, limit: limit - total)
            if total >= limit { break }
        }
        g[best] = 0
        return total
    }

    private static func fill<G: RandomNumberGenerator>(_ g: inout [Int], using rng: inout G) -> Bool {
        guard let i = g.firstIndex(of: 0) else { return true }
        for v in candidates(g, i).stableShuffled(using: &rng) {
            g[i] = v
            if fill(&g, using: &rng) { return true }
        }
        g[i] = 0
        return false
    }

    /// Returns a puzzle with a unique solution, and that solution.
    /// The puzzle is rated with the human solver: removals are only kept while
    /// the rated level stays at or below the requested one, and generation stops
    /// once the requested level is reached with at most `difficulty.clues` givens.
    /// If no attempt hits the level exactly, the closest result is returned.
    /// Deterministic for a given RNG state.
    public static func generate<G: RandomNumberGenerator>(
        _ difficulty: Difficulty, using rng: inout G, maxAttempts: Int = 40
    ) -> (puzzle: [Int], solution: [Int]) {
        var best: (puzzle: [Int], solution: [Int], distance: Int)?

        for _ in 0..<max(1, maxAttempts) {
            var solution = [Int](repeating: 0, count: 81)
            _ = fill(&solution, using: &rng)

            var puzzle = solution
            var clues = 81
            var level = Difficulty.beginner
            for i in Array(0..<81).stableShuffled(using: &rng) {
                let saved = puzzle[i]
                puzzle[i] = 0
                var copy = puzzle
                guard countSolutions(&copy, limit: 2) == 1 else {
                    puzzle[i] = saved
                    continue
                }
                let rated = Solver.rate(puzzle).level
                if rated > difficulty {
                    puzzle[i] = saved   // would be too hard
                    continue
                }
                clues -= 1
                level = rated
                if clues <= difficulty.clues && level == difficulty { break }
            }

            if level == difficulty { return (puzzle, solution) }
            let distance = abs(level.rank - difficulty.rank)
            if best == nil || distance < best!.distance {
                best = (puzzle, solution, distance)
            }
        }
        return (best!.puzzle, best!.solution)
    }

    /// Solves a puzzle, or returns nil if it has conflicting givens or no solution.
    /// (If several solutions exist, one of them is returned.)
    public static func solve(_ puzzle: [Int]) -> [Int]? {
        guard puzzle.count == 81 else { return nil }
        for i in 0..<81 where puzzle[i] != 0 {
            for p in Grid.peers[i] where puzzle[p] == puzzle[i] { return nil }
        }
        var g = puzzle
        return solveInPlace(&g) ? g : nil
    }

    private static func solveInPlace(_ g: inout [Int]) -> Bool {
        var best = -1
        var bestCands: [Int] = []
        for i in 0..<81 where g[i] == 0 {
            let c = candidates(g, i)
            if c.isEmpty { return false }
            if best == -1 || c.count < bestCands.count {
                best = i
                bestCands = c
                if c.count == 1 { break }
            }
        }
        if best == -1 { return true }
        for v in bestCands {
            g[best] = v
            if solveInPlace(&g) { return true }
        }
        g[best] = 0
        return false
    }

    /// Random (non-reproducible) puzzle.
    public static func generate(_ difficulty: Difficulty) -> (puzzle: [Int], solution: [Int]) {
        var rng = SystemRandomNumberGenerator()
        return generate(difficulty, using: &rng)
    }
}
