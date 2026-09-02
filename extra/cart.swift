import Foundation

// =============================================================================
// EXTRA — Shopping cart
// CoinDCX frontend SSE-1 used a cart machine-coding exercise (add / remove /
// qty / total). Mobile may get the same with a list UI.
//
// Say first:
//   "Line is productId + qty. Total is sum(qty * unitPrice). Qty 0 removes
//    the line. Unknown id on add = error. Coupon later = fee Strategy."
// Flutter: cubit state = lines + total. Widget only renders.
// =============================================================================

struct Product: Equatable {
    let id: String
    let name: String
    let unitPaise: Int64
}

enum CartError: Error, Equatable { case unknownProduct, unknownLine }

final class Cart {
    private let catalog: [String: Product]
    private var qty: [String: Int] = [:]

    init(catalog: [Product]) {
        var m: [String: Product] = [:]
        catalog.forEach { m[$0.id] = $0 }
        self.catalog = m
    }

    func add(_ productId: String, units: Int = 1) throws {
        guard catalog[productId] != nil else { throw CartError.unknownProduct }
        guard units > 0 else { return }
        qty[productId, default: 0] += units
    }

    func setQty(_ productId: String, units: Int) throws {
        guard qty[productId] != nil else { throw CartError.unknownLine }
        if units <= 0 { qty[productId] = nil; return }
        qty[productId] = units
    }

    func remove(_ productId: String) { qty[productId] = nil }

    func totalPaise() -> Int64 {
        qty.reduce(0) { acc, pair in
            acc + Int64(pair.value) * (catalog[pair.key]?.unitPaise ?? 0)
        }
    }

    func lines() -> Int { qty.count }
}

func expect(_ ok: Bool, _ m: String) { print(ok ? "  OK  \(m)" : "  FAIL  \(m)") }

func run() {
    let cart = Cart(catalog: [
        Product(id: "btc", name: "BTC", unitPaise: 100),
        Product(id: "eth", name: "ETH", unitPaise: 50),
    ])
    do {
        try cart.add("btc", units: 2)
        try cart.add("eth")
        expect(cart.totalPaise() == 250, "2*100 + 50")
        try cart.setQty("btc", units: 1)
        expect(cart.totalPaise() == 150, "qty update")
        try cart.setQty("eth", units: 0)
        expect(cart.lines() == 1, "qty 0 removes line")
        cart.remove("btc")
        expect(cart.totalPaise() == 0, "empty")
        do {
            try cart.add("sol")
            expect(false, "unknown product")
        } catch CartError.unknownProduct { expect(true, "unknown product rejected") }
        print("CART: passed")
    } catch { print("FAIL \(error)") }
}

run()

// Stretch: coupon = Strategy (same as fees in file 02). Debounce on search
// of catalog: 300ms, say it, don't code a Timer unless they ask.
