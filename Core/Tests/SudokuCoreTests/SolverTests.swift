import Foundation
import Testing
@testable import SudokuCore

@Suite struct SolverTests {
    /// A well-known puzzle that is solvable with singles only.
    private let classic: [Int] = {
        let s = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
        return s.map { Int(String($0))! }
    }()

    @Test func classicPuzzleIsSolvedWithSinglesOnly() {
        let r = Solver.rate(classic)
        #expect(r.solved)
        #expect(r.level <= .easy)
    }

    @Test func geometryIsConsistent() {
        #expect(Grid.units.count == 27)
        #expect(Grid.units.allSatisfy { $0.count == 9 })
        #expect(Grid.peers.allSatisfy { $0.count == 20 })
        #expect(Grid.box(of: 0) == 0 && Grid.box(of: 80) == 8 && Grid.box(of: 40) == 4)
        #expect(Grid.name(0) == "R1C1" && Grid.name(80) == "R9C9")
    }

    /// Every deduction the solver makes must agree with the true solution.
    /// This is the main safety net for all technique implementations.
    @Test func everyStepAgreesWithTheSolution() {
        var rng = SplitMix64(seed: "solver-soundness")
        var techniquesSeen = Set<Technique>()
        for level in Difficulty.allCases {
            for _ in 0..<6 {
                let (puzzle, solution) = SudokuEngine.generate(level, using: &rng)
                var s = Solver(puzzle: puzzle)
                while !s.isSolved, let step = s.nextStep() {
                    techniquesSeen.insert(step.technique)
                    if let p = step.placement {
                        #expect(p.digit == solution[p.cell], "\(step.technique) placed a wrong digit")
                    }
                    for e in step.eliminations {
                        #expect(e.digit != solution[e.cell], "\(step.technique) removed the solution digit")
                    }
                    s.apply(step)
                }
            }
        }
        print("techniques exercised:", techniquesSeen.sorted().map(\.title))
    }

    @Test func hintPlacementMatchesSolutionAndEndsWithAPlacement() {
        var rng = SplitMix64(seed: "hint")
        let (puzzle, solution) = SudokuEngine.generate(.hard, using: &rng)
        guard let hint = Solver.hint(for: puzzle) else {
            Issue.record("expected a hint for a freshly generated puzzle")
            return
        }
        #expect(hint.placement.digit == solution[hint.placement.cell])
        #expect(hint.steps.dropLast().allSatisfy { $0.placement == nil })
        #expect(!hint.final.explanation.isEmpty)
    }

    @Test func hintIsNilForContradictoryBoard() {
        var board = [Int](repeating: 0, count: 81)
        // Cell 0 sees 1-8 in its row and 9 in its column: no candidate left.
        for d in 1...8 { board[d] = d }
        board[9] = 9
        #expect(Solver.hint(for: board) == nil)
    }

    @Test func generatedLevelsMatchRequestedLevel() {
        var rng = SplitMix64(seed: "levels")
        var report: [String] = []
        for level in Difficulty.allCases {
            var exact = 0
            let n = 6
            let start = Date()
            for _ in 0..<n {
                let (puzzle, _) = SudokuEngine.generate(level, using: &rng)
                var copy = puzzle
                #expect(SudokuEngine.countSolutions(&copy, limit: 2) == 1)
                if Solver.rate(puzzle).level == level { exact += 1 }
            }
            let ms = Int(Date().timeIntervalSince(start) * 1000 / Double(n))
            report.append("\(level.rawValue): \(exact)/\(n) exact, ~\(ms) ms each")
            #expect(exact >= n / 2, "\(level.rawValue) rarely hits its level")
        }
        print(report.joined(separator: "\n"))
    }
}
