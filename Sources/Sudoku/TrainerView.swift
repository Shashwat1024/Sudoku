import SudokuCore
import SwiftUI

// MARK: - Shared helpers

/// Board showing a trainer position with its pencil marks and pattern highlighted.
private struct PositionBoard: View {
    let position: TrainerPosition
    /// Show the candidates the deduction removes (red) and the full highlight.
    let revealed: Bool

    var body: some View {
        let step = position.step
        let eliminated = Dictionary(grouping: step.eliminations, by: \.cell)
            .mapValues { Set($0.map(\.digit)) }
        MiniBoard(
            puzzle: position.values, values: position.values, notes: position.notes,
            patternCells: Set(step.cells), target: step.placement?.cell,
            eliminated: revealed ? eliminated : [:], noteScale: 0.3
        )
    }
}

private struct Stars: View {
    let score: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<TrainerStore.questionCount, id: \.self) { i in
                Image(systemName: i < score ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(i < score ? Color.yellow : Color.secondary.opacity(0.5))
            }
        }
    }
}

// MARK: - Technique list

struct TrainerView: View {
    let store: TrainerStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Text("Learn the techniques behind the hints. Read a short lesson with a real example, then take a five-question quiz.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    ForEach(Array(Technique.allCases.enumerated()), id: \.element) { index, t in
                        NavigationLink {
                            LessonView(technique: t, store: store)
                        } label: {
                            row(index + 1, t)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Learn Techniques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ number: Int, _ t: Technique) -> some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(t.title).font(.headline)
                Text(t.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Stars(score: store.bestScore(t))
            }
            Spacer()
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

// MARK: - Lesson

struct LessonView: View {
    let technique: Technique
    let store: TrainerStore

    private var example: TrainerPosition? { TrainerPool.shared.positions(technique).first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(technique.summary)
                    .font(.title3.weight(.semibold))

                ForEach(Array(technique.lesson.enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph).font(.body)
                }

                if let ex = example {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Example").font(.headline)
                        PositionBoard(position: ex, revealed: true)
                        Text(ex.step.explanation)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            legend(Color.orange.opacity(0.5), "The pattern")
                            legend(Color.red, "Removed candidate")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: false)

                    NavigationLink {
                        QuizView(technique: technique, store: store)
                    } label: {
                        Label("Practice quiz", systemImage: "questionmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                } else {
                    Text("Practice positions aren't available in this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(technique.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
            Text(text)
        }
    }
}

// MARK: - Quiz

struct QuizView: View {
    let technique: Technique
    let store: TrainerStore

    private struct Question: Identifiable {
        let id = UUID()
        let position: TrainerPosition
        let options: [Technique]
    }

    @State private var questions: [Question] = []
    @State private var index = 0
    @State private var answer: Technique?
    @State private var score = 0
    @State private var finished = false

    var body: some View {
        Group {
            if questions.isEmpty {
                ContentUnavailableView(
                    "No practice positions",
                    systemImage: "square.grid.3x3",
                    description: Text("This build doesn't include practice positions for \(technique.title).")
                )
            } else if finished {
                results
            } else {
                question(questions[index])
            }
        }
        .navigationTitle("\(technique.title) Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if questions.isEmpty { restart() } }
    }

    // MARK: Question

    private func question(_ q: Question) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Text("Question \(index + 1) of \(questions.count)").font(.subheadline.weight(.medium))
                    Spacer()
                    Text("Score \(score)").font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(index), total: Double(questions.count))

                PositionBoard(position: q.position, revealed: answer != nil)

                Text("Which technique does the highlighted pattern show?")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GlassEffectContainer(spacing: 8) {
                    VStack(spacing: 8) {
                        ForEach(q.options, id: \.self) { option in
                            optionButton(option, correct: q.position.technique)
                        }
                    }
                }

                if answer != nil { feedback(q) }
            }
            .padding()
        }
    }

    private func optionButton(_ option: Technique, correct: Technique) -> some View {
        let chosen = answer == option
        let reveal = answer != nil
        let tint: Color? = {
            guard reveal else { return nil }
            if option == correct { return .green }
            return chosen ? .red : nil
        }()
        return Button { choose(option) } label: {
            HStack {
                Text(option.title).font(.body.weight(.medium))
                Spacer()
                if reveal, option == correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if reveal, chosen {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
            .glassSurface(RoundedRectangle(cornerRadius: 16, style: .continuous), tint: tint)
        }
        .buttonStyle(.plain)
        .disabled(reveal)
    }

    private func feedback(_ q: Question) -> some View {
        let right = answer == q.position.technique
        return VStack(alignment: .leading, spacing: 10) {
            Label(right ? "Correct" : "Not quite: it's \(q.position.technique.title)",
                  systemImage: right ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.headline)
                .foregroundStyle(right ? Color.green : Color.orange)
            Text(q.position.step.explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: next) {
                Text(index + 1 < questions.count ? "Next" : "See results").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: false)
    }

    // MARK: Results

    private var results: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: score == questions.count ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(score == questions.count ? Color.yellow : Color.accentColor)
            Text("\(score) of \(questions.count)").font(.largeTitle.bold())
            Stars(score: score)
            Text(resultMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button { restart() } label: {
                Label("Try again", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding()
    }

    private var resultMessage: String {
        if score == questions.count { return "Perfect. You've mastered \(technique.title)." }
        if score >= questions.count - 1 { return "Nearly there. One more run for a perfect score." }
        return "Re-read the lesson, then try again with fresh positions."
    }

    // MARK: Logic

    private func choose(_ option: Technique) {
        guard answer == nil, !questions.isEmpty else { return }
        answer = option
        if option == questions[index].position.technique { score += 1 }
    }

    private func next() {
        if index + 1 < questions.count {
            index += 1
            answer = nil
        } else {
            store.record(technique, score: score)
            finished = true
        }
    }

    private func restart() {
        let picked = TrainerPool.shared.positions(technique)
            .shuffled()
            .prefix(TrainerStore.questionCount)
        questions = picked.map { p in
            let distractors = Technique.allCases.filter { $0 != technique }.shuffled().prefix(3)
            return Question(position: p, options: (Array(distractors) + [technique]).shuffled())
        }
        index = 0
        answer = nil
        score = 0
        finished = false
    }
}
