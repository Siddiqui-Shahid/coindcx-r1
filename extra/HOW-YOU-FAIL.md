# How people fail this round

Read once. These are not extra features — they are the usual reject reasons.

## Process (first 10 minutes)

- Coding before clarifying language, UI-or-not, in-memory, multi-user.
- Silence for 15 minutes. Narrate every type you add.
- Building SwiftUI / Flutter widgets. They asked LLD. `main` + prints wins.
- Switching to Dart at minute 20 because you felt guilty. Stay on Swift unless they require Dart.
- Claiming BLoC production experience. Map it. Do not lie.

## Design

- One god class. Split model / protocol / service.
- `if vehicleType == .suv` inside `book()`. That is a Strategy they will ask you to extend.
- `Double` for INR or BTC. Instant fail in fintech. Int64 paise or Decimal.
- Mutable shared balance with no lock/serial story when they ask “two taps”.
- List of ticks that you scan every update (O(n)) for a watchlist. Dictionary by symbol.

## Edges they will add at minute 45

Have a sentence ready. You do not need to recode everything.

| Stretch | Answer |
|---|---|
| Duplicate request | Idempotency key / clientOrderId (file 02) |
| Out-of-order WebSocket | Timestamp, drop stale (file 01) |
| Overlapping booking | Half-open interval (file 03 / parking-lot) |
| Burst of API calls | Rate limiter in this folder |
| Memory of 10k coins | LRU in this folder, plus virtualized list |
| New product (futures, SUV, surge fee) | New strategy type, service unchanged |
| Empty / loading / error | Enum state, not booleans |
| Tests | The `main` driver *is* the test. Say that. |

## Mobile / Flutter they may still ask (verbal)

You are iOS. These are 20-second answers, not a coding task.

- **BLoC vs Provider:** Provider injects and notifies. BLoC is event → state for rules (orders). You have not shipped Flutter; this is the mapping.
- **High-frequency UI:** one row widget per symbol; do not rebuild the page on one tick.
- **Plugins:** Dart calls Swift/Kotlin over a platform channel. You would own the iOS side.
- **Isolates / background:** parse JSON off the UI thread. Same as a background queue.
- **Rebuilds:** `const` / keys / small widgets. CoinDCX has published on this — they care.

## DSA sneak

If they drop a coding puzzle instead of LLD: arrays, hash map, two pointers.
State complexity. Do not freeze. The invite is still machine coding — bring it back to types if you can.

## Time-box if you stall

Minute 40: working happy path beats a perfect class diagram.
Minute 50: run it. Fix the crash. Then edges.
Minute 55: “next I would persist, add tests, swap the mock feed.” Stop adding features.
