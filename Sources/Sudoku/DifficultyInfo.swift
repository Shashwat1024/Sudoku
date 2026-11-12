import SudokuCore
import SwiftUI

extension Difficulty {
    /// What kind of reasoning the level needs.
    var blurb: String {
        switch self {
        case .beginner: return "Singles only. A relaxed start."
        case .easy: return "Adds hidden singles."
        case .medium: return "Needs locked candidates."
        case .hard: return "Pairs and triples."
        case .expert: return "X-Wing and XY-Wing."
        case .master: return "Beyond the techniques taught here."
        }
    }

    var color: Color {
        switch self {
        case .beginner: return .green
        case .easy: return .mint
        case .medium: return .yellow
        case .hard: return .orange
        case .expert: return .red
        case .master: return .purple
        }
    }
}

/// Six small bars, filled up to the level.
struct DifficultyMeter: View {
    let level: Difficulty

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<Difficulty.allCases.count, id: \.self) { i in
                Capsule()
                    .fill(i <= level.rank ? level.color : Color.secondary.opacity(0.25))
                    .frame(width: 5, height: 18)
            }
        }
    }
}
