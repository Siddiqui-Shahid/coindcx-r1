import Foundation

// =============================================================================
// 04 — Patterns you actually use tomorrow + answers to say
//
// Skim after the three problems. Do not memorize extra libraries.
// Each pattern below already appeared in 01–03. This file only names them.
// =============================================================================

// MARK: 1. Strategy — 02 SpotFee, 03 HourlyRate
//
// What: a protocol + structs instead of if product == .futures.
// Say: "New fee rule is a new type. PlaceOrderService does not change."
// Flutter: same — inject the strategy into the cubit.

protocol FeeCharging {
    func fee(on paise: Int64) -> Int64
}

struct SpotFee: FeeCharging {
    func fee(on paise: Int64) -> Int64 { paise * 10 / 10_000 } // 10 bps
}

struct ZeroFeePromo: FeeCharging {
    func fee(on paise: Int64) -> Int64 { 0 }
}

func demoStrategy() {
    let fees: FeeCharging = SpotFee()
    expect(fees.fee(on: 1_000_000) == 1_000, "strategy: 10 bps of 1e6")
}

// MARK: 2. Observer / stream — 01 PriceFeed
//
// What: feed pushes ticks; ViewModel does not poll inside apply().
// Say: "In Flutter this is a Stream the BLoC listens to. In Swift, Combine or
//       a callback. For this round a pull() mock is enough."
// Flutter: Bloc listens to repository.watchTicks().

// MARK: 3. Repository — all three files
//
// What: protocol + in-memory impl. UI/use case never knows about URLs.
// Say: "Tomorrow this is REST. Tests keep the fake. That's why it's a protocol."

protocol WalletRepository {
    func balance() -> Int64
}

final class InMemoryWallet: WalletRepository {
    var paise: Int64 = 0
    func balance() -> Int64 { paise }
}

// MARK: 4. Factory — only if they ask "new order types"
//
// What: one function that returns the right strategy/object.
// Say: "Market vs limit is a factory. I will not nest switches in the UI."

enum OrderKind { case market, limit }

func feeCharging(for kind: OrderKind) -> FeeCharging {
    switch kind {
    case .market: return SpotFee()
    case .limit: return ZeroFeePromo() // example only
    }
}

func demoFactory() {
    expect(feeCharging(for: .market).fee(on: 1_000_000) == 1_000, "factory picks spot fee")
}

// MARK: 5. SOLID in one sentence each (they do ask)

// S: PlaceOrderService places orders. It does not format INR or draw cells.
// O: add FuturesFee without editing PlaceOrderService.
// L: any FeeCharging can replace SpotFee in tests.
// I: QuoteBook is not stuffed into WalletRepository.
// D: ViewModel depends on PriceFeed protocol, not MockPriceFeed.

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
//    state, protocols at the edges. BLoC is that pattern. First weeks I'd
//    pair, ship one screen, then a plugin if you need a native bridge.
//
// Q: BLoC vs Provider?
// A: Provider is dependency injection + listen. BLoC is event -> state for
//    anything with real rules (orders, wallet). I'd use BLoC for this
//    service and Provider to pass the repository. I have not used them in
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
// A: New FeeCharging + maybe a margin WalletRepository. PlaceOrderService
//    stays. Don't copy-paste PlaceFuturesService.
//
// Q: Concurrent debit?
// A: NSLock in the demo. Production: serial queue or DB transaction with
//    a check-and-debit. Two requests must not both pass the balance read.
//
// Q: DSA?
// A: If they insist: hash map is already the watchlist. Overlap is interval
//    scan. I won't start LeetCode unless they give a new prompt.
//
// Q: Why not Double?
// A: 0.1 + 0.2. Money is Int64 paise or Decimal. Display is formatting.
// =============================================================================
