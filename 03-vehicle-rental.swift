import Foundation

// =============================================================================
// PROBLEM 3 — Vehicle rental (classic machine coding LLD)
//
// CoinDCX has used this shape of round (rental / booking / inventory).
// If they do NOT give a mobile UI problem, you get something like this:
//   "Add vehicles. Book a time range. No overlapping bookings. Price on return."
//
// What you say first:
//   "Vehicle, Booking, and a RentalService. Overlap is the core rule.
//    Pricing is a protocol — hourly vs daily is a new type, not a switch on enum."
//
// Flutter mapping (only if they ask): this is domain. UI is a form that calls
// book/return. Same cubit -> use case -> repository split as 01 and 02.
// =============================================================================

struct Vehicle: Equatable {
    let id: String
    let plate: String
    let kind: String          // "car", "bike" — display only; pricing is a strategy
}

enum BookingStatus: Equatable {
    case active
    case returned
}

struct Booking: Equatable {
    let id: String
    let vehicleId: String
    let userId: String
    let start: Date
    let end: Date             // requested end; actual return may be earlier/later
    var returnedAt: Date?
    var invoice: Money?
    var status: BookingStatus
}

struct Money: Equatable {
    let paise: Int64
}

enum RentalError: Error, Equatable, CustomStringConvertible {
    case unknownVehicle
    case overlap
    case notActive
    case unknownBooking

    var description: String {
        switch self {
        case .unknownVehicle: return "unknown vehicle"
        case .overlap: return "vehicle already booked in that range"
        case .notActive: return "booking is not active"
        case .unknownBooking: return "unknown booking"
        }
    }
}

/// Why a protocol: adding "weekend surcharge" later is a new struct.
/// Say: "I will not write if kind == .suv { ... } inside book()."
protocol Pricing {
    func quote(from start: Date, to end: Date) -> Money
}

struct HourlyRate: Pricing {
    let paisePerHour: Int64
    func quote(from start: Date, to end: Date) -> Money {
        let seconds = max(0, end.timeIntervalSince(start))
        let hours = Int64(ceil(seconds / 3600))
        let hoursCharged = max(1, hours) // minimum 1 hour — say this assumption
        return Money(paise: hoursCharged * paisePerHour)
    }
}

final class RentalService {
    private var vehicles: [String: Vehicle] = [:]
    private var pricing: [String: Pricing] = [:]
    private var bookings: [String: Booking] = [:]

    func addVehicle(_ v: Vehicle, pricing: Pricing) {
        vehicles[v.id] = v
        self.pricing[v.id] = pricing
    }

    /// Half-open range [start, end). Touching endpoints is allowed
    /// (return at 2pm, next booking at 2pm).
    /// Say this out loud so they don't argue overlap.
    func book(id: String, vehicleId: String, userId: String, start: Date, end: Date) throws -> Booking {
        guard vehicles[vehicleId] != nil else { throw RentalError.unknownVehicle }
        if hasOverlap(vehicleId: vehicleId, start: start, end: end) {
            throw RentalError.overlap
        }
        let b = Booking(
            id: id,
            vehicleId: vehicleId,
            userId: userId,
            start: start,
            end: end,
            returnedAt: nil,
            invoice: nil,
            status: .active
        )
        bookings[id] = b
        return b
    }

    func `return`(bookingId: String, at date: Date) throws -> Money {
        guard var b = bookings[bookingId] else { throw RentalError.unknownBooking }
        guard b.status == .active else { throw RentalError.notActive }
        guard let price = pricing[b.vehicleId] else { throw RentalError.unknownVehicle }

        // Charge actual usage: start -> return time (not the original reserved end).
        // Say: "If they return late, they pay until return. Early return: pay until return.
        //       If the product wants to charge the reserved window, I'd use b.end instead."
        let invoice = price.quote(from: b.start, to: date)
        b.returnedAt = date
        b.invoice = invoice
        b.status = .returned
        bookings[bookingId] = b
        return invoice
    }

    private func hasOverlap(vehicleId: String, start: Date, end: Date) -> Bool {
        bookings.values.contains { b in
            b.vehicleId == vehicleId
            && b.status == .active
            && rangesOverlap(start, end, b.start, b.end)
        }
    }

    /// [aStart, aEnd) overlaps [bStart, bEnd)
    private func rangesOverlap(_ aStart: Date, _ aEnd: Date, _ bStart: Date, _ bEnd: Date) -> Bool {
        aStart < bEnd && bStart < aEnd
    }
}

func runRentalScenarios() {
    let t = Date(timeIntervalSince1970: 0)
    func h(_ n: Double) -> Date { t.addingTimeInterval(n * 3600) }

    let svc = RentalService()
    svc.addVehicle(
        Vehicle(id: "v1", plate: "MH-01-AB-1234", kind: "car"),
        pricing: HourlyRate(paisePerHour: 1_000_000) // 10,000 INR/hour = 1_000_000 paise
    )

    do {
        // 1. Book 0–3h
        _ = try svc.book(id: "b1", vehicleId: "v1", userId: "u1", start: h(0), end: h(3))
        expect(true, "first booking ok")

        // 2. Overlap 2–4h
        do {
            _ = try svc.book(id: "b2", vehicleId: "v1", userId: "u2", start: h(2), end: h(4))
            expect(false, "overlap should throw")
        } catch RentalError.overlap {
            expect(true, "overlap rejected")
        }

        // 3. Touching 3–5h is OK (half-open)
        _ = try svc.book(id: "b3", vehicleId: "v1", userId: "u2", start: h(3), end: h(5))
        expect(true, "touching endpoint allowed")

        // 4. Unknown vehicle
        do {
            _ = try svc.book(id: "bx", vehicleId: "nope", userId: "u1", start: h(0), end: h(1))
            expect(false, "unknown vehicle should throw")
        } catch RentalError.unknownVehicle {
            expect(true, "unknown vehicle rejected")
        }

        // 5. Return b1 after 2 hours -> 2 * 1_000_000 paise (min 1 hour already satisfied)
        let invoice = try svc.return(bookingId: "b1", at: h(2))
        expect(invoice.paise == 2_000_000, "2 hours * 10_000 INR")

        // 6. Double return
        do {
            _ = try svc.return(bookingId: "b1", at: h(3))
            expect(false, "double return should throw")
        } catch RentalError.notActive {
            expect(true, "double return rejected")
        }

        print("RENTAL: all scenarios passed")
    } catch {
        print("FAIL unexpected \(error)")
    }
}

func expect(_ ok: Bool, _ message: String) {
    if ok { print("  OK  \(message)") }
    else { print("  FAIL  \(message)") }
}

runRentalScenarios()

// =============================================================================
// If they say "parking lot" instead
// Same skeleton: Slot, Vehicle, park(), leave(), fee by hours.
// Overlap becomes "slot occupied". Pricing strategy is identical.
// Do not memorize a second file. Swap names at the whiteboard.
// =============================================================================
