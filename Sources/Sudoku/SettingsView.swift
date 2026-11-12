import SudokuCore
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Pref.haptics) private var haptics = true
    @AppStorage(Pref.sounds) private var sounds = false
    @AppStorage(Pref.showMistakes) private var showMistakes = true
    @AppStorage(Pref.highlightSame) private var highlightSame = true
    @AppStorage(Pref.autoNotes) private var autoNotes = true
    @AppStorage(Pref.mistakeLimit) private var mistakeLimit = 0
    @AppStorage(Pref.theme) private var themeName = Theme.classic.id

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptics", isOn: $haptics)
                    Toggle("Sounds", isOn: $sounds)
                }

                Section {
                    Toggle("Highlight mistakes", isOn: $showMistakes)
                    Toggle("Highlight matching numbers", isOn: $highlightSame)
                    Toggle("Auto-remove notes", isOn: $autoNotes)
                    Picker("Mistake limit", selection: $mistakeLimit) {
                        Text("Off").tag(0)
                        Text("3").tag(3)
                        Text("5").tag(5)
                    }
                } header: {
                    Text("Gameplay")
                } footer: {
                    Text("With a mistake limit, the game ends when you reach it. You can retry the same puzzle.")
                }

                Section("Theme") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(Theme.all) { t in
                            themeSwatch(t)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

extension SettingsView {
    @ViewBuilder
    fileprivate func themeSwatch(_ t: Theme) -> some View {
        let selected = themeName == t.id
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(t.swatch)
                RoundedRectangle(cornerRadius: 6)
                    .fill(t.board == .clear ? Color.white.opacity(0.5) : t.board)
                    .padding(10)
                Text("5")
                    .font(.title2.weight(.regular))
                    .foregroundStyle(t.accent)
            }
            .frame(height: 64)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? t.accent : Color.secondary.opacity(0.3), lineWidth: selected ? 3 : 1)
            }
            Text(t.name)
                .font(.caption)
                .fontWeight(selected ? .semibold : .regular)
        }
        .contentShape(Rectangle())
        .onTapGesture { themeName = t.id }
    }
}

struct StatsView: View {
    let stats: Stats
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            List {
                Section("Overall") {
                    row("Games started", "\(stats.totalStarted)")
                    row("Games won", "\(stats.totalWon)")
                    row("Win rate", winRate)
                    row("Current streak", "\(stats.streak)")
                    row("Best streak", "\(stats.bestStreak)")
                }

                ForEach(Difficulty.allCases) { d in
                    let l = stats.level(d)
                    Section(d.rawValue) {
                        row("Played", "\(l.started)")
                        row("Won", "\(l.won)")
                        row("Best time", formatTime(l.bestTime))
                        row("Average time", formatTime(l.averageTime))
                    }
                }

                Section {
                    Button("Reset Statistics", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Best times only count games finished without hints.")
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { stats.reset() }
            }
        }
    }

    private var winRate: String {
        guard stats.totalStarted > 0 else { return "–" }
        return "\(Int((Double(stats.totalWon) / Double(stats.totalStarted) * 100).rounded()))%"
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }
}
