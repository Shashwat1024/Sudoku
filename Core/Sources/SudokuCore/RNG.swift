import Foundation

/// Small deterministic RNG (SplitMix64). The same seed always yields the same
/// sequence on every device, which the daily puzzle and shared puzzles rely on.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    /// Stable seed from a string (FNV-1a), e.g. a date like "2026-11-12".
    public init(seed string: String) {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            h ^= UInt64(byte)
            h = h &* 0x100000001b3
        }
        state = h
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

extension Array {
    /// Fisher-Yates shuffle with a fixed algorithm, so results don't change
    /// between Swift versions (the standard library's shuffle may).
    public func stableShuffled<G: RandomNumberGenerator>(using rng: inout G) -> [Element] {
        var a = self
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            a.swapAt(i, j)
        }
        return a
    }
}
