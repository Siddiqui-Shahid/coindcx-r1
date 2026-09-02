import Foundation

// =============================================================================
// EXTRA — Parking lot
// Same shape as vehicle rental (file 03): occupy a resource, leave, charge.
// Prompt: "Cars and bikes park. Find a free slot. Fee on exit."
//
// Say first:
//   "Slot is the resource. Vehicle type picks a slot size and a pricing
//    strategy. park() returns a ticket. leave() frees the slot and invoices.
//    I will not scan every slot if I can keep a queue of free ids."
// =============================================================================

enum VehicleKind: String {
    case bike, car
}

struct Vehicle: Equatable {
    let plate: String
    let kind: VehicleKind
}

struct Slot: Equatable {
    let id: Int
    let kind: VehicleKind   // bike slot vs car slot — bikes don't take car spots here
    var plate: String?      // nil = free
}

struct Ticket: Equatable {
    let slotId: Int
    let plate: String
    let inAt: Date
}

protocol Pricing {
    func fee(parkedFrom start: Date, to end: Date) -> Int64  // paise
}

struct Hourly: Pricing {
    let paisePerHour: Int64
    func fee(parkedFrom start: Date, to end: Date) -> Int64 {
        let hours = max(1, Int64(ceil(end.timeIntervalSince(start) / 3600)))
        return hours * paisePerHour
    }
}

enum LotError: Error, Equatable { case full, unknownTicket, slotTaken }

final class ParkingLot {
    private var slots: [Int: Slot]
    private var tickets: [String: Ticket] = [:] // plate -> open ticket
    private let pricing: [VehicleKind: Pricing]

    init(bikeSlots: Int, carSlots: Int, pricing: [VehicleKind: Pricing]) {
        var map: [Int: Slot] = [:]
        var id = 1
        for _ in 0..<bikeSlots { map[id] = Slot(id: id, kind: .bike, plate: nil); id += 1 }
        for _ in 0..<carSlots { map[id] = Slot(id: id, kind: .car, plate: nil); id += 1 }
        self.slots = map
        self.pricing = pricing
    }

    func park(_ v: Vehicle, at date: Date) throws -> Ticket {
        if tickets[v.plate] != nil { throw LotError.slotTaken }
        guard let slot = slots.values.first(where: { $0.kind == v.kind && $0.plate == nil }) else {
            throw LotError.full
        }
        slots[slot.id] = Slot(id: slot.id, kind: slot.kind, plate: v.plate)
        let t = Ticket(slotId: slot.id, plate: v.plate, inAt: date)
        tickets[v.plate] = t
        return t
    }

    func leave(plate: String, at date: Date) throws -> Int64 {
        guard let t = tickets[plate], var slot = slots[t.slotId] else { throw LotError.unknownTicket }
        let fee = pricing[slot.kind]!.fee(parkedFrom: t.inAt, to: date)
        slot.plate = nil
        slots[slot.id] = slot
        tickets[plate] = nil
        return fee
    }
}

func expect(_ ok: Bool, _ m: String) { print(ok ? "  OK  \(m)" : "  FAIL  \(m)") }

func run() {
    let t0 = Date(timeIntervalSince1970: 0)
    let lot = ParkingLot(
        bikeSlots: 1,
        carSlots: 1,
        pricing: [.bike: Hourly(paisePerHour: 1000), .car: Hourly(paisePerHour: 5000)]
    )
    do {
        let a = try lot.park(Vehicle(plate: "BIKE-1", kind: .bike), at: t0)
        expect(a.slotId == 1, "first free bike slot")
        do {
            _ = try lot.park(Vehicle(plate: "BIKE-2", kind: .bike), at: t0)
            expect(false, "second bike should be full")
        } catch LotError.full { expect(true, "lot full for bikes") }
        let fee = try lot.leave(plate: "BIKE-1", at: t0.addingTimeInterval(7200))
        expect(fee == 2000, "2 hours * 1000")
        _ = try lot.park(Vehicle(plate: "BIKE-2", kind: .bike), at: t0) // slot freed
        expect(true, "slot reusable after leave")
        print("PARKING: passed")
    } catch { print("FAIL \(error)") }
}

run()
