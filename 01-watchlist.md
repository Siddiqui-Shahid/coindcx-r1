# Watchlist — explained in plain English

Companion to `01-watchlist.swift`. Read this first, then glance at the code.

---

## What they are asking

Imagine the CoinDCX home screen: Bitcoin, Ethereum, a few coins you pinned. Prices jump every second.

Your job is **not** to draw a pretty list. Your job is:

1. Remember which coins the user pinned.
2. When a new price arrives, update **only that coin**.
3. Ignore junk: old prices, coins the user is not watching, empty list.

If you do that, the UI will not freeze when 200 prices arrive.

---

## The one sentence you say first

> I store the latest price in a dictionary keyed by symbol, so one update is instant. The screen only reads state. Stale and unknown ticks are dropped.

That sentence is the whole design.

---

## The pieces (like a kitchen)

| Thing in code | Everyday meaning |
|---|---|
| `Asset` | A coin on the list. `BTCINR` is the id. “Bitcoin” is just the label. |
| `Tick` | One price snapshot: which coin, how much, **when** the server said so. |
| `WatchlistState` | What the screen is allowed to show: empty, loading, data, or error. Never two at once. |
| `WatchlistStore` | The pin list. “What did the user add?” |
| `PriceFeed` | The pipe prices come from. Today a fake queue. Tomorrow a WebSocket. |
| `WatchlistViewModel` | The brain. UI does not think. It only paints whatever `state` is. |

**Why a dictionary (`ticks["BTCINR"]`) instead of an array?**

An array means: walk the whole list to find Bitcoin. A dictionary means: jump straight to Bitcoin. On a live ticker, that is the difference between smooth and janky.

---

## How a price actually gets applied

When `apply(tick)` runs, it asks three questions, in order:

1. **Is this coin on my watchlist?** No → throw it away. The exchange may send the whole market. You only care what the user pinned.
2. **Is this older than the price I already have?** Yes → throw it away. Networks replay packets. Newer timestamp wins. Same timestamp = duplicate, also drop.
3. Otherwise **overwrite** that symbol in the dictionary.

Then `reload()` rebuilds `state` for the screen: the list of assets (order for the rows) plus the dictionary (prices).

Empty is special: no pins → `.empty`, not “data with zero rows”. Interviewers like that. It is a different screen (illustration vs list).

---

## Walk through the test like a story

You pin BTC and ETH. You try to pin BTC again — still two rows.

Then five prices arrive:

| Incoming | What should happen |
|---|---|
| BTC at time 1, price 50 lakh | Keep it |
| ETH at time 1, price 2 lakh | Keep it |
| BTC at time 0, cheaper | **Ignore** — older than what you have |
| SOL | **Ignore** — you never pinned Solana |
| BTC at time 2, 51 lakh | **Replace** — this is newer |

End state: BTC = 51 lakh, ETH = 2 lakh, no SOL. Two keys in the map.

---

## What you type in 60 minutes (order)

1. `Asset`, `Tick`, `WatchlistState`
2. The two protocols (`PriceFeed`, `WatchlistStore`)
3. Fake store + fake feed (arrays are fine)
4. ViewModel with `apply` — write this even if you skip UI
5. A `main` that prints the five cases above

Skip SwiftUI. Prints are enough.

---

## If they say Flutter

Same brain, different names:

- ViewModel → **Cubit / BLoC** (events in, state out)
- Price feed → a **Stream** the cubit listens to
- One row per symbol so one tick does not rebuild the whole `ListView`

Say you have not shipped Flutter. Say the pattern is the same as your iOS ViewModel.

---

## Extra questions (do not code these unless time left)

**WebSocket or polling?**  
WebSocket for live prices. Subscribe once. On reconnect, send the last timestamp so you can drop old ticks. Polling is a backup.

**List still stutters with 200 rows?**  
Reuse cells (`ListView.builder`). Each row is its own widget, keyed by symbol. Parse JSON on a background queue, not on the UI thread.

**How do you test?**  
Fake feed + fake store. Assert that a stale tick does not change the price. No widget test needed for that rule.
