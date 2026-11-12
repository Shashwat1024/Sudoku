import Foundation
import Observation
import SudokuCore

/// A recorded run that can be raced against.
struct GhostRun: Codable, Equatable, Sendable {
    var moves: [Move]
    var seconds: Int
    var title: String
}

/// Everything needed to start a race: the puzzle and the run to race.
struct GhostSetup: Equatable, Identifiable, Sendable {
    let id = UUID()
    var puzzle: [Int]
    var solution: [Int]
    var difficulty: Difficulty
    var run: GhostRun
}

/// A finished (or failed) game with its full move log.
struct GameRecord: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var date: Date
    var difficulty: Difficulty
    var mode: GameMode
    var puzzle: [Int]
    var solution: [Int]
    var moves: [Move]
    var seconds: Int
    var mistakes: Int
    var hints: Int
    var completed: Bool

    var modeLabel: String {
        switch mode {
        case .classic: return difficulty.rawValue
        case .daily: return "Daily · \(difficulty.rawValue)"
        case .zen: return "Zen · \(difficulty.rawValue)"
        }
    }

    var ghostSetup: GhostSetup {
        GhostSetup(
            puzzle: puzzle, solution: solution, difficulty: difficulty,
            run: GhostRun(moves: moves, seconds: seconds, title: "your earlier run")
        )
    }

    var shareCode: String {
        GhostCode.encode(.init(puzzle: puzzle, moves: moves, seconds: seconds))
    }
}

/// The most recent finished games, kept in a JSON file in Application Support.
@MainActor
@Observable
final class HistoryStore {
    private(set) var records: [GameRecord] = []

    private let limit = 30
    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func add(_ record: GameRecord) {
        records.insert(record, at: 0)
        if records.count > limit { records.removeLast(records.count - limit) }
        save()
    }

    func clear() {
        records = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let r = try? JSONDecoder().decode([GameRecord].self, from: data)
        else { return }
        records = r
    }
}
