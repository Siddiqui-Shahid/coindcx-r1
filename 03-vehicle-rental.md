# Vehicle rental — explained in plain English

Companion to `03-vehicle-rental.swift`. Read this first, then glance at the code.

This is the **classic LLD** shape. If they do **not** give you a ticker or wallet, they often give booking / parking / inventory. Same skeleton. Different names.

---

## What they are asking

A Zoomcar-style shop:

- Add cars.
- Someone books 9am–12pm.
- Nobody else can book that car overlapping those hours.
- When they return the car, print a bill.

The core rule is **overlap**. Pricing is secondary.

---

## The one sentence you say first

> Vehicle, Booking, RentalService. Overlap is the core rule. Hourly vs daily price is a separate object — I will not write `if kind == suv` inside book.

---

## The pieces

| Thing in code | Everyday meaning |
|---|---|
| `Vehicle` | One car. Id, plate, a label like “car”. The label is **not** used for price. |
| `Booking` | A reservation: who, which car, from–to, still active or already returned, bill if any. |
| `Money` | Paise again. ₹10,000 / hour = `1_000_000` paise. |
| `HourlyRate` | “Given two timestamps, how many rupees?” Round up, minimum 1 hour. |
| `RentalService` | Add vehicle, book, return. Holds the maps. |

**Why pricing is not `if vehicle.kind == "suv"`:**  
`book()` never looks at the label. It looks up `HourlyRate` for that car. Daily or weekend later is another struct. No protocol until you have two rate types.

---

## Overlap — the rule you must say out loud

Bookings use a **half-open** range: `[start, end)`.

- Includes the start.
- **Does not** include the end.

So:

- Booked 0:00–3:00.
- Next booking **3:00–5:00** is **allowed** (they touch at 3, they do not overlap).
- Booking **2:00–4:00** is **rejected** (2 sits inside 0–3).

Two ranges overlap when:

> A starts before B ends, **and** B starts before A ends.

Only **active** bookings count. After return, that car is free for those hours in this simple model (we do not keep blocking the original reserved window after return).

Say the half-open rule **before** they argue with you about “is 3pm free?”.

---

## Book, then return

**Book**

1. Car exists? No → unknown vehicle.
2. Any active booking on that car overlapping this window? Yes → overlap error.
3. Save booking as `active`.

**Return**

1. Booking exists? No → unknown.
2. Already returned? → not active (cannot return twice).
3. Bill from **actual start → return time**, not the original reserved end.

So if they reserved 3 hours but brought it back after 2, they pay **2 hours** in this drill.

**Say the assumption:** “I’m charging actual usage. If the product wants to charge the reserved window even on early return, I’d use the original end time instead.”

Late return: they pay until the return clock, so they pay more. Same formula.

Minimum 1 hour: even a 5-minute trip bills 1 hour. Say that too.

---

## Walk through the test

One car. ₹10,000 per hour.

| Step | Result |
|---|---|
| Book 0–3h | OK |
| Book 2–4h on the same car | Overlap — rejected |
| Book 3–5h | OK — touches at 3, half-open |
| Book a car id that does not exist | Unknown vehicle |
| Return the first booking at hour 2 | Bill = 2 × ₹10,000 |
| Return that booking again | Not active |

---

## What you type in 60 minutes

1. `Vehicle`, `Booking`, `BookingStatus`, `Money`
2. `HourlyRate` (concrete — no protocol)
3. `RentalService` with `addVehicle`, `book`, `return`, private `hasOverlap`
4. `main` with the table above

If they say **parking lot** instead: slot = the car, `park` / `leave` = book / return, “occupied” = overlap. Do not memorize a second design. Swap names.

---

## If they say Flutter

This is domain logic. A form calls `book` / `return`. Same split as watchlist: cubit → service → memory/API. Do not start building a calendar UI.
