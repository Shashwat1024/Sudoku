import SudokuCore
import SwiftUI

/// Time machine and thinking heatmap for one finished game.
struct ReplayView: View {
    let record: GameRecord
    let onRace: (GhostSetup) -> Void

    @Environment(\.theme) private var theme

    private enum Tab: String, CaseIterable { case replay = "Replay", heatmap = "Heatmap" }
    private struct PlayKey: Hashable { var playing: Bool; var speed: Double }

    @State private var tab: Tab = .replay
    @State private var step = 0
    @State private var playing = false
    @State private var speed = 1.0

    private var moves: [Move] { record.moves }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summary
                Picker("View", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if tab == .replay { replayBody } else { heatmapBody }
                actions
            }
            .padding()
        }
        .navigationTitle(record.modeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: PlayKey(playing: playing, speed: speed)) { await runPlayback() }
        .onChange(of: tab) { _, _ in playing = false }
    }

    // MARK: Summary

    private var summary: some View {
        HStack {
            Label(record.completed ? "Solved" : "Not finished",
                  systemImage: record.completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(record.completed ? Color.green : Color.red)
            Spacer()
            if record.mode != .zen { Text(formatTime(record.seconds)).monospacedDigit() }
            Text("·").foregroundStyle(.secondary)
            Text("\(record.mistakes) mistake\(record.mistakes == 1 ? "" : "s")")
            if record.hints > 0 {
                Text("·").foregroundStyle(.secondary)
                Text("\(record.hints) hint\(record.hints == 1 ? "" : "s")")
            }
        }
        .font(.subheadline)
    }

    // MARK: Replay

    private var replayBody: some View {
        let state = Replay.state(puzzle: record.puzzle, moves: moves, upTo: step)
        return VStack(spacing: 14) {
            MiniBoard(
                puzzle: record.puzzle, values: state.values, notes: state.notes,
                highlight: step > 0 ? moves[step - 1].cell : nil
            )

            Slider(
                value: Binding(get: { Double(step) }, set: { step = Int($0); playing = false }),
                in: 0...Double(max(moves.count, 1)), step: 1
            )
            .disabled(moves.isEmpty)

            HStack {
                Text(elapsed).monospacedDigit()
                Spacer()
                Text("Move \(step) of \(moves.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    roundButton("backward.end.fill") { playing = false; step = max(0, step - 1) }
                    roundButton(playing ? "pause.fill" : "play.fill", prominent: true) {
                        if step >= moves.count { step = 0 }
                        playing.toggle()
                    }
                    roundButton("forward.end.fill") { playing = false; step = min(moves.count, step + 1) }
                    Menu {
                        ForEach([1.0, 2.0, 4.0], id: \.self) { s in
                            Button("\(Int(s))×") { speed = s }
                        }
                    } label: {
                        Text("\(Int(speed))×")
                            .font(.headline)
                            .frame(width: 56, height: 48)
                            .glassSurface(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var elapsed: String {
        let t = step > 0 ? moves[step - 1].t : 0
        return "\(formatTime(t)) / \(formatTime(record.seconds))"
    }

    private func roundButton(_ icon: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: prominent ? 64 : 48, height: 48)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .glassSurface(Capsule(), tint: prominent ? theme.accent : nil)
        }
        .buttonStyle(.plain)
        .disabled(moves.isEmpty)
    }

    /// Plays the moves back, compressing long pauses so the replay keeps moving.
    private func runPlayback() async {
        guard playing else { return }
        while playing && step < moves.count {
            let previous = step > 0 ? moves[step - 1].t : 0
            let gap = Double(max(0, moves[step].t - previous))
            let delay = min(max(gap * 0.12, 0.15), 0.9) / speed
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            step += 1
        }
        if step >= moves.count { playing = false }
    }

    // MARK: Heatmap

    private var heatTimes: [Int] { Heatmap.cellTimes(moves: moves) }

    private var heatmapBody: some View {
        let times = heatTimes
        let maxT = max(1, times.enumerated().filter { record.puzzle[$0.offset] == 0 }.map(\.element).max() ?? 1)
        let heat = times.map { Double($0) / Double(maxT) }
        let slowest = times.enumerated()
            .filter { record.puzzle[$0.offset] == 0 && $0.element > 0 }
            .sorted { $0.element > $1.element }
            .prefix(3)

        return VStack(spacing: 14) {
            MiniBoard(puzzle: record.puzzle, values: record.completed ? record.solution : Replay.state(puzzle: record.puzzle, moves: moves).values, heat: heat)

            VStack(spacing: 4) {
                LinearGradient(
                    colors: [theme.accent.opacity(0.06), theme.accent.opacity(0.8)],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 10)
                .clipShape(Capsule())
                HStack {
                    Text("Quick")
                    Spacer()
                    Text("Slow (\(formatTime(maxT)))")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if slowest.isEmpty {
                Text("No timing data for this game.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where you spent the most time").font(.headline)
                    ForEach(Array(slowest), id: \.offset) { item in
                        HStack {
                            Text(SudokuCore.Grid.name(item.offset)).monospaced()
                            Spacer()
                            Text(formatTime(item.element)).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
            }
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        if record.completed {
            VStack(spacing: 10) {
                Button { onRace(record.ghostSetup) } label: {
                    Label("Race this run", systemImage: "flag.checkered").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                ShareLink(
                    item: record.shareCode,
                    subject: Text("Sudoku ghost"),
                    message: Text("Race my Sudoku run! Paste this code into Sudoku, History, Race a shared run.")
                ) {
                    Label("Share this run", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }
}
