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
//    Debit is fail-closed: throw if balance is short, do not go negative.
//    clientOrderId is idempotent so a retry does not charge twice.
//    Fees are a protocol so spot vs futures is a new type, not an if-else."
//
// Flutter mapping:
//   PlaceOrderService -> use case / cubit method
//   WalletRepository  -> injected; cubit never talks to HTTP
//   FeeCharging       -> strategy object
// =============================================================================

// MARK: - Money

/// Smallest currency unit. INR: 1 rupee = 100 paise.
/// Why they care: Double cannot represent 10.10. Interviews fail people who use Double.
/// Say: "I'll store paise as Int64. Display is a formatter problem, not a model problem."
struct Money: Equatable, Comparable {
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
    static func zeroINR() -> Money { .inrPaise(0) }
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

struct MarketQuote {
    let symbol: String          // "BTCINR"
    let pricePaisePerUnit: Int64  // INR paise per 1.0 coin — simplified for the round
    let asOf: Date
}

struct Order: Equatable {
    let clientOrderId: String
    let symbol: String
    let qty: Decimal            // coin qty — Decimal OK here; INR is Money
    let notional: Money         // qty * price
    let fee: Money
    let totalDebited: Money     // notional + fee
}

// MARK: - Ports

protocol WalletRepository {
    func balance() -> Money
    func credit(_ amount: Money)
    func debit(_ amount: Money) throws
}

/// Swap 0.1% spot for a different futures fee without touching PlaceOrderService.
/// Say: "Strategy. New product = new type."
protocol FeeCharging {
    func fee(on notional: Money) -> Money
}

protocol QuoteBook {
    func quote(for symbol: String) -> MarketQuote?
}

// MARK: - Impl

final class InMemoryWallet: WalletRepository {
    private var current: Money
    /// Say: "In production this is a serial queue / DB transaction.
    ///       Two debits must not both read the same balance."
    private let lock = NSLock()

    init(starting: Money) { self.current = starting }

    func balance() -> Money {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func credit(_ amount: Money) {
        lock.lock(); defer { lock.unlock() }
        current = current.adding(amount)
    }

    func debit(_ amount: Money) throws {
        lock.lock(); defer { lock.unlock() }
        if current < amount {
            throw WalletError.insufficientFunds(have: current, need: amount)
        }
        current = current.subtracting(amount)
    }
}

/// 10 bps = 0.10%. Integer math: fee = notional * 10 / 10_000.
struct SpotFee: FeeCharging {
    func fee(on notional: Money) -> Money {
        let paise = notional.minor * 10 / 10_000
        return Money(minor: paise, currency: notional.currency)
    }
}

final class StaticQuoteBook: QuoteBook {
    private let quotes: [String: MarketQuote]
    init(_ quotes: [MarketQuote]) {
        var map: [String: MarketQuote] = [:]
        quotes.forEach { map[$0.symbol] = $0 }
        self.quotes = map
    }
    func quote(for symbol: String) -> MarketQuote? { quotes[symbol] }
}

// MARK: - Use case

/// Place a market buy. This is the file you type in the round.
/// Flutter: method on a cubit / use case class. UI calls `place(clientOrderId:symbol:qty:)`.
final class PlaceOrderService {
    private let wallet: WalletRepository
    private let quotes: QuoteBook
    private let fees: FeeCharging
    private let maxPriceAge: TimeInterval
    private var filledIds: [String: Order] = [:]  // idempotency store

    init(
        wallet: WalletRepository,
        quotes: QuoteBook,
        fees: FeeCharging,
        maxPriceAge: TimeInterval = 5
    ) {
        self.wallet = wallet
        self.quotes = quotes
        self.fees = fees
        self.maxPriceAge = maxPriceAge
    }

    @discardableResult
    func place(clientOrderId: String, symbol: String, qty: Decimal, now: Date = Date()) throws -> Order {
        // Idempotent retry: same id returns the original order, no second debit.
        // Say: "Double-tap and network retry both resend the same clientOrderId."
        if let existing = filledIds[clientOrderId] {
            throw WalletError.duplicateOrder(existing.clientOrderId)
            // Alternative (also fine): return existing instead of throw.
            // Pick one, say it, stick to it. Throwing makes the test obvious.
        }

        guard qty > 0 else { throw WalletError.zeroOrNegativeQty }

        guard let q = quotes.quote(for: symbol) else { throw WalletError.unknownAsset }

        if now.timeIntervalSince(q.asOf) > maxPriceAge {
            throw WalletError.stalePrice
        }

        // qty * price -> paise. Keep it integer: qty is "whole coins" in this drill
        // so Decimal(5) * 5_000_000 paise is exact. If they ask about fractional BTC,
        // say: "I'd use a fixed lot size or Decimal rounding mode, not Double."
        let qtyInt = NSDecimalNumber(decimal: qty).int64Value
        let notional = Money.inrPaise(qtyInt * q.pricePaisePerUnit)
        let fee = fees.fee(on: notional)
        let total = notional.adding(fee)

        try wallet.debit(total)

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

func runWalletScenarios() {
    let now = Date()
    // BTC at 5,000,000 INR. 1 INR = 100 paise → 500_000_000 paise per coin.
    let fresh = MarketQuote(symbol: "BTCINR", pricePaisePerUnit: 500_000_000, asOf: now)

    // 12,000,000 INR = 1_200_000_000 paise. Enough for 2 BTC + fee, not 3.
    let wallet = InMemoryWallet(starting: .inrPaise(1_200_000_000))

    let service = PlaceOrderService(
        wallet: wallet,
        quotes: StaticQuoteBook([fresh]),
        fees: SpotFee(),
        maxPriceAge: 5
    )

    func paise(_ o: Order) -> Int64 { o.totalDebited.minor }

    do {
        // 1. Happy path: 1 BTC
        let o1 = try service.place(clientOrderId: "ord-1", symbol: "BTCINR", qty: 1, now: now)
        expect(o1.notional.minor == 500_000_000, "notional is 50 lakh INR in paise")
        expect(o1.fee.minor == 500_000, "10 bps of 500_000_000 = 500_000 paise")
        expect(paise(o1) == 500_500_000, "debit notional + fee")
        expect(wallet.balance().minor == 1_200_000_000 - 500_500_000, "balance dropped")

        // 2. Duplicate id — no second debit
        let before = wallet.balance()
        do {
            _ = try service.place(clientOrderId: "ord-1", symbol: "BTCINR", qty: 1, now: now)
            expect(false, "duplicate should throw")
        } catch WalletError.duplicateOrder {
            expect(wallet.balance() == before, "duplicate did not debit again")
        }

        // 3. Zero qty
        do {
            _ = try service.place(clientOrderId: "ord-z", symbol: "BTCINR", qty: 0, now: now)
            expect(false, "zero qty should throw")
        } catch WalletError.zeroOrNegativeQty {
            expect(true, "zero qty rejected")
        }

        // 4. Unknown asset
        do {
            _ = try service.place(clientOrderId: "ord-sol", symbol: "SOLINR", qty: 1, now: now)
            expect(false, "unknown should throw")
        } catch WalletError.unknownAsset {
            expect(true, "unknown asset rejected")
        }

        // 5. Stale price — quote.asOf is `now`; calling 30s later exceeds maxPriceAge (5s)
        do {
            _ = try service.place(
                clientOrderId: "ord-stale",
                symbol: "BTCINR",
                qty: 1,
                now: now.addingTimeInterval(30)
            )
            expect(false, "stale should throw")
        } catch WalletError.stalePrice {
            expect(true, "stale price rejected")
        }

        // 6. Insufficient funds — 2 more BTC needed ~ 1e9 paise, wallet has ~699m
        do {
            _ = try service.place(clientOrderId: "ord-big", symbol: "BTCINR", qty: 2, now: now)
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

runWalletScenarios()

// =============================================================================
// Stretch
//
// Q: Fractional BTC qty?
// A: Store qty as Decimal with a rounding mode, or lots (qty in satoshi). Never Double.
//
// Q: Persist and retry?
// A: Write the order as 'pending' with clientOrderId unique constraint, then debit
//    in one transaction. Retry reads the row instead of inserting.
//
// Q: Credit BTC after buy?
// A: Same service, second wallet (BTC). I skipped it: one currency keeps the round small.
//    Say you would add WalletRepository per asset.
// =============================================================================
