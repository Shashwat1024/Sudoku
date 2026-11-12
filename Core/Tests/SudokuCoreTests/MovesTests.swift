import Foundation
import Testing
@testable import SudokuCore

@Suite struct MovesTests {
    private let blank = [Int](repeating: 0, count: 81)

    @Test func placeThenEraseRestoresEmptyCell() {
        let moves = [
            Move(cell: 4, value: 7, kind: .place, t: 1),
            Move(cell: 4, value: 0, kind: .erase, t: 2),
        ]
        #expect(Replay.state(puzzle: blank, moves: moves).values == blank)
        #expect(Replay.state(puzzle: blank, moves: moves, upTo: 1).values[4] == 7)
    }

    @Test func noteTogglesOnAndOff() {
        let toggle = Move(cell: 0, value: 3, kind: .note, t: 1)
        #expect(Replay.state(puzzle: blank, moves: [toggle]).notes[0] == [3])
        #expect(Replay.state(puzzle: blank, moves: [toggle, toggle]).notes[0].isEmpty)
    }

    @Test func placingClearsNotesInThatCell() {
        let moves = [
            Move(cell: 2, value: 1, kind: .note, t: 1),
            Move(cell: 2, value: 5, kind: .place, t: 2),
        ]
        let s = Replay.state(puzzle: blank, moves: moves)
        #expect(s.values[2] == 5)
        #expect(s.notes[2].isEmpty)
    }

    @Test func replayOfFullSolutionMovesReproducesSolution() {
        let (puzzle, solution) = SudokuEngine.generate(.beginner)
        var moves: [Move] = []
        var t = 0
        for i in 0..<81 where puzzle[i] == 0 {
            t += 1
            moves.append(Move(cell: i, value: solution[i], kind: i % 7 == 0 ? .hint : .place, t: t))
        }
        #expect(Replay.state(puzzle: puzzle, moves: moves).values == solution)
    }

    @Test func movesRoundTripThroughJSON() throws {
        let moves = [Move(cell: 10, value: 9, kind: .hint, t: 42)]
        let data = try JSONEncoder().encode(moves)
        #expect(try JSONDecoder().decode([Move].self, from: data) == moves)
    }
}
