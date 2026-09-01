import Foundation

// =============================================================================
// PROBLEM 1 — Crypto watchlist with live ticks
//
// Interview prompt (typical):
//   "Build a watchlist. Prices arrive often. The list should stay correct
//    without freezing the UI."
//
// What you say first:
//   "I'll keep ticks in a dictionary keyed by symbol so one update is O(1).
//    The ViewModel holds UI state. A stale tick (older timestamp) is ignored.
//    Unknown symbols are ignored — the user only watches what they added.
//    No UIKit: a print driver is enough for 60 minutes."
//
// Flutter mapping:
//   ViewModel  -> Cubit (state: loading / data / empty / error)
//   Tick stream -> Stream / Bloc listener
//   Dict by symbol -> don't rebuild the whole ListView on one price
// =============================================================================

// MARK: - Models

/// One tradable pair the user can pin.
/// Why they care: identity is the symbol, not a row index (indices break when the list sorts).
/// Say: "Symbol is the stable id. Display name is UI-only."
struct Asset: Hashable {
    let symbol: String   // "BTCINR"
    let name: String     // "Bitcoin"
}

/// One price sample from the feed.
/// Why they care: fintech + high-frequency UI is on the JD.
/// Say: "Decimal, not Double — Double cannot represent 0.1. Timestamp is the
///       server time so I can drop out-of-order packets."
struct Tick: Equatable {
    let symbol: String
    let price: Decimal
    let timestamp: Date
}

/// What the screen shows. One enum so the UI cannot be "loading and data".
/// Flutter: Cubit state class / freezed union.
enum WatchlistState: Equatable {
    case empty                          // user has no symbols — distinct from loading
    case loading
    case data([Asset], [String: Tick])  // assets in display order; ticks by symbol
    case error(String)
}

// MARK: - Ports (protocols)

/// Price source. Swap mock -> WebSocket later without touching the ViewModel.
/// Say: "Repository/feed is a protocol so the cubit stays testable."
/// Flutter: abstract class PriceFeed, injected into the cubit.
protocol PriceFeed {
    /// Next batch of ticks (mock). In production this would be a Stream.
    func pull() -> [Tick]
}

/// Who the user is watching. In-memory for the round.
protocol WatchlistStore {
    func all() -> [Asset]
    func add(_ asset: Asset)
}

// MARK: - In-memory impls

final class InMemoryWatchlistStore: WatchlistStore {
    private var assets: [Asset] = []

    func all() -> [Asset] { assets }

    func add(_ asset: Asset) {
        // Why: adding BTC twice must not duplicate rows.
        // Say: "I key uniqueness on symbol."
        if assets.contains(where: { $0.symbol == asset.symbol }) { return }
        assets.append(asset)
    }
}

/// Queue of ticks you seed in `main`. Stands in for a WebSocket.
final class MockPriceFeed: PriceFeed {
    private var queue: [Tick]

    init(_ ticks: [Tick]) { self.queue = ticks }

    func pull() -> [Tick] {
        let batch = queue
        queue = []
        return batch
    }
}

// MARK: - ViewModel (the thing you actually implement in the round)

/// Applies ticks, drops stale/unknown, exposes state.
/// Why they care: this is BLoC without the Flutter types.
/// Say: "UI only renders `state`. Business rules live here, not in the cell."
final class WatchlistViewModel {
    private let store: WatchlistStore
    private let feed: PriceFeed

    /// Latest tick per symbol. O(1) update. This is the whole performance story.
    /// Flutter: Map<String, Tick> in cubit state; list item widgets take one symbol.
    private var ticks: [String: Tick] = [:]

    private(set) var state: WatchlistState = .empty

    init(store: WatchlistStore, feed: PriceFeed) {
        self.store = store
        self.feed = feed
    }

    /// Call after adding symbols, before ticks. Empty list is a real state.
    func reload() {
        let assets = store.all()
        if assets.isEmpty {
            state = .empty
            return
        }
        state = .data(assets, ticks)
    }

    /// Pull the feed and apply. In production: subscribe once, not poll in the VM —
    /// say that if they ask WebSocket vs polling.
    func consumeFeed() {
        for tick in feed.pull() {
            apply(tick)
        }
        reload()
    }

    /// Core rule. Write this first if time is short.
    func apply(_ tick: Tick) {
        let watching = store.all().contains { $0.symbol == tick.symbol }
        if !watching {
            // Unknown symbol: ignore. Do not grow the map with junk.
            // Say: "Feed can send the whole market. Watchlist only stores what the user pinned."
            return
        }
        if let existing = ticks[tick.symbol], tick.timestamp <= existing.timestamp {
            // Stale / out-of-order: ignore.
            // Say: "WebSocket reconnects can replay. Newer timestamp wins. Equal = drop duplicate."
            return
        }
        ticks[tick.symbol] = tick
    }
}

// MARK: - Driver (what `main` looks like in the interview)

func runWatchlistScenarios() {
    let btc = Asset(symbol: "BTCINR", name: "Bitcoin")
    let eth = Asset(symbol: "ETHINR", name: "Ethereum")
    let t0 = Date(timeIntervalSince1970: 1_000)
    let t1 = Date(timeIntervalSince1970: 1_001)
    let t2 = Date(timeIntervalSince1970: 1_002)

    func tick(_ symbol: String, _ price: String, _ date: Date) -> Tick {
        Tick(symbol: symbol, price: Decimal(string: price)!, timestamp: date)
    }

    let store = InMemoryWatchlistStore()
    let feed = MockPriceFeed([
        tick("BTCINR", "5000000", t1),
        tick("ETHINR", "200000", t1),
        tick("BTCINR", "4990000", t0),   // stale — must be ignored
        tick("SOLINR", "15000", t1),     // not watching — must be ignored
        tick("BTCINR", "5100000", t2),   // newer — must win
    ])
    let vm = WatchlistViewModel(store: store, feed: feed)

    // 1. Empty
    vm.reload()
    expect(vm.state == .empty, "empty watchlist is .empty, not .data([])")

    // 2. Add symbols, no ticks yet — data with missing prices is OK
    store.add(btc)
    store.add(eth)
    store.add(btc) // duplicate
    vm.reload()
    if case let .data(assets, _) = vm.state {
        expect(assets.count == 2, "duplicate BTC was ignored")
    } else {
        expect(false, "expected .data after add")
    }

    // 3. Consume feed
    vm.consumeFeed()
    guard case let .data(_, latest) = vm.state else {
        expect(false, "expected .data after ticks")
        return
    }
    expect(latest["BTCINR"]?.price == Decimal(string: "5100000"), "newer BTC tick won")
    expect(latest["ETHINR"]?.price == Decimal(string: "200000"), "ETH applied")
    expect(latest["SOLINR"] == nil, "unknown SOL dropped")
    expect(latest.count == 2, "map only has watched symbols")

    print("WATCHLIST: all scenarios passed")
}

func expect(_ ok: Bool, _ message: String) {
    if ok {
        print("  OK  \(message)")
    } else {
        print("  FAIL  \(message)")
    }
}

runWatchlistScenarios()

// =============================================================================
// Stretch they will ask — answers, do not code unless extra time
//
// Q: WebSocket vs polling?
// A: WS for ticks. ViewModel subscribes once. Reconnect with last timestamp
//    so you can drop stale. Polling is a fallback, not the design.
//
// Q: UI still janky with 200 rows?
// A: ListView.builder (Flutter) / cell reuse. Row is its own widget keyed by
//    symbol. Cubit emits the map; only the row whose tick changed rebuilds.
//    Parse JSON off the UI isolate / background queue.
//
// Q: How do you test this?
// A: MockPriceFeed + InMemoryWatchlistStore. Assert apply() drops stale ticks.
//    No widget test needed for the rule.
// =============================================================================
