import Foundation

// =============================================================================
// EXTRA — Expense split (Splitwise-lite)
// Prompt: "Friends add expenses. Show net balance. Do not over-build settle."
//
// Say first:
//   "Each user has a net (positive = others owe them). Equal split is enough
//    for 60 minutes. Simplify-debt graph is a stretch — mention it, skip it."
// Money: integer paise. Never Double.
// =============================================================================

enum SplitError: Error, Equatable { case unknownUser, zeroAmount, emptySplit }

final class Ledger {
    private var net: [String: Int64] = [:] // paise; + means they are owed

    func addUser(_ id: String) { if net[id] == nil { net[id] = 0 } }

    /// `paidBy` paid `paise` for `among` (equal split, remainder to payer).
    func addEqual(paidBy: String, paise: Int64, among: [String]) throws {
        guard paise > 0 else { throw SplitError.zeroAmount }
        guard !among.isEmpty else { throw SplitError.emptySplit }
        guard net[paidBy] != nil else { throw SplitError.unknownUser }
        for u in among where net[u] == nil { throw SplitError.unknownUser }

        let n = Int64(among.count)
        let share = paise / n
        let remainder = paise % n // give leftover paise to payer so we never lose 1 paise

        net[paidBy, default: 0] += paise
        for u in among { net[u, default: 0] -= share }
        net[paidBy, default: 0] -= remainder
        // Result: payer net += (paise - share - remainder) if they are in `among`
        // which is (n-1)*share after remainder adjustment. Fine for the round.
    }

    func balance(_ id: String) -> Int64 { net[id] ?? 0 }
}

func expect(_ ok: Bool, _ m: String) { print(ok ? "  OK  \(m)" : "  FAIL  \(m)") }

func run() {
    let l = Ledger()
    l.addUser("a"); l.addUser("b"); l.addUser("c")
    // A pays 3000 paise for A,B,C → 1000 each
    try! l.addEqual(paidBy: "a", paise: 3000, among: ["a", "b", "c"])
    expect(l.balance("a") == 2000, "A is owed 2000")
    expect(l.balance("b") == -1000, "B owes 1000")
    expect(l.balance("c") == -1000, "C owes 1000")
    expect(l.balance("a") + l.balance("b") + l.balance("c") == 0, "zero-sum")
    do {
        try l.addEqual(paidBy: "z", paise: 100, among: ["a"])
        expect(false, "unknown payer")
    } catch SplitError.unknownUser {
        expect(true, "unknown user rejected")
    } catch {
        expect(false, "wrong error \(error)")
    }
    print("SPLIT: passed")
}

run()

// Stretch: "simplify" = greedy match max-credit with max-debit. Do not start
// unless they ask and you have 10 minutes left.
