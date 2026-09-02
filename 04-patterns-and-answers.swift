import Foundation

// =============================================================================
// 04 — Patterns you actually use tomorrow + answers to say
//
// Skim after the three problems. Do not memorize extra libraries.
// No protocols here — same as 02 and 03. Concrete types + actors for races.
// =============================================================================

// MARK: 1. Strategy — 02 SpotFee, 03 HourlyRate
//
// What: a small fee object you pass in, not if product == .futures.
// Say: "New fee rule is a new type. PlaceOrderService does not change.
//       I do not need a protocol until I have two implementations."
// Flutter: inject the fee object into the cubit.

struct SpotFee {
    func fee(on paise: Int64) -> Int64 { paise * 10 / 10_000 } // 10 bps
}

struct ZeroFeePromo {
    func fee(on paise: Int64) -> Int64 { 0 }
}

func demoStrategy() {
    expect(SpotFee().fee(on: 1_000_000) == 1_000, "strategy: 10 bps of 1e6")
}

// MARK: 2. Observer / stream — 01 PriceFeed
//
// What: feed pushes ticks; ViewModel does not poll inside apply().
// Say: "In Flutter this is a Stream the BLoC listens to. In Swift, Combine or
//       a callback. For this round a pull() mock is enough."
// Flutter: Bloc listens to repository.watchTicks().

// MARK: 3. Repository — Wallet actor in 02, in-memory store in 01
//
// What: a type the use case calls. UI never knows about URLs.
// Say: "Today this is an actor / in-memory struct. Tomorrow the same methods
//       hit REST. I add a protocol only when the second impl exists."

struct Wallet {
    var paise: Int64 = 0
    func balance() -> Int64 { paise }
}

// MARK: 4. Factory — only if they ask "new order types"
//
// What: one function that returns the right fee object.
// Say: "Market vs limit is a factory. I will not nest switches in the UI."

enum OrderKind { case market, limit }

func fee(for kind: OrderKind, on paise: Int64) -> Int64 {
    switch kind {
    case .market: return SpotFee().fee(on: paise)
    case .limit: return ZeroFeePromo().fee(on: paise)
    }
}

func demoFactory() {
    expect(fee(for: .market, on: 1_000_000) == 1_000, "factory picks spot fee")
}

// MARK: 5. SOLID in one sentence each (they do ask)

// S: PlaceOrderService places orders. It does not format INR or draw cells.
// O: add FuturesFee without editing PlaceOrderService.
// L: FuturesFee has the same fee(on:) shape so tests can swap it.
// I: Quotes stay a separate type. Do not stuff them into Wallet.
// D: ViewModel holds a feed object you pass in — mock today, WebSocket later.

func expect(_ ok: Bool, _ message: String) {
    if ok { print("  OK  \(message)") }
    else { print("  FAIL  \(message)") }
}

demoStrategy()
demoFactory()
print("PATTERNS: snippets ran")

// =============================================================================
// FOLLOW-UPS — exact sentences
//
// Q: You don't know Flutter. Why should we hire you?
// A: You said you're willing to meet people who will learn. I already ship
//    this architecture on iOS: state in a ViewModel, UI as a function of
//    state, concrete types at the edges. BLoC is that pattern. First weeks I'd
//    pair, ship one screen, then a plugin if you need a native bridge.
//
// Q: BLoC vs Provider?
// A: Provider is dependency injection + listen. BLoC is event -> state for
//    anything with real rules (orders, wallet). I'd use BLoC for this
//    service and Provider to pass the wallet. I have not used them in
//    production — that's the mapping, not a claim.
//
// Q: High-frequency list (JD)?
// A: Point at 01. Map by symbol. Row widget keyed by symbol. Parse off UI
//    thread. Don't setState on the whole page for one tick.
//
// Q: Flutter plugins?
// A: Platform channel: Dart calls into Swift/Kotlin. I'd write the iOS side
//    comfortably. Dart FFI/plugin boilerplate I'd learn from your existing
//    plugins. Good-to-have on the JD, not the round.
//
// Q: How do you test?
// A: Point at the `main` drivers. In-memory fakes. Assert stale tick / duplicate
//    id / overlap. Widget tests later. TDD for the rule, not for the padding.
//
// Q: How would you extend 01 for 200 coins?
// A: Same map. Virtualized list. Maybe a binary protocol. Not a new architecture.
//
// Q: How would you extend 02 for futures?
// A: New fee struct + maybe a second Wallet actor. PlaceOrderService stays.
//    Don't copy-paste PlaceFuturesService.
//
// Q: Concurrent debit?
// A: Wallet is an actor. Isolation is the serial queue. Production: DB
//    transaction. Two requests must not both pass the balance read.
//
// Q: Why no protocols?
// A: One wallet, one fee, one rate. A protocol is for a second implementation.
//    An actor is for races on money.
//
// Q: DSA?
// A: If they insist: hash map is already the watchlist. Overlap is interval
//    scan. I won't start LeetCode unless they give a new prompt.
//
// Q: Why not Double?
// A: 0.1 + 0.2. Money is Int64 paise or Decimal. Display is formatting.
// =============================================================================
