import Foundation

// MARK: - Grid geometry

public enum Grid {
    /// 27 units: 0-8 rows, 9-17 columns, 18-26 boxes.
    public static let units: [[Int]] = {
        var u: [[Int]] = []
        for r in 0..<9 { u.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { u.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let br = b / 3 * 3, bc = b % 3 * 3
            var cells: [Int] = []
            for dr in 0..<3 { for dc in 0..<3 { cells.append((br + dr) * 9 + bc + dc) } }
            u.append(cells)
        }
        return u
    }()

    static let unitSets: [Set<Int>] = units.map { Set($0) }

    /// peers[i] = the 20 other cells sharing a row, column or box with i.
    public static let peers: [[Int]] = (0..<81).map { i in
        var s = Set<Int>()
        for u in [i / 9, 9 + i % 9, 18 + box(of: i)] { s.formUnion(units[u]) }
        s.remove(i)
        return s.sorted()
    }

    /// Flattened 81x81 table: isPeer[a * 81 + b].
    static let isPeerTable: [Bool] = {
        var t = [Bool](repeating: false, count: 81 * 81)
        for a in 0..<81 { for b in peers[a] { t[a * 81 + b] = true } }
        return t
    }()

    public static func isPeer(_ a: Int, _ b: Int) -> Bool { isPeerTable[a * 81 + b] }

    public static func box(of cell: Int) -> Int { (cell / 27) * 3 + (cell % 9) / 3 }

    /// "R4C5" style name (1-based).
    public static func name(_ cell: Int) -> String { "R\(cell / 9 + 1)C\(cell % 9 + 1)" }

    public static func unitName(_ u: Int) -> String {
        if u < 9 { return "row \(u + 1)" }
        if u < 18 { return "column \(u - 8)" }
        return "box \(u - 17)"
    }
}

// MARK: - Techniques and steps

public enum Technique: Int, CaseIterable, Codable, Comparable, Sendable {
    case nakedSingle = 1
    case hiddenSingle
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case nakedTriple
    case xWing
    case xyWing

    public static func < (l: Technique, r: Technique) -> Bool { l.rawValue < r.rawValue }

    public var title: String {
        switch self {
        case .nakedSingle: return "Naked Single"
        case .hiddenSingle: return "Hidden Single"
        case .lockedCandidates: return "Locked Candidates"
        case .nakedPair: return "Naked Pair"
        case .hiddenPair: return "Hidden Pair"
        case .nakedTriple: return "Naked Triple"
        case .xWing: return "X-Wing"
        case .xyWing: return "XY-Wing"
        }
    }
}

public struct Placement: Equatable, Sendable {
    public var cell: Int
    public var digit: Int
}

public struct Elimination: Equatable, Sendable {
    public var cell: Int
    public var digit: Int
}

/// One logical deduction: either a digit to place or candidates to remove.
public struct Step: Equatable, Sendable {
    public var technique: Technique
    public var placement: Placement?
    public var eliminations: [Elimination]
    /// Cells that form the pattern (to highlight).
    public var cells: [Int]
    public var digits: [Int]
    public var explanation: String
}

/// A hint: the deductions needed to reach the next placement.
/// All steps but the last remove candidates; the last one places a digit.
public struct Hint: Equatable, Sendable {
    public var steps: [Step]

    public var final: Step { steps[steps.count - 1] }
    public var placement: Placement { final.placement! }
}

// MARK: - Rating

public struct Rating: Equatable, Sendable {
    public var hardest: Technique?
    public var steps: Int
    /// True if the solver finished using only the supported techniques.
    public var solved: Bool

    /// Difficulty band implied by the hardest technique required.
    public var level: Difficulty {
        guard solved else { return .master }
        guard let h = hardest else { return .beginner }
        switch h {
        case .nakedSingle: return .beginner
        case .hiddenSingle: return .easy
        case .lockedCandidates: return .medium
        case .nakedPair, .hiddenPair, .nakedTriple: return .hard
        case .xWing, .xyWing: return .expert
        }
    }
}

// MARK: - Solver

/// Human-style solver: tracks candidates per cell and applies the easiest
/// available technique first.
public struct Solver: Sendable {
    public private(set) var values: [Int]
    /// Candidate bitmask per cell; bit d set means digit d is possible.
    public private(set) var cands: [UInt16]

    @inline(__always) private static func bit(_ d: Int) -> UInt16 { 1 << UInt16(d) }

    private static func digits(of mask: UInt16) -> [Int] {
        (1...9).filter { mask & bit($0) != 0 }
    }

    public init(puzzle: [Int]) {
        values = puzzle
        cands = [UInt16](repeating: 0, count: 81)
        for i in 0..<81 where puzzle[i] == 0 { cands[i] = 0x3FE }
        for i in 0..<81 where puzzle[i] != 0 {
            for p in Grid.peers[i] { cands[p] &= ~Self.bit(puzzle[i]) }
        }
    }

    public var isSolved: Bool { !values.contains(0) }

    /// An unfilled cell with no candidates left means the board is contradictory.
    public var isContradictory: Bool {
        (0..<81).contains { values[$0] == 0 && cands[$0] == 0 }
    }

    public mutating func apply(_ step: Step) {
        if let p = step.placement {
            values[p.cell] = p.digit
            cands[p.cell] = 0
            for q in Grid.peers[p.cell] { cands[q] &= ~Self.bit(p.digit) }
        }
        for e in step.eliminations { cands[e.cell] &= ~Self.bit(e.digit) }
    }

    public func nextStep(maxTechnique: Technique = .xyWing) -> Step? {
        for t in Technique.allCases where t <= maxTechnique {
            if let s = find(t) { return s }
        }
        return nil
    }

    // MARK: Finders

    private func find(_ t: Technique) -> Step? {
        switch t {
        case .nakedSingle: return nakedSingle()
        case .hiddenSingle: return hiddenSingle()
        case .lockedCandidates: return lockedCandidates()
        case .nakedPair: return nakedSubset(2, .nakedPair)
        case .hiddenPair: return hiddenPair()
        case .nakedTriple: return nakedSubset(3, .nakedTriple)
        case .xWing: return xWing()
        case .xyWing: return xyWing()
        }
    }

    private func cellsWith(_ d: Int, in u: Int) -> [Int] {
        let b = Self.bit(d)
        return Grid.units[u].filter { cands[$0] & b != 0 }
    }

    private func nakedSingle() -> Step? {
        for i in 0..<81 where values[i] == 0 && cands[i].nonzeroBitCount == 1 {
            let d = cands[i].trailingZeroBitCount
            return Step(
                technique: .nakedSingle,
                placement: Placement(cell: i, digit: d),
                eliminations: [], cells: [i], digits: [d],
                explanation: "\(Grid.name(i)) can only be \(d): every other digit already appears in its row, column or box."
            )
        }
        return nil
    }

    private func hiddenSingle() -> Step? {
        for u in 0..<27 {
            for d in 1...9 {
                let cs = cellsWith(d, in: u)
                if cs.count == 1 {
                    let i = cs[0]
                    return Step(
                        technique: .hiddenSingle,
                        placement: Placement(cell: i, digit: d),
                        eliminations: [], cells: Grid.units[u].filter { values[$0] == 0 }, digits: [d],
                        explanation: "In \(Grid.unitName(u)), the digit \(d) fits in only one cell: \(Grid.name(i))."
                    )
                }
            }
        }
        return nil
    }

    private func lockedCandidates() -> Step? {
        // Pointing: within a box, a digit confined to one line leaves the rest of that line.
        for b in 18..<27 {
            for d in 1...9 {
                let cs = cellsWith(d, in: b)
                guard cs.count >= 2 else { continue }
                let rows = Set(cs.map { $0 / 9 })
                let cols = Set(cs.map { $0 % 9 })
                var line: Int?
                var lineName = ""
                if rows.count == 1 { line = rows.first!; lineName = "row \(line! + 1)" }
                else if cols.count == 1 { line = 9 + cols.first!; lineName = "column \(line! - 8)" }
                guard let l = line else { continue }
                let elim = Grid.units[l]
                    .filter { cands[$0] & Self.bit(d) != 0 && !Grid.unitSets[b].contains($0) }
                    .map { Elimination(cell: $0, digit: d) }
                if !elim.isEmpty {
                    return Step(
                        technique: .lockedCandidates, placement: nil, eliminations: elim,
                        cells: cs, digits: [d],
                        explanation: "In \(Grid.unitName(b)), the digit \(d) can only go in \(lineName) (\(cs.map(Grid.name).joined(separator: ", "))), so \(d) can be removed from the rest of \(lineName)."
                    )
                }
            }
        }
        // Claiming: within a line, a digit confined to one box leaves the rest of that box.
        for u in 0..<18 {
            for d in 1...9 {
                let cs = cellsWith(d, in: u)
                guard cs.count >= 2 else { continue }
                let boxes = Set(cs.map { Grid.box(of: $0) })
                guard boxes.count == 1, let bx = boxes.first else { continue }
                let elim = Grid.units[18 + bx]
                    .filter { cands[$0] & Self.bit(d) != 0 && !Grid.unitSets[u].contains($0) }
                    .map { Elimination(cell: $0, digit: d) }
                if !elim.isEmpty {
                    return Step(
                        technique: .lockedCandidates, placement: nil, eliminations: elim,
                        cells: cs, digits: [d],
                        explanation: "In \(Grid.unitName(u)), the digit \(d) can only go in \(Grid.unitName(18 + bx)) (\(cs.map(Grid.name).joined(separator: ", "))), so \(d) can be removed from the rest of that box."
                    )
                }
            }
        }
        return nil
    }

    private func combinations(_ cells: [Int], _ k: Int) -> [[Int]] {
        var out: [[Int]] = []
        func go(_ start: Int, _ cur: [Int]) {
            if cur.count == k { out.append(cur); return }
            guard start < cells.count else { return }
            for i in start..<cells.count { go(i + 1, cur + [cells[i]]) }
        }
        go(0, [])
        return out
    }

    private func nakedSubset(_ k: Int, _ technique: Technique) -> Step? {
        for u in 0..<27 {
            let cells = Grid.units[u].filter {
                values[$0] == 0 && (2...k).contains(cands[$0].nonzeroBitCount)
            }
            guard cells.count >= k else { continue }
            for combo in combinations(cells, k) {
                let union = combo.reduce(UInt16(0)) { $0 | cands[$1] }
                guard union.nonzeroBitCount == k else { continue }
                var elim: [Elimination] = []
                for c in Grid.units[u] where values[c] == 0 && !combo.contains(c) {
                    for d in Self.digits(of: cands[c] & union) {
                        elim.append(Elimination(cell: c, digit: d))
                    }
                }
                if !elim.isEmpty {
                    let ds = Self.digits(of: union)
                    let word = k == 2 ? "pair" : "triple"
                    return Step(
                        technique: technique, placement: nil, eliminations: elim,
                        cells: combo, digits: ds,
                        explanation: "In \(Grid.unitName(u)), \(combo.map(Grid.name).joined(separator: ", ")) can only hold \(ds.map(String.init).joined(separator: ", ")) (a naked \(word)), so those digits can be removed from the other cells in \(Grid.unitName(u))."
                    )
                }
            }
        }
        return nil
    }

    private func hiddenPair() -> Step? {
        for u in 0..<27 {
            var pos = [[Int]](repeating: [], count: 10)
            for d in 1...9 { pos[d] = cellsWith(d, in: u) }
            let ds = (1...9).filter { pos[$0].count == 2 }
            guard ds.count >= 2 else { continue }
            for a in 0..<ds.count {
                for b in (a + 1)..<ds.count where pos[ds[a]] == pos[ds[b]] {
                    let cells = pos[ds[a]]
                    let keep = Self.bit(ds[a]) | Self.bit(ds[b])
                    var elim: [Elimination] = []
                    for c in cells {
                        for d in Self.digits(of: cands[c] & ~keep) {
                            elim.append(Elimination(cell: c, digit: d))
                        }
                    }
                    if !elim.isEmpty {
                        return Step(
                            technique: .hiddenPair, placement: nil, eliminations: elim,
                            cells: cells, digits: [ds[a], ds[b]],
                            explanation: "In \(Grid.unitName(u)), the digits \(ds[a]) and \(ds[b]) only fit in \(cells.map(Grid.name).joined(separator: " and ")) (a hidden pair), so every other candidate can be removed from those two cells."
                        )
                    }
                }
            }
        }
        return nil
    }

    private func xWing() -> Step? {
        for d in 1...9 {
            let bd = Self.bit(d)
            for byRow in [true, false] {
                // Lines where d has exactly two possible cells.
                var lines: [(line: Int, other: [Int])] = []
                for l in 0..<9 {
                    let u = byRow ? l : 9 + l
                    let cs = cellsWith(d, in: u).map { byRow ? $0 % 9 : $0 / 9 }
                    if cs.count == 2 { lines.append((l, cs)) }
                }
                guard lines.count >= 2 else { continue }
                for a in 0..<lines.count {
                    for b in (a + 1)..<lines.count where lines[a].other == lines[b].other {
                        let l1 = lines[a].line, l2 = lines[b].line
                        let others = lines[a].other
                        var elim: [Elimination] = []
                        for o in others {
                            for l in 0..<9 where l != l1 && l != l2 {
                                let cell = byRow ? l * 9 + o : o * 9 + l
                                if cands[cell] & bd != 0 { elim.append(Elimination(cell: cell, digit: d)) }
                            }
                        }
                        if !elim.isEmpty {
                            let corners = [l1, l2].flatMap { l in others.map { byRow ? l * 9 + $0 : $0 * 9 + l } }
                            let lineWord = byRow ? "rows" : "columns"
                            let crossWord = byRow ? "columns" : "rows"
                            return Step(
                                technique: .xWing, placement: nil, eliminations: elim,
                                cells: corners, digits: [d],
                                explanation: "X-Wing on \(d): in \(lineWord) \(l1 + 1) and \(l2 + 1), the digit \(d) only fits in \(crossWord) \(others.map { String($0 + 1) }.joined(separator: " and ")). So \(d) can be removed from the rest of those \(crossWord)."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    private func xyWing() -> Step? {
        for p in 0..<81 where values[p] == 0 && cands[p].nonzeroBitCount == 2 {
            let pd = Self.digits(of: cands[p])
            let x = pd[0], y = pd[1]
            let wings = Grid.peers[p].filter { values[$0] == 0 && cands[$0].nonzeroBitCount == 2 }
            for w1 in wings {
                // w1 holds {x, z}
                guard cands[w1] & Self.bit(x) != 0, cands[w1] & Self.bit(y) == 0 else { continue }
                let z = Self.digits(of: cands[w1] & ~Self.bit(x))[0]
                for w2 in wings where w2 != w1 {
                    // w2 holds {y, z}
                    guard cands[w2] == Self.bit(y) | Self.bit(z) else { continue }
                    var elim: [Elimination] = []
                    for c in 0..<81 where values[c] == 0 && c != p && c != w1 && c != w2 {
                        if Grid.isPeer(c, w1) && Grid.isPeer(c, w2) && cands[c] & Self.bit(z) != 0 {
                            elim.append(Elimination(cell: c, digit: z))
                        }
                    }
                    if !elim.isEmpty {
                        return Step(
                            technique: .xyWing, placement: nil, eliminations: elim,
                            cells: [p, w1, w2], digits: [z],
                            explanation: "XY-Wing: \(Grid.name(p)) holds \(x)/\(y), with wings \(Grid.name(w1)) (\(x)/\(z)) and \(Grid.name(w2)) (\(y)/\(z)). Whatever \(Grid.name(p)) is, one wing must be \(z), so \(z) can be removed from cells that see both wings."
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: - High-level helpers

    /// Solves with human techniques only and reports the hardest one needed.
    public static func rate(_ puzzle: [Int]) -> Rating {
        var s = Solver(puzzle: puzzle)
        var hardest: Technique?
        var steps = 0
        while !s.isSolved, let step = s.nextStep() {
            steps += 1
            if hardest == nil || step.technique > hardest! { hardest = step.technique }
            s.apply(step)
        }
        return Rating(hardest: hardest, steps: steps, solved: s.isSolved)
    }

    /// Deductions leading to the next digit placement, from the board as it stands
    /// (candidates are recomputed from placed digits, ignoring the player's notes).
    /// Returns nil if the board is contradictory or needs more than the supported techniques.
    public static func hint(for values: [Int]) -> Hint? {
        var s = Solver(puzzle: values)
        guard !s.isContradictory else { return nil }
        var steps: [Step] = []
        while let step = s.nextStep() {
            steps.append(step)
            if step.placement != nil { return Hint(steps: steps) }
            s.apply(step)
        }
        return nil
    }
}
