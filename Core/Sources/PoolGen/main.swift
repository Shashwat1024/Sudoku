import Foundation
import SudokuCore

// Builds the bundled practice pool for the technique trainer.
//
//   swift run -c release PoolGen <output.json> [quotaPerTechnique] [maxPuzzles]
//
// Generates many hard puzzles, walks the human solver, and keeps real positions in
// which each technique is the easiest one available. Output is deterministic.

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: PoolGen <output.json> [quotaPerTechnique=30] [maxPuzzles=20000]")
    exit(1)
}
let outPath = args[1]
let quota = args.count > 2 ? Int(args[2]) ?? 30 : 30
let maxPuzzles = args.count > 3 ? Int(args[3]) ?? 20000 : 20000

var pool: [Technique: [TrainerPosition]] = [:]
var seen = Set<String>()
let levels: [Difficulty] = [.hard, .expert, .master, .master]

@MainActor
func isFull() -> Bool {
    Technique.allCases.allSatisfy { (pool[$0]?.count ?? 0) >= quota }
}

var puzzles = 0
let start = Date()
while puzzles < maxPuzzles && !isFull() {
    var rng = SplitMix64(seed: "trainer-pool-v1-\(puzzles)")
    let level = levels[puzzles % levels.count]
    let (puzzle, _) = SudokuEngine.generate(level, using: &rng, maxAttempts: 4)
    puzzles += 1

    for p in Trainer.positions(from: puzzle) where (pool[p.technique]?.count ?? 0) < quota {
        guard Trainer.isConsistent(p) else { continue }
        let key = "\(p.technique.rawValue):" + p.values.map(String.init).joined()
        if seen.insert(key).inserted { pool[p.technique, default: []].append(p) }
    }
    if puzzles % 500 == 0 {
        let counts = Technique.allCases.map { "\($0.title)=\(pool[$0]?.count ?? 0)" }.joined(separator: ", ")
        print("[\(puzzles) puzzles, \(Int(Date().timeIntervalSince(start)))s] \(counts)")
    }
}

let all = Technique.allCases.flatMap { pool[$0] ?? [] }
let data = try JSONEncoder().encode(all)
try data.write(to: URL(fileURLWithPath: outPath))

print("\nDone: \(puzzles) puzzles, \(all.count) positions, \(data.count / 1024) KB -> \(outPath)")
for t in Technique.allCases {
    let n = pool[t]?.count ?? 0
    print("  \(t.title): \(n)\(n < quota ? "  (below quota)" : "")")
}
