# Extra — so this round does not ambush you

The four files in the parent folder are the core. **Do not rewrite those.**
This folder is only if they give a *different* prompt, or they stretch you
after the happy path.

Skim `HOW-YOU-FAIL.md` first (10 min). Then pick **one** Swift file that
matches a prompt you have not practiced. Run:

```bash
swift extra/parking-lot.swift
swift extra/rate-limiter.swift
swift extra/lru-cache.swift
swift extra/expense-split.swift
swift extra/cart.swift
```

Do not try to memorize all five. Know the *shape*: models → protocol →
in-memory → 4 prints. Swap names on the call.

## Which file if they say…

| They say | Open |
|---|---|
| Parking lot, slots, entry/exit fee | `parking-lot.swift` |
| Rate limit, throttle, 100 req/min, API abuse | `rate-limiter.swift` |
| Cache, LRU, “images / ticker memory”, capacity | `lru-cache.swift` |
| Splitwise, settle up, who owes whom | `expense-split.swift` |
| Shopping cart, qty, total (CoinDCX frontend used this) | `cart.swift` |
| Snake & ladder / chess / elevator | Same skeleton as parking: entities + rules + `main`. Do not start a UI. |

## Still Swift. Still no Dart.

If they insist on Dart: types + `main()`, copy the same rules, skip widgets.
