import SwiftUI

/// Undo / Erase / Notes / Hint / Check row, each a Liquid Glass key.
struct ControlsView: View {
    let game: Game
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                button("Undo", "arrow.uturn.backward", enabled: game.canUndo) { game.undo() }
                button("Erase", "eraser") { game.erase() }
                button("Notes", game.notesMode ? "pencil.circle.fill" : "pencil.circle",
                       active: game.notesMode) {
                    game.notesMode.toggle()
                }
                button("Hint", "lightbulb") { game.hint() }
                button("Check", "checkmark.circle") { game.check() }
            }
        }
    }

    private func button(
        _ title: String, _ icon: String, enabled: Bool = true, active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        let usable = enabled && game.canPlay
        return Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .foregroundStyle(usable ? theme.accent : Color.secondary)
            .glassSurface(
                RoundedRectangle(cornerRadius: 18, style: .continuous),
                tint: active ? theme.accent : nil
            )
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .opacity(usable ? 1 : 0.55)
    }
}

/// 1-9 keys with remaining counts, as Liquid Glass keys.
struct NumberPadView: View {
    let game: Game
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(1...9, id: \.self) { n in
                    let left = game.remaining(n)
                    if left == 0 {
                        // All nine placed: drop the glass and the count, leave a faint ghost digit.
                        Text("\(n)")
                            .font(.title.weight(.regular))
                            .foregroundStyle(theme.given.opacity(0.16))
                            .frame(maxWidth: .infinity, minHeight: 64)
                    } else {
                        let usable = game.canPlay
                        Button { game.input(n) } label: {
                            VStack(spacing: 2) {
                                Text("\(n)").font(.title.weight(.regular))
                                Text("\(left)").font(.caption2).foregroundStyle(.secondary)
                            }
                            .foregroundStyle(theme.given)
                            .frame(maxWidth: .infinity, minHeight: 64)
                            .glassSurface(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!usable)
                        .opacity(usable ? 1 : 0.35)
                    }
                }
            }
        }
    }
}
