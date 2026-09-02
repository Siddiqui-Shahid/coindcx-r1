import Foundation

// =============================================================================
// PROBLEM 2 — Wallet + place market order
//
// Interview prompt (typical):
//   "User has an INR wallet. They buy BTC at the current price. Handle fees,
//    insufficient funds, and accidental double-tap."
//
// What you say first:
//   "Money is integer minor units — paise — never Double.
//    Wallet is an actor so two debits cannot both pass the balance check.
//    PlaceOrderService is an actor so the same clientOrderId cannot debit twice.
//    Debit is fail-closed. Fees are a concrete type — futures is another type later."
//
// Flutter mapping:
//   PlaceOrderService.place -> cubit / use-case method
//   Wallet actor            -> repository the cubit awaits
//   SpotFee                 -> fee object you inject (Strategy without a protocol)
// =============================================================================

// MARK: - Money

/// Smallest currency unit. INR: 1 rupee = 100 paise.
/// Why they care: Double cannot represent 10.10. Interviews fail people who use Double.
/// Say: "I'll store paise as Int64. Display is a formatter problem, not a model problem."
struct Money: Equatable, Comparable, Sendable {
    let minor: Int64
    let currency: String

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "do not compare mixed currencies")
        return lhs.minor < rhs.minor
    }

    func adding(_ other: Money) -> Money {
        precondition(currency == other.currency)
        return Money(minor: minor + other.minor, currency: currency)
    }

    func subtracting(_ other: Money) -> Money {
        precondition(currency == other.currency)
        return Money(minor: minor - other.minor, currency: currency)
    }

    static func inrPaise(_ paise: Int64) -> Money { Money(minor: paise, currency: "INR") }
}

enum WalletError: Error, Equatable, CustomStringConvertible {
    case insufficientFunds(have: Money, need: Money)
    case zeroOrNegativeQty
    case stalePrice
    case duplicateOrder(String)
    case unknownAsset

    var description: String {
        switch self {
        case let .insufficientFunds(have, need):
            return "insufficient funds have=\(have.minor) need=\(need.minor)"
        case .zeroOrNegativeQty: return "qty must be > 0"
        case .stalePrice: return "price too old"
        case let .duplicateOrder(id): return "duplicate order \(id)"
        case .unknownAsset: return "unknown asset"
        }
    }
}

struct MarketQuote: Sendable {
    let symbol: String
    let pricePaisePerUnit: Int64
    let asOf: Date
}

struct Order: Equatable, Sendable {
    let clientOrderId: String
    let symbol: String
    let qty: Decimal
    let notional: Money
    let fee: Money
    let totalDebited: Money
}

// MARK: - Concrete helpers (no protocols)

/// 10 bps = 0.10%. Integer math: fee = notional * 10 / 10_000.
/// Say: "If they add futures I write another struct with the same fee(on:) method.
///       I do not need a protocol for one implementation in 60 minutes."
struct SpotFee: Sendable {
    func fee(on notional: Money) -> Money {
        let paise = notional.minor * 10 / 10_000
        return Money(minor: paise, currency: notional.currency)
    }
}

/// In-memory price table. Immutable after init — no actor needed.
struct Quotes: Sendable {
    private let quotes: [String: MarketQuote]

    init(_ list: [MarketQuote]) {
        var map: [String: MarketQuote] = [:]
        list.forEach { map[$0.symbol] = $0 }
        self.quotes = map
    }

    func quote(for symbol: String) -> MarketQuote? { quotes[symbol] }
}

// MARK: - Actors (this replaces NSLock + protocols)

/// The wallet. Actor = one-at-a-time access. Two Buy taps cannot both read
/// "enough cash" and both subtract.
/// Say: "Actor isolation is the serial queue. Production can still be a DB transaction."
actor Wallet {
    private var current: Money

    init(starting: Money) { self.current = starting }

    func balance() -> Money { current }

    func credit(_ amount: Money) {
        current = current.adding(amount)
    }

    func debit(_ amount: Money) throws {
        if current < amount {
            throw WalletError.insufficientFunds(have: current, need: amount)
        }
        current = current.subtracting(amount)
    }
}

/// Place a market buy. Actor so `filledIds` cannot race with a double-tap.
/// Flutter: cubit method. UI calls `await place(...)`.
actor PlaceOrderService {
    private let wallet: Wallet
    private let quotes: Quotes
    private let fees: SpotFee
    private let maxPriceAge: TimeInterval
    private var filledIds: [String: Order] = [:]

    init(
        wallet: Wallet,
        quotes: Quotes,
        fees: SpotFee,
        maxPriceAge: TimeInterval = 5
    ) {
        self.wallet = wallet
        self.quotes = quotes
        self.fees = fees
        self.maxPriceAge = maxPriceAge
    }

    @discardableResult
    func place(
        clientOrderId: String,
        symbol: String,
        qty: Decimal,
        now: Date = Date()
    ) async throws -> Order {
        // Same id: refuse. Actor makes this check-then-set safe.
        // Say: "Double-tap and network retry both resend the same clientOrderId."
        if let existing = filledIds[clientOrderId] {
            throw WalletError.duplicateOrder(existing.clientOrderId)
        }

        guard qty > 0 else { throw WalletError.zeroOrNegativeQty }
        guard let q = quotes.quote(for: symbol) else { throw WalletError.unknownAsset }

        if now.timeIntervalSince(q.asOf) > maxPriceAge {
            throw WalletError.stalePrice
        }

        // Whole coins in this drill. Fractional BTC: lots or Decimal rounding, not Double.
        let qtyInt = NSDecimalNumber(decimal: qty).int64Value
        let notional = Money.inrPaise(qtyInt * q.pricePaisePerUnit)
        let fee = fees.fee(on: notional)
        let total = notional.adding(fee)

        try await wallet.debit(total)

        let order = Order(
            clientOrderId: clientOrderId,
            symbol: symbol,
            qty: qty,
            notional: notional,
            fee: fee,
            totalDebited: total
        )
        filledIds[clientOrderId] = order
        return order
    }
}

// MARK: - Driver

func runWalletScenarios() async {
    let now = Date()
    // BTC at 5,000,000 INR. 1 INR = 100 paise → 500_000_000 paise per coin.
    let fresh = MarketQuote(symbol: "BTCINR", pricePaisePerUnit: 500_000_000, asOf: now)

    // 12,000,000 INR = 1_200_000_000 paise. Enough for 2 BTC + fee, not 3.
    let wallet = Wallet(starting: .inrPaise(1_200_000_000))

    let service = PlaceOrderService(
        wallet: wallet,
        quotes: Quotes([fresh]),
        fees: SpotFee(),
        maxPriceAge: 5
    )

    func paise(_ o: Order) -> Int64 { o.totalDebited.minor }

    do {
        // 1. Happy path: 1 BTC
        let o1 = try await service.place(clientOrderId: "ord-1", symbol: "BTCINR", qty: 1, now: now)
        expect(o1.notional.minor == 500_000_000, "notional is 50 lakh INR in paise")
        expect(o1.fee.minor == 500_000, "10 bps of 500_000_000 = 500_000 paise")
        expect(paise(o1) == 500_500_000, "debit notional + fee")
        expect(await wallet.balance().minor == 1_200_000_000 - 500_500_000, "balance dropped")

        // 2. Duplicate id — no second debit
        let before = await wallet.balance()
        do {
            _ = try await service.place(clientOrderId: "ord-1", symbol: "BTCINR", qty: 1, now: now)
            expect(false, "duplicate should throw")
        } catch WalletError.duplicateOrder {
            expect(await wallet.balance() == before, "duplicate did not debit again")
        }

        // 3. Zero qty
        do {
            _ = try await service.place(clientOrderId: "ord-z", symbol: "BTCINR", qty: 0, now: now)
            expect(false, "zero qty should throw")
        } catch WalletError.zeroOrNegativeQty {
            expect(true, "zero qty rejected")
        }

        // 4. Unknown asset
        do {
            _ = try await service.place(clientOrderId: "ord-sol", symbol: "SOLINR", qty: 1, now: now)
            expect(false, "unknown should throw")
        } catch WalletError.unknownAsset {
            expect(true, "unknown asset rejected")
        }

        // 5. Stale price — quote.asOf is `now`; calling 30s later exceeds maxPriceAge (5s)
        do {
            _ = try await service.place(
                clientOrderId: "ord-stale",
                symbol: "BTCINR",
                qty: 1,
                now: now.addingTimeInterval(30)
            )
            expect(false, "stale should throw")
        } catch WalletError.stalePrice {
            expect(true, "stale price rejected")
        }

        // 6. Insufficient funds
        do {
            _ = try await service.place(clientOrderId: "ord-big", symbol: "BTCINR", qty: 2, now: now)
            expect(false, "insufficient should throw")
        } catch WalletError.insufficientFunds {
            expect(true, "insufficient funds rejected")
        }

        print("WALLET: all scenarios passed")
    } catch {
        print("FAIL unexpected \(error)")
    }
}

func expect(_ ok: Bool, _ message: String) {
    if ok { print("  OK  \(message)") }
    else { print("  FAIL  \(message)") }
}

await runWalletScenarios()

// =============================================================================
// Stretch
//
// Q: Why actors instead of a protocol + NSLock?
// A: Wallet and the order-id map are shared mutable state. An actor serializes
//    that. I do not need a protocol until I have a second implementation.
//
// Q: Fractional BTC qty?
// A: Lots (satoshi) or Decimal with a rounding mode. Never Double.
//
// Q: Persist and retry?
// A: Unique clientOrderId in the DB, debit in one transaction. Retry reads the row.
//
// Q: Credit BTC after buy?
// A: Second Wallet actor for BTC. Skipped so the round stays one currency.
// =============================================================================
