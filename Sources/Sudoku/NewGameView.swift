import SudokuCore
import SwiftUI

/// Pick a mode (Classic or Zen) and one of the six difficulty levels.
struct NewGameView: View {
    let onStart: (Difficulty, Bool) -> Void

    @State private var zen = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Mode", selection: $zen) {
                    Text("Classic").tag(false)
                    Text("Zen").tag(true)
                }
                .pickerStyle(.segmented)

                Text(zen
                     ? "No timer, no mistake pressure, nothing recorded. Just the puzzle."
                     : "Timed, with mistakes counted and your stats recorded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(Difficulty.allCases) { d in
                    row(d)
                }
            }
            .padding()
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ d: Difficulty) -> some View {
        Button { onStart(d, zen) } label: {
            HStack(spacing: 14) {
                DifficultyMeter(level: d)
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.rawValue).font(.headline)
                    Text(d.blurb).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
