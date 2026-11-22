import Foundation

public struct CalendarDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let jdn: Int

    /// 1 = Monday ... 7 = Sunday
    public var dayOfWeek: Int {
        ((jdn % 7) + 7) % 7 + 1
    }

    public func encoded(dmy: Bool) -> Double {
        let s: String
        if dmy {
            s = String(format: "%d.%02d%04d", day, month, year)
        } else {
            s = String(format: "%d.%02d%04d", month, day, year)
        }
        return Double(s) ?? 0.0
    }
}

public enum DateMath {
    private static let minJDN = jdn(year: 1582, month: 10, day: 15)
    private static let maxJDN = jdn(year: 4046, month: 11, day: 25)

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    public static func jdn(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    public static func dateFromJDN(_ j: Int) -> CalendarDate {
        let f = j + 1401 + (((4 * j + 274277) / 146097) * 3) / 4 - 38
        let e = 4 * f + 3
        let g = (e % 1461) / 4
        let h = 5 * g + 2
        let day = (h % 153) / 5 + 1
        let month = ((h / 153 + 2) % 12) + 1
        let year = e / 1461 - 4716 + (12 + 2 - month) / 12
        return CalendarDate(year: year, month: month, day: day, jdn: j)
    }

    public static func parse(_ value: Double, dmy: Bool) throws -> CalendarDate {
        guard value.isFinite, value > 0, value < 100.0 else {
            throw CalcError(8)
        }
        let s = String(format: "%.6f", abs(value))
        let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 6, let p1 = Int(parts[0]) else {
            throw CalcError(8)
        }
        let frac = parts[1]
        let idx2 = frac.index(frac.startIndex, offsetBy: 2)
        guard let p2 = Int(frac[..<idx2]), let year = Int(frac[idx2...]) else {
            throw CalcError(8)
        }
        let day = dmy ? p1 : p2
        let month = dmy ? p2 : p1

        guard month >= 1, month <= 12,
              day >= 1, day <= daysInMonth(year: year, month: month) else {
            throw CalcError(8)
        }
        let j = jdn(year: year, month: month, day: day)
        guard j >= minJDN, j <= maxJDN else {
            throw CalcError(8)
        }
        return CalendarDate(year: year, month: month, day: day, jdn: j)
    }

    public static func subtractMonths(from date: CalendarDate, months: Int) -> CalendarDate {
        let total = (date.year * 12 + (date.month - 1)) - months
        let newYear = total >= 0 ? total / 12 : (total - 11) / 12
        let newMonth = ((total % 12) + 12) % 12 + 1
        let newDay = min(date.day, daysInMonth(year: newYear, month: newMonth))
        let j = jdn(year: newYear, month: newMonth, day: newDay)
        return CalendarDate(year: newYear, month: newMonth, day: newDay, jdn: j)
    }

    public static func addDays(dateVal: Double, days: Double, dmy: Bool) throws -> (dateVal: Double, dow: Int) {
        let base = try parse(dateVal, dmy: dmy)
        let trunc = days.rounded(.towardZero)
        guard trunc.isFinite, abs(trunc) <= 1_000_000 else {
            throw CalcError(8)
        }
        let targetJDN = base.jdn + Int(trunc)
        guard targetJDN >= minJDN, targetJDN <= maxJDN else {
            throw CalcError(8)
        }
        let result = dateFromJDN(targetJDN)
        return (result.encoded(dmy: dmy), result.dayOfWeek)
    }

    public static func deltaDays(date1Val: Double, date2Val: Double, dmy: Bool) throws -> (actual: Int, days360: Int) {
        let d1 = try parse(date1Val, dmy: dmy)
        let d2 = try parse(date2Val, dmy: dmy)
        let actual = d2.jdn - d1.jdn
        let dd1 = d1.day == 31 ? 30 : d1.day
        let dd2 = (d2.day == 31 && d1.day >= 30) ? 30 : d2.day
        let days360 = (d2.year - d1.year) * 360 + (d2.month - d1.month) * 30 + (dd2 - dd1)
        return (actual, days360)
    }
}
