import Foundation

// =============================================================================
// EXTRA — Rate limiter
// Prompt: "Allow 3 requests per user per 10 seconds. Drop the rest."
// Why CoinDCX: trading APIs, login OTP, websocket subscribe.
//
// Say first:
//   "Sliding window per userId. I store timestamps. allow() is O(n) in the
//    window size (tiny). Token bucket is the stretch if they want bursts."
// Flutter: this lives in the repository / interceptor, not in the widget.
// =============================================================================

protocol RateLimiting {
    func allow(userId: String, at: Date) -> Bool
}

/// Keep timestamps in the last `window`. Count must stay <= `max`.
final class SlidingWindowLimiter: RateLimiting {
    private let max: Int
    private let window: TimeInterval
    private var hits: [String: [Date]] = [:]

    init(max: Int, window: TimeInterval) {
        self.max = max
        self.window = window
    }

    func allow(userId: String, at: Date) -> Bool {
        let cutoff = at.addingTimeInterval(-window)
        var recent = (hits[userId] ?? []).filter { $0 > cutoff }
        if recent.count >= max {
            hits[userId] = recent
            return false
        }
        recent.append(at)
        hits[userId] = recent
        return true
    }
}

func expect(_ ok: Bool, _ m: String) { print(ok ? "  OK  \(m)" : "  FAIL  \(m)") }

func run() {
    let lim = SlidingWindowLimiter(max: 3, window: 10)
    let t = Date(timeIntervalSince1970: 100)
    expect(lim.allow(userId: "u1", at: t), "1st ok")
    expect(lim.allow(userId: "u1", at: t.addingTimeInterval(1)), "2nd ok")
    expect(lim.allow(userId: "u1", at: t.addingTimeInterval(2)), "3rd ok")
    expect(!lim.allow(userId: "u1", at: t.addingTimeInterval(3)), "4th blocked")
    expect(lim.allow(userId: "u2", at: t.addingTimeInterval(3)), "other user independent")
    expect(lim.allow(userId: "u1", at: t.addingTimeInterval(13)), "window expired, allowed")
    print("RATE LIMIT: passed")
}

run()

// Stretch they ask:
//   Token bucket: refill N tokens/sec, burst up to bucket size.
//   Distributed: Redis INCR + TTL, not this in-memory map.
//   Per-route limits: key = userId + path.
