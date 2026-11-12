import SudokuCore

/// Short lesson text for each solving technique.
extension Technique {
    var summary: String {
        switch self {
        case .nakedSingle: return "A cell with only one possible digit left."
        case .hiddenSingle: return "A digit that fits in only one cell of a row, column or box."
        case .lockedCandidates: return "A digit trapped on one line inside a box, or in one box along a line."
        case .nakedPair: return "Two cells in a group that share the same two candidates."
        case .hiddenPair: return "Two digits that only fit in the same two cells of a group."
        case .nakedTriple: return "Three cells that between them hold only three digits."
        case .xWing: return "A digit forming a rectangle across two rows and two columns."
        case .xyWing: return "A pivot cell and two wings that force a shared digit."
        }
    }

    var lesson: [String] {
        switch self {
        case .nakedSingle:
            return [
                "Look at one empty cell and cross off every digit already used in its row, column and box.",
                "If only a single digit survives, it has to go in that cell. With pencil marks it's the cell that shows just one note.",
            ]
        case .hiddenSingle:
            return [
                "Pick a row, column or box and a digit. If that digit's pencil mark appears in just one cell of the group, that cell must hold it, even if the cell lists other candidates too.",
                "It's called hidden because the cell still shows several notes, which hide the fact that this digit has nowhere else to go.",
            ]
        case .lockedCandidates:
            return [
                "Pointing: inside a box, if a digit can only go in one row or column, it can't appear anywhere else on that row or column outside the box.",
                "Claiming: along a row or column, if a digit can only go in one box, it can't appear in the rest of that box.",
            ]
        case .nakedPair:
            return [
                "If two cells in a row, column or box contain only the same two digits, those digits must go in those two cells, in some order.",
                "That means both digits can be removed from every other cell in the group.",
            ]
        case .hiddenPair:
            return [
                "If two digits appear as candidates in only the same two cells of a group, those two cells must hold those two digits.",
                "So every other candidate can be removed from those two cells.",
            ]
        case .nakedTriple:
            return [
                "Three cells in a group whose candidates are all drawn from the same three digits must hold those three digits. Each cell may list only two or three of them.",
                "Remove the three digits from every other cell in the group.",
            ]
        case .xWing:
            return [
                "If a digit can go in exactly two cells in each of two rows, and those cells line up in the same two columns, the digit must sit on opposite corners of that rectangle.",
                "So the digit can be removed from everywhere else in those two columns. The same idea works turned sideways, with columns and rows swapped.",
            ]
        case .xyWing:
            return [
                "Find a pivot cell with two candidates X and Y. Find a wing that sees the pivot with candidates X and Z, and another wing that sees the pivot with Y and Z.",
                "Whatever the pivot turns out to be, one of the wings must be Z. So Z can be removed from any cell that sees both wings.",
            ]
        }
    }
}
