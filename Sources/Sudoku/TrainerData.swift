import Foundation
import Observation
import SudokuCore

/// The bundled practice positions (see the PoolGen tool in Core), grouped by technique.
struct TrainerPool: Sendable {
    let byTechnique: [Technique: [TrainerPosition]]

    static let shared = TrainerPool.load()

    func positions(_ t: Technique) -> [TrainerPosition] { byTechnique[t] ?? [] }

    private static func load() -> TrainerPool {
        guard let url = Bundle.main.url(forResource: "trainer", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let all = try? JSONDecoder().decode([TrainerPosition].self, from: data)
        else { return TrainerPool(byTechnique: [:]) }
        var grouped: [Technique: [TrainerPosition]] = [:]
        // Drop anything that doesn't reproduce its own deduction.
        for p in all where Trainer.isConsistent(p) { grouped[p.technique, default: []].append(p) }
        return TrainerPool(byTechnique: grouped)
    }
}

/// Best quiz score per technique.
@MainActor
@Observable
final class TrainerStore {
    static let questionCount = 5

    private(set) var best: [Int: Int] = [:]

    private let storeKey = "sudoku.trainer"

    init() { load() }

    func bestScore(_ t: Technique) -> Int { best[t.rawValue] ?? 0 }

    /// Techniques answered perfectly at least once.
    var mastered: Int {
        Technique.allCases.filter { bestScore($0) >= Self.questionCount }.count
    }

    func record(_ t: Technique, score: Int) {
        guard score > bestScore(t) else { return }
        best[t.rawValue] = score
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(best) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let b = try? JSONDecoder().decode([Int: Int].self, from: data)
        else { return }
        best = b
    }
}
