import Foundation
import SwiftUI

enum TemperatureMetric: String, CaseIterable, Identifiable {
    case low, mean, high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low: return Color(red: 0.32, green: 0.53, blue: 0.59)
        case .mean: return Color(red: 0.52, green: 0.61, blue: 0.50)
        case .high: return Color(red: 0.86, green: 0.48, blue: 0.31)
        }
    }
    func value(in temperatures: Temperatures?) -> Double? {
        guard let temperatures else { return nil }
        switch self {
        case .low: return temperatures.low
        case .mean: return temperatures.mean
        case .high: return temperatures.high
        }
    }
    func stats(in day: HistoricalDay?) -> DayStats? {
        guard let day else { return nil }
        switch self {
        case .low: return day.low
        case .mean: return day.mean
        case .high: return day.high
        }
    }
}

struct Temperatures: Codable {
    let low: Double?
    let mean: Double?
    let high: Double?
}

struct DayStats: Codable {
    let average: Double
    let p10: Double
    let p90: Double
}

struct HistoricalDay: Codable {
    let low: DayStats?
    let mean: DayStats?
    let high: DayStats?
}

struct YearHistory {
    let days: [String: Temperatures]
    let through: String?
}

enum HermosilloDate {
    static let zone = TimeZone(identifier: "America/Hermosillo")!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }
    static func iso(_ date: Date = .now) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
    static func offset(_ iso: String, days: Int) -> String {
        let values = iso.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3,
              let date = calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2], hour: 12)),
              let shifted = calendar.date(byAdding: .day, value: days, to: date)
        else { return iso }
        return self.iso(shifted)
    }
    static func key(_ iso: String) -> String { String(iso.suffix(5)) }
    static let monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    static let keys: [String] = {
        (0..<366).compactMap { offset("2024-01-01", days: $0).split(separator: "-", maxSplits: 1).last.map(String.init) }
    }()
    static func label(_ key: String) -> String {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[0]) else { return key }
        return "\(monthNames[parts[0] - 1]) \(parts[1])"
    }
    static func shortLabel(_ iso: String) -> String {
        let key = self.key(iso)
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[0]) else { return iso }
        return "\(monthNames[parts[0] - 1].prefix(3)) \(parts[1])"
    }
}

enum TemperatureDisplay {
    static func value(_ celsius: Double?, fahrenheit: Bool) -> String {
        guard let celsius, celsius.isFinite else { return "—" }
        return "\(Int((fahrenheit ? celsius * 9 / 5 + 32 : celsius).rounded()))°"
    }
    static func difference(_ celsius: Double?, fahrenheit: Bool) -> String {
        guard let celsius, celsius.isFinite else { return "—" }
        let amount = fahrenheit ? celsius * 9 / 5 : celsius
        return String(format: "%+.1f°", amount)
    }
}
