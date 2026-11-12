import AudioToolbox
import Foundation
import Observation
import SudokuCore

private struct SavedGame: Codable {
    var difficulty: Difficulty
    var puzzle: [Int]
    var solution: [Int]
    var values: [Int]
    var notes: [[Int]]
    var mistakes: Int
    var seconds: Int
    var hintsUsed: Int?
    var gameOver: Bool?
    var moves: [Move]?
    var mode: GameMode?
    var ghost: GhostRun?
}

/// How the current game was started.
enum GameMode: Codable, Equatable, Sendable {
    case classic
    /// Today's daily puzzle, identified by its date key.
    case daily(String)
    /// No timer, no mistake pressure, no stats.
    case zen
}

enum GameEvent: Equatable, Sendable {
    case none, place, erase, mistake, complete, over
}

@MainActor
@Observable
final class Game {
    private struct Snapshot {
        var values: [Int]
        var notes: [Set<Int>]
    }

    let stats = Stats()
    let daily = DailyStore()
    let gameHistory = HistoryStore()

    var mode: GameMode = .classic
    var difficulty: Difficulty = .easy
    var puzzle: [Int] = Array(repeating: 0, count: 81)
    var solution: [Int] = Array(repeating: 0, count: 81)
    var values: [Int] = Array(repeating: 0, count: 81)
    var notes: [Set<Int>] = Array(repeating: [], count: 81)
    var selected: Int?
    var notesMode = false
    var mistakes = 0
    var hintsUsed = 0
    var seconds = 0
    var isComplete = false
    var isGameOver = false
    var isPaused = false
    var isGenerating = false
    var lastWinWasBest = false
    var hintInfo: HintInfo?
    /// A recorded run racing alongside this game, if any.
    var ghost: GhostRun?
    /// Result line for a finished race ("You beat ... by 0:12").
    var ghostResult: String?
    /// The record of the game that just ended (for "Review").
    var lastRecord: GameRecord?
    /// The player has seen the result alert for the finished game.
    var resultAcknowledged = false

    /// Every action this game, in order. Feeds replay, heatmap and ghost features.
    private(set) var moves: [Move] = []

    /// Bumped on every feedback-worthy event so the view can trigger haptics.
    var eventID = 0
    var lastEvent: GameEvent = .none

    private var history: [Snapshot] = []
    private var generationID = 0
    private let saveKey = "sudoku.savedGame"

    /// False until a game has been loaded or started. There is deliberately no
    /// hidden game at launch: that would show a phantom "Continue" and inflate stats.
    private(set) var hasGame = false

    init() {
        hasGame = load()
    }

    /// Called when the result alert is dismissed. Ignored if a new game or retry has
    /// already cleared the finished state (SwiftUI runs the dismiss handler after the
    /// button action, which would otherwise mark the *new* game's result as seen).
    func acknowledgeResult() {
        if isComplete || isGameOver { resultAcknowledged = true }
    }

    // MARK: - Lifecycle

    /// A random puzzle at the given level (Zen mode if requested).
    func newGame(_ difficulty: Difficulty, mode: GameMode = .classic) {
        startGame(difficulty: difficulty, mode: mode) { SudokuEngine.generate(difficulty) }
    }

    /// Today's daily puzzle. Does nothing if it's already the game in progress.
    func startDaily() {
        let key = DailyPuzzle.todayKey()
        if isTodaysDailyActive { return }
        let d = DailyPuzzle.difficulty(forKey: key)
        startGame(difficulty: d, mode: .daily(key)) {
            let made = DailyPuzzle.make(forKey: key)
            return (made.puzzle, made.solution)
        }
    }

    /// True while the player is partway through today's daily puzzle.
    var isTodaysDailyActive: Bool {
        mode == .daily(DailyPuzzle.todayKey()) && !isComplete && !isGameOver
    }

    /// A puzzle the player scanned or typed in. It must have exactly one solution.
    func startImported(puzzle: [Int], solution: [Int]) {
        let level = Solver.rate(puzzle).level
        startGame(difficulty: level, mode: .classic) { (puzzle, solution) }
    }

    /// Race a recorded run on the same puzzle.
    func startGhostRace(_ setup: GhostSetup) {
        startGame(difficulty: setup.difficulty, mode: .classic, ghost: setup.run) {
            (setup.puzzle, setup.solution)
        }
    }

    /// Generates off the main thread, then swaps the new puzzle in.
    private func startGame(
        difficulty: Difficulty, mode: GameMode, ghost: GhostRun? = nil,
        generate: @escaping @Sendable () -> (puzzle: [Int], solution: [Int])
    ) {
        // Abandoning a tracked game (not Zen) resets the win streak.
        if isInProgress && tracksStats { stats.recordLoss() }
        // Clear end-of-game flags now so the result alert doesn't reappear.
        isComplete = false
        isGameOver = false
        isPaused = false
        isGenerating = true
        generationID += 1
        let id = generationID

        Task {
            let generated = await Task.detached(priority: .userInitiated) {
                generate()
            }.value
            // A newer request superseded this one.
            guard id == generationID else { return }
            self.difficulty = difficulty
            self.mode = mode
            puzzle = generated.puzzle
            solution = generated.solution
            resetProgress()
            self.ghost = ghost
            hasGame = true
            isGenerating = false
            if tracksStats { stats.recordStart(difficulty) }
            save()
        }
    }

    /// Zen games don't touch statistics or streaks.
    private var tracksStats: Bool { mode != .zen }

    /// Restart the current puzzle from scratch.
    func retry() {
        resetProgress()
        if tracksStats { stats.recordStart(difficulty) }
        save()
    }

    private func resetProgress() {
        values = puzzle
        notes = Array(repeating: [], count: 81)
        selected = nil
        notesMode = false
        mistakes = 0
        hintsUsed = 0
        seconds = 0
        isComplete = false
        isGameOver = false
        isPaused = false
        lastWinWasBest = false
        ghostResult = nil
        lastRecord = nil
        resultAcknowledged = false
        hintInfo = nil
        history = []
        moves = []
    }

    func tick() {
        guard !isPaused, !isComplete, !isGameOver, !isGenerating else { return }
        seconds += 1
        if seconds % 5 == 0 { save() }
    }

    func pause() {
        guard !isComplete, !isGameOver, !isGenerating else { return }
        isPaused = true
    }

    func resume() { isPaused = false }

    // MARK: - Queries

    /// Played at least one move and not finished: abandoning it loses progress.
    var isInProgress: Bool {
        !isGenerating && !isComplete && !isGameOver && values != puzzle
    }

    /// A game exists that can be resumed, even if no digit has been placed yet.
    var hasUnfinishedGame: Bool {
        hasGame && !isGenerating && !isComplete && !isGameOver
    }

    /// How far the racing ghost has got at the current game time (0...1).
    var ghostProgress: Double? {
        guard let g = ghost else { return nil }
        let s = Replay.state(puzzle: puzzle, moves: g.moves, atTime: seconds)
        return Completion.fraction(values: s.values, puzzle: puzzle, solution: solution)
    }
    var canPlay: Bool { !isComplete && !isGameOver && !isPaused && !isGenerating }
    var canUndo: Bool { canPlay && !history.isEmpty }
    /// Zen mode never ends a game over mistakes.
    var mistakeLimit: Int { mode == .zen ? 0 : Pref.int(Pref.mistakeLimit, 0) }

    func isGiven(_ i: Int) -> Bool { puzzle[i] != 0 }

    func isWrong(_ i: Int) -> Bool {
        values[i] != 0 && values[i] != solution[i]
    }

    func isPeer(_ a: Int, _ b: Int) -> Bool {
        a / 9 == b / 9 || a % 9 == b % 9
            || (a / 27 == b / 27 && (a % 9) / 3 == (b % 9) / 3)
    }

    func remaining(_ n: Int) -> Int {
        var placed = 0
        for i in 0..<81 where values[i] == n && values[i] == solution[i] { placed += 1 }
        return 9 - placed
    }

    var timeString: String { formatTime(seconds) }

    /// Share of the empty cells that currently hold the correct digit (0...1).
    var progress: Double {
        let empty = puzzle.filter { $0 == 0 }.count
        guard empty > 0 else { return 1 }
        let correct = (0..<81).filter { puzzle[$0] == 0 && values[$0] == solution[$0] }.count
        return Double(correct) / Double(empty)
    }

    // MARK: - Actions

    func select(_ i: Int) {
        guard !isPaused, !isGenerating else { return }
        selected = i
    }

    func input(_ n: Int) {
        guard canPlay, let i = selected, !isGiven(i) else { return }
        hintInfo = nil
        if notesMode {
            guard values[i] == 0 else { return }
            record(Move(cell: i, value: n, kind: .note, t: seconds))
            if notes[i].contains(n) { notes[i].remove(n) } else { notes[i].insert(n) }
            fire(.place, digit: n)
        } else {
            guard values[i] != n else { return }
            record(Move(cell: i, value: n, kind: .place, t: seconds))
            values[i] = n
            notes[i] = []
            if n == solution[i] {
                if Pref.bool(Pref.autoNotes, true) {
                    for j in 0..<81 where isPeer(i, j) { notes[j].remove(n) }
                }
                fire(.place, digit: n)
            } else {
                mistakes += 1
                fire(.mistake)
            }
            checkEnd()
        }
        save()
    }

    func erase() {
        guard canPlay, let i = selected, !isGiven(i) else { return }
        guard values[i] != 0 || !notes[i].isEmpty else { return }
        hintInfo = nil
        record(Move(cell: i, value: 0, kind: .erase, t: seconds))
        values[i] = 0
        notes[i] = []
        fire(.erase)
        save()
    }

    func undo() {
        guard canUndo, let last = history.popLast() else { return }
        hintInfo = nil
        values = last.values
        notes = last.notes
        if !moves.isEmpty { moves.removeLast() }
        save()
    }

    // MARK: - Hints and checking

    /// Teaching hint: explains the next deduction; the player can then reveal it.
    func hint() {
        guard canPlay else { return }
        // Mistakes first: a hint on a wrong board would teach the wrong thing.
        if let m = Checker.earliestMistake(moves: moves, values: values, solution: solution) {
            hintInfo = mistakeInfo(m)
            return
        }
        if let h = Solver.hint(for: values) {
            let target = h.placement.cell
            selected = target
            hintInfo = HintInfo(
                kind: .technique,
                title: h.final.technique.title,
                lines: h.steps.map(\.explanation),
                cells: Array(Set(h.steps.flatMap(\.cells))).sorted(),
                target: target,
                digit: h.placement.digit
            )
        } else if let i = fallbackCell() {
            selected = i
            hintInfo = HintInfo(
                kind: .guess,
                title: "Needs deeper logic",
                lines: ["None of the techniques this app teaches apply here, so this step needs trial and error. You can reveal the answer for the highlighted cell."],
                cells: [], target: i, digit: solution[i]
            )
        }
    }

    /// "Where did I go wrong?" Finds the earliest mistake still on the board.
    func check() {
        guard canPlay else { return }
        if let m = Checker.earliestMistake(moves: moves, values: values, solution: solution) {
            hintInfo = mistakeInfo(m)
        } else {
            hintInfo = HintInfo(
                kind: .ok, title: "No mistakes so far",
                lines: ["Everything you've placed is consistent with the solution."],
                cells: [], target: nil, digit: nil
            )
        }
    }

    /// Fills in the cell the current hint pointed at.
    func revealHint() {
        guard canPlay, let info = hintInfo, let i = info.target, let d = info.digit else { return }
        hintInfo = nil
        record(Move(cell: i, value: d, kind: .hint, t: seconds))
        hintsUsed += 1
        selected = i
        values[i] = d
        notes[i] = []
        for j in 0..<81 where isPeer(i, j) { notes[j].remove(d) }
        fire(.place, digit: d)
        checkEnd()
        save()
    }

    func dismissHint() { hintInfo = nil }

    private func fallbackCell() -> Int? {
        if let s = selected, !isGiven(s), values[s] != solution[s] { return s }
        return (0..<81).first { values[$0] != solution[$0] }
    }

    private func mistakeInfo(_ m: Checker.Mistake) -> HintInfo {
        let name = Grid.name(m.cell)
        var cells = [m.cell]
        let text: String
        if let other = m.conflictsWith {
            cells.append(other)
            text = "\(name) and \(Grid.name(other)) both contain \(m.digit), so one of them is wrong. \(name) is the earliest suspect on your board."
        } else {
            text = "\(name) contains a \(m.digit) that can't be part of the solution. It doesn't clash with anything yet, but it will lead to a contradiction later."
        }
        return HintInfo(
            kind: .mistake, title: "Check your work",
            lines: [text], cells: cells, target: nil, digit: nil
        )
    }

    // MARK: - Private

    /// Logs a move and snapshots the board so the move can be undone.
    /// History and the move log stay 1:1, so undo pops both.
    private func record(_ move: Move) {
        history.append(Snapshot(values: values, notes: notes))
        if history.count > 200 { history.removeFirst() }
        moves.append(move)
    }

    private func checkEnd() {
        if values == solution {
            isComplete = true
            if tracksStats {
                lastWinWasBest = stats.recordWin(
                    difficulty, seconds: seconds, eligibleForBest: hintsUsed == 0
                )
            }
            // Only today's puzzle counts toward the daily streak.
            if case .daily(let key) = mode, key == DailyPuzzle.todayKey() {
                daily.record(key: key, seconds: seconds, hints: hintsUsed, mistakes: mistakes)
            }
            if let g = ghost { ghostResult = raceResult(against: g) }
            recordHistory(completed: true)
            fire(.complete)
        } else if mistakeLimit > 0 && mistakes >= mistakeLimit {
            isGameOver = true
            if tracksStats { stats.recordLoss() }
            recordHistory(completed: false)
            fire(.over)
        }
    }

    private func recordHistory(completed: Bool) {
        let record = GameRecord(
            date: Date(), difficulty: difficulty, mode: mode,
            puzzle: puzzle, solution: solution, moves: moves,
            seconds: seconds, mistakes: mistakes, hints: hintsUsed, completed: completed
        )
        lastRecord = record
        gameHistory.add(record)
    }

    private func raceResult(against g: GhostRun) -> String {
        let diff = g.seconds - seconds
        if diff > 0 { return "You beat \(g.title) by \(formatTime(diff))." }
        if diff < 0 {
            let name = g.title.prefix(1).uppercased() + String(g.title.dropFirst())
            return "\(name) won by \(formatTime(-diff))."
        }
        return "Dead heat with \(g.title)."
    }

    private func fire(_ event: GameEvent, digit: Int? = nil) {
        lastEvent = event
        eventID += 1
        guard Pref.bool(Pref.sounds, false) else { return }
        // Zen mode replaces system sounds with soft bell tones, one note per digit.
        if mode == .zen {
            if event == .place, let digit { ZenTones.shared.play(digit: digit) }
            return
        }
        let sound: SystemSoundID
        switch event {
        case .place, .erase: sound = 1104
        case .mistake, .over: sound = 1053
        case .complete: sound = 1025
        case .none: return
        }
        AudioServicesPlaySystemSound(sound)
    }

    // MARK: - Persistence

    private func save() {
        guard !isGenerating else { return }
        let saved = SavedGame(
            difficulty: difficulty, puzzle: puzzle, solution: solution,
            values: values, notes: notes.map { Array($0) },
            mistakes: mistakes, seconds: seconds,
            hintsUsed: hintsUsed, gameOver: isGameOver, moves: moves, mode: mode,
            ghost: ghost
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let s = try? JSONDecoder().decode(SavedGame.self, from: data),
              s.puzzle.count == 81, s.solution.count == 81,
              s.values.count == 81, s.notes.count == 81,
              s.values != s.solution
        else { return false }
        difficulty = s.difficulty
        puzzle = s.puzzle
        solution = s.solution
        values = s.values
        notes = s.notes.map { Set($0) }
        mistakes = s.mistakes
        seconds = s.seconds
        hintsUsed = s.hintsUsed ?? 0
        isGameOver = s.gameOver ?? false
        moves = s.moves ?? []
        mode = s.mode ?? .classic
        ghost = s.ghost
        return true
    }
}
