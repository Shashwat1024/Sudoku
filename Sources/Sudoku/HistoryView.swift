import SudokuCore
import SwiftUI

/// Past games: tap one to replay it or see its heatmap.
struct HistoryView: View {
    let store: HistoryStore
    let onRace: (GhostSetup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showImport = false
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            Group {
                if store.records.isEmpty {
                    ContentUnavailableView(
                        "No games yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished games appear here so you can replay them and see where you spent your time.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(store.records) { record in
                                NavigationLink {
                                    ReplayView(record: record) { setup in
                                        dismiss()
                                        onRace(setup)
                                    }
                                } label: {
                                    row(record)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Race a shared run…", systemImage: "flag.checkered") { showImport = true }
                        if !store.records.isEmpty {
                            Button("Clear history", systemImage: "trash", role: .destructive) {
                                confirmClear = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                ImportGhostView { setup in
                    dismiss()
                    onRace(setup)
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { store.clear() }
            }
        }
    }

    private func row(_ r: GameRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: r.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(r.completed ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(r.modeLabel).font(.headline)
                Text(r.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if r.mode != .zen {
                Text(formatTime(r.seconds)).font(.subheadline.monospacedDigit())
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .foregroundStyle(.primary)
        .glassSurface(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Paste a shared run code to race it.
struct ImportGhostView: View {
    let onRace: (GhostSetup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Paste a run code someone shared with you. You'll play the same puzzle and race their recorded run.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.footnote.monospaced())
                    .frame(height: 150)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        text = strings.first ?? ""
                        error = nil
                    }
                    Spacer()
                    Button("Clear") { text = ""; error = nil }
                        .disabled(text.isEmpty)
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }

                Button(action: race) {
                    Label("Race", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Race a Shared Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func race() {
        guard let payload = GhostCode.decode(text) else {
            error = "That doesn't look like a valid run code."
            return
        }
        guard let solution = SudokuEngine.solve(payload.puzzle) else {
            error = "This puzzle has no valid solution."
            return
        }
        // A ghost only makes sense on a puzzle with exactly one solution.
        var copy = payload.puzzle
        guard SudokuEngine.countSolutions(&copy, limit: 2) == 1 else {
            error = "This puzzle has more than one solution, so it can't be raced."
            return
        }
        let level = Solver.rate(payload.puzzle).level
        dismiss()
        onRace(GhostSetup(
            puzzle: payload.puzzle, solution: solution, difficulty: level,
            run: GhostRun(moves: payload.moves, seconds: payload.seconds, title: "the shared run")
        ))
    }
}
