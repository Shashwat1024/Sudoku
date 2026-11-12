import SudokuCore
import SwiftUI

/// Today's puzzle, the streak, and a month calendar of completed days.
struct DailyView: View {
    let game: Game
    let play: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var month: Date = {
        let c = Calendar.current
        return c.date(from: c.dateComponents([.year, .month], from: Date())) ?? Date()
    }()

    private var cal: Calendar { .current }
    private var todayKey: String { DailyPuzzle.todayKey() }
    private var daily: DailyStore { game.daily }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    todayCard
                    streakRow
                    calendar
                }
                .padding()
            }
            .navigationTitle("Daily Puzzle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Today

    private var todayCard: some View {
        let level = DailyPuzzle.difficulty(forKey: todayKey)
        let result = daily.results[todayKey]
        return VStack(alignment: .leading, spacing: 10) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(level.rawValue).font(.title.bold())
                Spacer()
                if let r = result {
                    Label(formatTime(r.seconds), systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }
            Text(statusText(result))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: play) {
                Text(buttonTitle(result)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: false)
    }

    private func statusText(_ result: DailyResult?) -> String {
        if let r = result {
            let h = r.hints == 0 ? "no hints" : "\(r.hints) hint\(r.hints == 1 ? "" : "s")"
            return "Completed today with \(r.mistakes) mistake\(r.mistakes == 1 ? "" : "s") and \(h)."
        }
        if game.isTodaysDailyActive { return "You're partway through today's puzzle." }
        return "Everyone gets the same puzzle today. A new one arrives at midnight."
    }

    private func buttonTitle(_ result: DailyResult?) -> String {
        if game.isTodaysDailyActive { return "Continue" }
        return result != nil ? "Play again" : "Play today's puzzle"
    }

    // MARK: Streak

    private var streakRow: some View {
        HStack(spacing: 12) {
            stat("flame.fill", "\(daily.currentStreak())", "Current streak", .orange)
            stat("trophy.fill", "\(daily.bestStreak)", "Best streak", .yellow)
            stat("checkmark.seal.fill", "\(daily.results.count)", "Completed", theme.accent)
        }
    }

    private func stat(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.title2.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassSurface(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: false)
    }

    // MARK: Calendar

    private var calendar: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(isCurrentMonth)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) } else { Color.clear.frame(height: 36) }
                }
            }
        }
        .padding()
        .glassSurface(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: false)
    }

    private func dayCell(_ date: Date) -> some View {
        let key = DailyPuzzle.dateKey(for: date)
        let done = daily.isCompleted(key)
        let isToday = key == todayKey
        let isFuture = date > Date() && !isToday
        return ZStack {
            Circle()
                .fill(done ? theme.accent : Color.clear)
            if isToday {
                Circle().strokeBorder(theme.accent, lineWidth: 2)
            }
            if done {
                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
            } else {
                Text("\(cal.component(.day, from: date))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isFuture ? Color.secondary.opacity(0.4) : Color.primary)
            }
        }
        .frame(height: 36)
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { symbols[($0 + cal.firstWeekday - 1) % 7] }
    }

    private var monthDays: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month)
        let lead = (firstWeekday - cal.firstWeekday + 7) % 7
        var out: [Date?] = Array(repeating: nil, count: lead)
        for d in range {
            out.append(cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return out
    }

    private var isCurrentMonth: Bool {
        cal.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: month) { month = m }
    }
}
