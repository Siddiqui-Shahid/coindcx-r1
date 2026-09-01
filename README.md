# CoinDCX R1 — Machine Coding (LLD)

**When:** 2 Sep 2026, 10:30 AM IST · 60 min · video  
**Role:** Senior Software Engineer 1 – Mobile  
**Language tomorrow:** Swift. Do not write Dart unless they insist.

This folder is a 2–3 hour pack. Code is the study material. Comments tell you
what to say out loud. Run any problem with:

```bash
swift 01-watchlist.swift
swift 02-wallet-order.swift
swift 03-vehicle-rental.swift
swift 04-patterns-and-answers.swift
```

Re-implement **one** of `01` or `02` from a blank file at the end. That is the
part that wins the round.

---

## 2–3 hour schedule

| Clock | What |
|---|---|
| 0:00–0:20 | This README. Say the opening script out loud once. |
| 0:20–1:10 | Read `01-watchlist.swift` top to bottom. Run it. |
| 1:10–2:00 | Read `02-wallet-order.swift`. Run it. Note every `throw`. |
| 2:00–2:30 | Read `03-vehicle-rental.swift` (types + `main` if short on time). |
| 2:30–3:00 | Hide the file. Re-implement watchlist **or** wallet in 25 min. Skim `04`. |

If you only have 90 minutes: README + `01` + `02`. Skip `03` until the commute.

---

## What they score (say these words)

1. **Clarify before code** — actors, must-haves, non-goals, language.
2. **Types and APIs** — entities, protocols, who owns what.
3. **Working happy path** — something that prints / runs.
4. **Edge cases** — stale data, empty, insufficient funds, overlap, duplicate id.
5. **Extensibility** — new coin, new fee, new vehicle type without rewriting.
6. **Talk while typing** — silence loses interviews.

A pretty UI is not required. A correct core + “what I would add next” is.

---

## Opening script (say this, then wait)

> I’m strongest in Swift/iOS. I haven’t shipped Flutter. I’ll implement this
> in Swift with the same layers you’d use in Flutter: UI state, use case,
> repository. I’ll map it to BLoC/Provider as we go. Does that work?

If they say Dart-only: models + `main()`, no widgets. Switching languages at
minute 20 is how the round dies.

### First 10 minutes — do not code

Write this on the shared screen:

- Actors and use cases
- Entities
- Public methods
- Non-goals (“in-memory, one user, mock prices”)
- Assumptions

Ask: UI required or classes + `main`? Persistence? Live updates? Multi-user?

Then implement in this order:

1. Models
2. Protocols
3. In-memory impl
4. Use case / ViewModel
5. `main` with 4–6 scenarios
6. Edges

---

## Flutter mapping (verbal only)

| You write in Swift | You say |
|---|---|
| `WatchlistViewModel` / `PlaceOrderService` | Cubit or simple BLoC: events in, state out |
| `AsyncStream` / callback of ticks | Dart `Stream` — Provider/BLoC listens |
| Protocol + in-memory repo | Same in Dart; widgets stay dumb |
| `Dictionary<Symbol, Tick>` | One price change must not rebuild the whole list |
| Integer minor units for money | Never `double` for INR or crypto |
| `FeeCharging` protocol | Strategy — add futures later without rewriting spot |
| Platform channel (if asked) | Flutter plugin — I have not written one; I have done native bridges |

Sentence that lands:

> BLoC is the same pattern I use with a ViewModel and a stream of UI state.
> For a ticker I’d store ticks by symbol so one update does not rebuild the book.

Do not claim BLoC/Provider production experience.

---

## Which file if they give X

| They say | Open in your head |
|---|---|
| Watchlist, ticker, live prices, order book UI | `01-watchlist.swift` |
| Wallet, cart, place order, fees, balance | `02-wallet-order.swift` |
| Parking lot, rental, booking, splitwise-style | `03-vehicle-rental.swift` |
| “How would you extend this?” / BLoC / testing | `04-patterns-and-answers.swift` |

---

## If they pivot to DSA

This invite is machine coding + LLD. If they still give a coding puzzle:
arrays, hash maps, two pointers. Talk complexity. Do not spend tonight on
LeetCode.

---

## Logistics

- Empty Swift file or Playground ready, not a 40-module app
- Camera, quiet room, photo if their tool asks
- Recruiter: saurav.ajmani@coindcx.com if you are not in by 10:35
