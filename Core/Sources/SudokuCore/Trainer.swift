import Foundation

/// A real mid-solve position in which `technique` is the easiest deduction
/// available, so it is exactly the one the solver would use next.
public struct TrainerPosition: Codable, Equatable, Sendable {
    public var technique: Technique
    public var values: [Int]
    /// Candidate bitmask per cell (bit d set = digit d possible), as in `Solver`.
    public var cands: [UInt16]
    public var step: Step

    public init(technique: Technique, values: [Int], cands: [UInt16], step: Step) {
        self.technique = technique
        self.values = values
        self.cands = cands
        self.step = step
    }

    /// Candidate digits per cell as sets (empty for filled cells).
    public var notes: [Set<Int>] {
        (0..<81).map { i in
            guard values[i] == 0 else { return [] }
            return Set((1...9).filter { cands[i] & (1 << UInt16($0)) != 0 })
        }
    }
}

public enum Trainer {
    /// Walks a full solver run and captures the first position at which each
    /// technique is used. Techniques that never occur are simply absent.
    public static func positions(from puzzle: [Int]) -> [TrainerPosition] {
        var solver = Solver(puzzle: puzzle)
        var seen = Set<Technique>()
        var out: [TrainerPosition] = []
        while !solver.isSolved, let step = solver.nextStep() {
            if seen.insert(step.technique).inserted {
                out.append(TrainerPosition(
                    technique: step.technique, values: solver.values,
                    cands: solver.cands, step: step
                ))
            }
            solver.apply(step)
        }
        return out
    }

    /// Checks a stored position is internally consistent: the solver restored
    /// from it would make exactly the recorded deduction.
    public static func isConsistent(_ p: TrainerPosition) -> Bool {
        guard p.values.count == 81, p.cands.count == 81 else { return false }
        return Solver(values: p.values, cands: p.cands).nextStep() == p.step
    }
}
