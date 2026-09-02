# Patterns and answers — explained in plain English

Companion to `04-patterns-and-answers.swift`. Skim this the night before. Do not memorize libraries. These patterns **already appeared** in files 01–03. This file only **names** them so you can say the word when they ask.

---

## How to use this

In the round they will point at your code and ask “which pattern is this?”  
You answer with one of the four names below, then one sentence.

You are iOS. If they ask Flutter, map — do not pretend production BLoC.

---

## 1. Strategy — “the rule is a plug”

**You already used it:** wallet fees (`SpotFee`), rental hourly rate (`HourlyRate`).

**Human version:**  
The buy service should not contain a giant `if`. “How much fee?” is a small object you pass in. Tomorrow, zero-fee promo is another object with the same shape. The buy function does not change.

**Say:** “New fee rule is a new type. `PlaceOrderService` stays.”

**Flutter:** inject that object into the cubit. Same idea.

---

## 2. Observer / stream — “prices come to you”

**You already used it:** `PriceFeed` in the watchlist.

**Human version:**  
The screen does not sit in a loop asking “any new price?”. Something **pushes** ticks. The ViewModel reacts.

In the drill, `pull()` is a fake. In production it is a WebSocket / Combine / Dart `Stream`.

**Say:** “BLoC listens to `repository.watchTicks()`. For this round a mock pull is enough.”

---

## 3. Repository — “the app does not know about URLs”

**You already used it:** wallet, watchlist store, quote book.

**Human version:**  
The brain asks `balance()` and `debit()`. It does not know if that is RAM, SQLite, or HTTP. Tests use the fake. Shipping uses the real one.

**Say:** “Today this is an actor or an in-memory struct. Tomorrow the same methods hit REST. I add a protocol only when the second impl exists.”

---

## 4. Factory — only if they ask “market vs limit”

**Human version:**  
One function: “you said market → here is the spot fee object. You said limit → here is the promo fee object.” The UI does not `switch` on order type in five screens.

**Say:** “Market vs limit is a factory. I will not nest switches in the UI.”

---

## SOLID — one sentence each (they do ask)

| Letter | In English, using your files |
|---|---|
| **S**ingle responsibility | `PlaceOrderService` places orders. It does not format rupees or draw cells. |
| **O**pen/closed | Add `FuturesFee` without editing `PlaceOrderService`. |
| **L**iskov | A futures fee with the same `fee(on:)` shape can replace `SpotFee` in a test. |
| **I**nterface segregation | Quotes stay their own type. Do not stuff them into `Wallet`. |
| **D**ependency inversion | ViewModel holds a feed you pass in — mock today, WebSocket later. |

If you remember only two: **S** and **D**. Those show up the most.

---

## Follow-ups — say these, do not ramble

**You don’t know Flutter. Why hire you?**  
You wrote on the JD that you will meet people who will learn. I already ship this architecture on iOS: state in a ViewModel, UI is a function of state, concrete types at the edges. BLoC is that pattern. First weeks I would pair, ship one screen, then a plugin if you need a native bridge.

**BLoC vs Provider?**  
Provider is “hand me this object and tell me when it changes.” BLoC is “event in, new state out” for real rules (orders, wallet). I would use BLoC for the service and Provider to pass the repository. I have not used them in production — that is a mapping, not a claim.

**High-frequency list (it is on the JD)?**  
Point at watchlist. Dictionary by symbol. Each row is its own widget. Parse off the UI thread. Do not rebuild the whole page for one tick.

**Flutter plugins?**  
Dart calls into Swift/Kotlin over a platform channel. I would be comfortable on the iOS side. Plugin boilerplate I would copy from your existing plugins. Good-to-have, not this round.

**How do you test?**  
The `main` prints *are* the tests. Fake wallet, fake feed. Assert stale tick / duplicate id / overlap. Widget tests later. Test the rule, not the padding.

**200 coins on the watchlist?**  
Same dictionary. Virtualized list. Maybe a tighter network format. Not a new architecture.

**Add futures trading?**  
New fee type + maybe a margin wallet. Do not copy-paste `PlaceFuturesService`.

**Two debits at once?**  
Wallet is an actor. Isolation is the serial queue. Production: DB transaction. Both requests must not pass the balance check.

**Why no protocols?**  
One wallet, one fee, one rate. A protocol is for a second implementation. An actor is for races on money.

**DSA?**  
Hash map is already the watchlist. Overlap is an interval check. I will not start LeetCode unless you give a new prompt.

**Why not Double?**  
`0.1 + 0.2`. Money is paise (`Int64`) or `Decimal`. Display is formatting.

---

## Cheatsheet: pattern → file

| They say | You point at |
|---|---|
| Strategy | Fees in `02`, hourly rate in `03` |
| Observer / stream | Price feed in `01` |
| Repository | Wallet, store, quotes — all three |
| Factory | Market vs limit (this file) |
| SOLID | The table above |
| Flutter / BLoC | “ViewModel in `01` is a Cubit” |
