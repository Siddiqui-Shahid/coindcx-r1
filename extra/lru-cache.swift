import Foundation

// =============================================================================
// EXTRA — LRU cache
// Prompt: "Cache the last N tickers / images. Get and put in O(1)."
//
// Say first:
//   "Dictionary for lookup + doubly linked list for recency. Head = most
//    recent. On get/put move node to head. On overflow evict tail."
// Why they care: memory on a 200-coin watchlist, image cache, "what drops first".
// Flutter: same idea in a Dart class; UI never owns the cache.
// =============================================================================

final class LRUNode {
    let key: String
    var value: Int
    var prev: LRUNode?
    var next: LRUNode?
    init(_ key: String, _ value: Int) { self.key = key; self.value = value }
}

final class LRUCache {
    private let cap: Int
    private var map: [String: LRUNode] = [:]
    private let head = LRUNode("", 0) // dummy
    private let tail = LRUNode("", 0)

    init(capacity: Int) {
        self.cap = capacity
        head.next = tail
        tail.prev = head
    }

    func get(_ key: String) -> Int? {
        guard let n = map[key] else { return nil }
        moveToHead(n)
        return n.value
    }

    func put(_ key: String, _ value: Int) {
        if let n = map[key] {
            n.value = value
            moveToHead(n)
            return
        }
        let n = LRUNode(key, value)
        map[key] = n
        insertAfterHead(n)
        if map.count > cap {
            if let dead = popTail() {
                map[dead.key] = nil
            }
        }
    }

    private func moveToHead(_ n: LRUNode) {
        n.prev?.next = n.next
        n.next?.prev = n.prev
        insertAfterHead(n)
    }

    private func insertAfterHead(_ n: LRUNode) {
        n.next = head.next
        n.prev = head
        head.next?.prev = n
        head.next = n
    }

    private func popTail() -> LRUNode? {
        guard let n = tail.prev, n !== head else { return nil }
        n.prev?.next = tail
        tail.prev = n.prev
        n.prev = nil
        n.next = nil
        return n
    }
}

func expect(_ ok: Bool, _ m: String) { print(ok ? "  OK  \(m)" : "  FAIL  \(m)") }

func run() {
    let c = LRUCache(capacity: 2)
    c.put("btc", 1)
    c.put("eth", 2)
    expect(c.get("btc") == 1, "get btc")
    c.put("sol", 3) // evicts eth (least recent)
    expect(c.get("eth") == nil, "eth evicted")
    expect(c.get("btc") == 1, "btc still there")
    expect(c.get("sol") == 3, "sol there")
    print("LRU: passed")
}

run()
