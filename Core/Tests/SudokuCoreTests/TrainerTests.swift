import Foundation
import Testing
@testable import SudokuCore

@Suite struct TrainerTests {
    @Test func capturedPositionsAreConsistentAndSound() {
        var rng = SplitMix64(seed: "trainer-positions")
        var checked = 0
        var byTechnique: [Technique: Int] = [:]
        for level in [Difficulty.medium, .hard, .expert, .master] {
            for _ in 0..<4 {
                let (puzzle, solution) = SudokuEngine.generate(level, using: &rng)
                for p in Trainer.positions(from: puzzle) {
                    checked += 1
                    byTechnique[p.technique, default: 0] += 1
                    // Restoring the solver from the saved position reproduces the step.
                    #expect(Trainer.isConsistent(p), "\(p.technique) position is not reproducible")
                    // The deduction itself agrees with the true solution.
                    if let pl = p.step.placement { #expect(pl.digit == solution[pl.cell]) }
                    for e in p.step.eliminations { #expect(e.digit != solution[e.cell]) }
                    // It is the easiest technique available (nothing simpler applies).
                    #expect(p.step.technique == p.technique)
                    #expect(Solver(values: p.values, cands: p.cands).nextStep(maxTechnique: p.technique)?.technique == p.technique)
                }
            }
        }
        #expect(checked > 0)
        print("positions checked:", checked, byTechnique.sorted { $0.key < $1.key }.map { "\($0.key.title)=\($0.value)" })
    }

    @Test func positionsRoundTripThroughJSON() throws {
        var rng = SplitMix64(seed: "trainer-json")
        let (puzzle, _) = SudokuEngine.generate(.hard, using: &rng)
        let positions = Trainer.positions(from: puzzle)
        #expect(!positions.isEmpty)
        let data = try JSONEncoder().encode(positions)
        let back = try JSONDecoder().decode([TrainerPosition].self, from: data)
        #expect(back == positions)
        #expect(back.allSatisfy(Trainer.isConsistent))
    }

    @Test func notesMatchCandidateMasks() {
        var rng = SplitMix64(seed: "trainer-notes")
        let (puzzle, _) = SudokuEngine.generate(.medium, using: &rng)
        guard let p = Trainer.positions(from: puzzle).first else { Issue.record("no position"); return }
        let notes = p.notes
        #expect(notes.count == 81)
        for i in 0..<81 {
            if p.values[i] != 0 { #expect(notes[i].isEmpty) }
            else { #expect(notes[i].count == p.cands[i].nonzeroBitCount) }
        }
    }

    @Test func inconsistentPositionIsRejected() {
        var rng = SplitMix64(seed: "trainer-bad")
        let (puzzle, _) = SudokuEngine.generate(.medium, using: &rng)
        guard var p = Trainer.positions(from: puzzle).first else { Issue.record("no position"); return }
        p.step.explanation = "tampered"
        #expect(!Trainer.isConsistent(p))
        p.cands = []
        #expect(!Trainer.isConsistent(p))
    }
}
