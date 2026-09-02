# Wallet + place order — explained in plain English

Companion to `02-wallet-order.swift`. Read this first, then glance at the code.

---

## What they are asking

User has rupees in a CoinDCX wallet. They tap **Buy 1 BTC**. You must:

1. Charge the right amount (price × quantity + fee).
2. Refuse if they cannot pay — balance must never go negative.
3. If they double-tap, **do not charge twice**.
4. If the price on screen is 30 seconds old, refuse. Do not buy at a dead quote.

This is a money problem. One sloppy `Double` and they will not trust you with a trading app.

---

## The one sentence you say first

> Money is stored as paise (integers), never Double. Wallet and PlaceOrderService are actors, so two Buy taps cannot race. Debit fails closed. The same client order id cannot debit twice.

---

## Why not `Double`

`0.1 + 0.2` is not `0.3` in floating point. For INR and crypto that is a bug, not a rounding debate.

**Rule:** store **paise** (1 rupee = 100 paise) as a whole number.

Examples from the file:

- BTC price = ₹50,00,000 → `500_000_000` paise per coin
- Wallet starts at ₹1,20,00,000 → `1_200_000_000` paise
- Fee is 0.10% (10 bps) → integer math: `amount * 10 / 10_000`

The screen can still show `₹50,00,000.00`. That is formatting. The model stays integers.

---

## The pieces

| Thing in code | Everyday meaning |
|---|---|
| `Money` | A pile of paise + currency (`INR`). You cannot add INR to USD. |
| `MarketQuote` | “BTC is this many paise, as of this time.” |
| `Order` | The receipt: id, qty, price chunk, fee, total taken from wallet. |
| `Wallet` (actor) | Get balance, add money, take money. One caller at a time — no lock. |
| `SpotFee` | “How much extra?” 0.10%. Futures later is another struct, not a protocol. |
| `Quotes` | A dictionary of prices. Immutable, so not an actor. |
| `PlaceOrderService` (actor) | The buy button’s brain. UI calls `await place(...)`. |

**Why no protocols:** you only have one wallet and one fee in 60 minutes. A protocol is for a second implementation. An actor is for shared money.

**Why two actors:** `Wallet` protects the balance. `PlaceOrderService` protects the “already filled this id” map. `await wallet.debit` hops from one actor to the other.

---

## What happens when they tap Buy

`await place(clientOrderId: "ord-1", symbol: "BTCINR", qty: 1)` walks this checklist. **Stop at the first failure.** Do not debit and then fail.

1. **Have I seen this id already?** Yes → duplicate. Do not debit again. (Double-tap / retry.)
2. **Qty > 0?** No → reject.
3. **Do we have a quote for this coin?** No → unknown asset.
4. **Is the quote fresh?** Older than 5 seconds in the drill → stale. Refuse.
5. **Notional** = qty × price (in paise).
6. **Fee** = fee object on that notional.
7. **Total** = notional + fee. Try to debit. If wallet is short → insufficient funds. Balance unchanged.
8. Save the order under that id. Return the receipt.

Happy path in the file: buy 1 BTC.

- Notional = 500,000,000 paise (₹50 lakh)
- Fee = 500,000 paise (₹5,000)
- Total debit = 500,500,000 paise
- Wallet drops by that amount

---

## The six tests, as a story

| # | What you try | What should happen |
|---|---|---|
| 1 | Buy 1 BTC with a fresh quote | Success. Wallet down by price + fee. |
| 2 | Same `ord-1` again | Error: duplicate. Wallet **unchanged**. |
| 3 | Qty 0 | Reject. |
| 4 | Buy SOL when you only have a BTC quote | Unknown asset. |
| 5 | Buy with a quote from 30 seconds ago (limit is 5s) | Stale price. |
| 6 | Buy 2 more BTC when leftover cash is not enough | Insufficient funds. No partial debit. |

Memorize this table. In the interview, write these as `print` / `expect` in `main`.

---

## Two taps at the same time

An **actor** runs one method at a time. Two `debit` calls cannot both read “I have enough” and both subtract. That is what `NSLock` used to do, without you writing a lock.

**What you say:** “Wallet is an actor. Isolation is the serial queue. In production I would still use a database transaction for persist + debit.”

---

## If they say Flutter

- `await place(...)` → a Cubit method
- `Wallet` actor → the repository the cubit awaits; the widget never calls HTTP
- `SpotFee` → passed in; new product = new fee type, still no protocol required in 60 min

---

## Extra questions

**Why no protocol?**  
One wallet, one fee, one quote table. A protocol is for a second implementation. An actor is for races on money.

**Fractional BTC (0.001)?**  
Lots (satoshi) or `Decimal` with a rounding rule. Still not `Double`.

**Retry after crash?**  
Save the order as pending with a **unique** `clientOrderId`, then debit in one transaction. Retry finds the row instead of inserting a second debit.

**Where does the BTC go after buy?**  
A second wallet (BTC). Skipped so the round stays small. Say you would add one repository per asset.
