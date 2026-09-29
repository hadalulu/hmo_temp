import Foundation

struct RainHour {
    let date: Date
    let probability: Double
}

struct ForecastSnapshot {
    let temperatures: [String: Temperatures]
    let rain: [RainHour]
}

struct WeatherFinding {
    let key: String
    let date: String
    let message: String
}

// Pure rules, shared by foreground and background checks.
enum AlertRules {
    static func findings(snapshot: ForecastSnapshot, normals: [String: HistoricalDay], now: Date, fahrenheit: Bool) -> [WeatherFinding] {
        var result: [WeatherFinding] = []
        let today = HermosilloDate.iso(now)
        let end = now.addingTimeInterval(48 * 3_600)
        // Probability describes the preceding hour. Include hours overlapping the window.
        let rain = snapshot.rain.filter { $0.date > now && $0.date.addingTimeInterval(-3_600) < end && $0.probability > 50 }
        let grouped = Dictionary(grouping: rain) { HermosilloDate.iso($0.date.addingTimeInterval(-1)) }
        for date in grouped.keys.sorted() {
            guard let peak = grouped[date]?.max(by: { $0.probability < $1.probability }) else { continue }
            result.append(WeatherFinding(key: "rain-\(date)", date: date,
                message: "\(HermosilloDate.shortLabel(date)): rain probability up to \(Int(peak.probability.rounded()))% within 48 hours."))
        }
        for date in snapshot.temperatures.keys.sorted() where date >= today {
            for metric in TemperatureMetric.allCases {
                guard let value = metric.value(in: snapshot.temperatures[date]),
                      let stats = metric.stats(in: normals[HermosilloDate.key(date)]),
                      value < stats.p10 || value > stats.p90 else { continue }
                let direction = value < stats.p10 ? "below" : "above"
                let range = "\(TemperatureDisplay.value(stats.p10, fahrenheit: fahrenheit))–\(TemperatureDisplay.value(stats.p90, fahrenheit: fahrenheit))"
                result.append(WeatherFinding(key: "temperature-\(date)-\(metric.rawValue)-\(direction)", date: date,
                    message: "\(HermosilloDate.shortLabel(date)) \(metric.rawValue): \(TemperatureDisplay.value(value, fahrenheit: fahrenheit)), \(direction) historical 10th–90th range (\(range))."))
            }
        }
        return result
    }
}

