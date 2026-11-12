import SwiftUI

/// What the hint sheet shows, and which cells the board should highlight.
struct HintInfo: Equatable {
    enum Kind { case technique, mistake, ok, guess }

    var kind: Kind
    var title: String
    var lines: [String]
    /// Cells forming the pattern (or the wrong cells for a mistake).
    var cells: [Int]
    /// Cell the hint would fill, and the digit.
    var target: Int?
    var digit: Int?

    var canReveal: Bool { target != nil && digit != nil }
}

struct HintSheet: View {
    let info: HintInfo
    let reveal: () -> Void
    let dismiss: () -> Void

    private var icon: String {
        switch info.kind {
        case .technique: return "lightbulb.fill"
        case .mistake: return "exclamationmark.triangle.fill"
        case .ok: return "checkmark.seal.fill"
        case .guess: return "questionmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch info.kind {
        case .technique, .guess: return .orange
        case .mistake: return .red
        case .ok: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(info.title).font(.headline)
                Spacer()
                Button("Close", action: dismiss)
                    .buttonStyle(.glass)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(info.lines.enumerated()), id: \.offset) { index, line in
                        Text(info.lines.count > 1 ? "\(index + 1). \(line)" : line)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if info.canReveal {
                Button(action: reveal) {
                    Text("Show answer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding()
        .presentationDetents([.height(250), .medium])
        .presentationBackgroundInteraction(.enabled(upThrough: .height(250)))
        .presentationDragIndicator(.visible)
    }
}
