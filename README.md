# Sudoku

An ad-free Sudoku app for iPhone, written in SwiftUI. Built and installed from
Windows/Linux with [xtool](https://github.com/xtool-org/xtool), no Mac or Xcode
required on the development machine.

## Features

- **Six difficulty levels** that are rated by the human techniques a puzzle needs,
  not just by clue count: Beginner, Easy, Medium, Hard, Expert, Master.
- **Teaching hints.** The hint explains the technique (naked single, hidden single,
  locked candidates, naked and hidden pairs, naked triples, X-Wing, XY-Wing),
  highlights the cells involved, and only then offers to reveal the answer.
- **Check.** Finds the earliest mistake still on the board and tells you whether it
  clashes with another cell.
- **Daily puzzle.** One deterministic puzzle per date, identical on every device,
  with a streak and a month calendar.
- **Zen mode.** No timer, no mistake pressure, nothing recorded; a time-of-day sky
  background and optional soft bell tones.
- **Replay and heatmap.** Every game records its moves. Replay a finished game with
  a scrubber and speed control, or see a heatmap of where you spent the most time.
- **Ghost races.** Race your earlier run on the same puzzle, or paste a run code
  shared by someone else (plain text, no server).
- Notes, undo, pause, mistake limit, statistics, seven colour themes.
- **Liquid Glass** controls and a soft colour glow (iOS 26+).
- Home screen to continue an unfinished game, start a new one from all six levels,
  open the daily puzzle, or browse history.

## Structure

```
Core/                  Pure Swift package: puzzle engine, solver, rating, daily
                       puzzle, mistake checker. No UI, tested on any platform.
Sources/Sudoku/        SwiftUI app (views, game state, stats, themes)
Resources/AppIcon.png  App icon
xtool.yml              xtool app configuration
```

The solver and generator live in `Core` so they can be tested natively and quickly:

```sh
cd Core
swift test
```

The tests include a soundness check: across many generated puzzles, every
deduction the solver makes must agree with the true solution.

## Building the app

Requirements: Swift 6.x, xtool set up for iOS development (see the xtool docs),
and an iPhone running iOS 26 or later.

1. Set your own bundle identifier in `xtool.yml`.
2. Connect your device and run:

```sh
xtool dev run -c release
```

Release mode matters: puzzle generation is much faster when optimized.

## License

MIT. See [LICENSE](LICENSE).

## Notes

- Apps signed with a free Apple ID expire after 7 days and need reinstalling.
- No accounts, no network access, no analytics. Everything is stored on the device.
