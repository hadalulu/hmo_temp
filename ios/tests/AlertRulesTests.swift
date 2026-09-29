import Foundation

@main
struct AlertRulesTests {
    static func main() {
        let now = ISO8601DateFormatter().date(from: "2026-12-31T12:00:00-07:00")!
        let today = HermosilloDate.iso(now)
        let tomorrow = HermosilloDate.offset(today, days: 1)
        let normal = DayStats(average: 20, p10: 10, p90: 30)
        let normals = ["12-31": HistoricalDay(low: normal, mean: normal, high: normal),
                       "01-01": HistoricalDay(low: normal, mean: normal, high: normal)]
        func evaluate(_ temps: [String: Temperatures] = [:], _ rain: [RainHour] = [], fahrenheit: Bool = false) -> [WeatherFinding] {
            AlertRules.findings(snapshot: ForecastSnapshot(temperatures: temps, rain: rain), normals: normals, now: now, fahrenheit: fahrenheit)
        }
        func hour(_ offset: Double, _ probability: Double) -> RainHour {
            RainHour(date: now.addingTimeInterval(offset * 3_600), probability: probability)
        }
        precondition(evaluate([today: Temperatures(low: 10, mean: 20, high: 30)]).isEmpty, "Percentile equality is normal")
        let unusual = [tomorrow: Temperatures(low: 9, mean: 31, high: 31)]
        let findings = evaluate(unusual)
        precondition(findings.count == 3, "All three temperature metrics must be checked")
        precondition(findings[0].key == "temperature-\(tomorrow)-low-below")
        precondition(findings[1].key == "temperature-\(tomorrow)-mean-above")
        precondition(findings[2].key == "temperature-\(tomorrow)-high-above")
        precondition(evaluate(unusual, fahrenheit: true).map(\.key) == findings.map(\.key), "Units cannot change rule decisions")
        precondition(evaluate([HermosilloDate.offset(today, days: -1): Temperatures(low: 0, mean: 40, high: 50)]).isEmpty)
        precondition(evaluate([today: Temperatures(low: nil, mean: nil, high: nil)]).isEmpty)
        precondition(evaluate(["2027-01-02": Temperatures(low: 0, mean: 40, high: 50)]).isEmpty, "Missing baseline cannot trigger")
        precondition(evaluate([:], [hour(1, 50)]).isEmpty, "50% does not trigger")
        precondition(evaluate([:], [hour(1, 51)]).count == 1)
        precondition(evaluate([:], [hour(0, 90), hour(-1, 90), hour(49, 90)]).isEmpty, "Past and beyond-window hours do not trigger")
        precondition(evaluate([:], [hour(48, 51)]).count == 1, "Last overlapping hour must be included")
        precondition(evaluate([:], [hour(1, 51), hour(2, 80)]).count == 1, "Combine rain hours for the same date")
        precondition(evaluate([:], [hour(1, 51), hour(24, 80)]).count == 2, "Separate local dates at year boundary")
        print("Weather alert rule checks passed")
    }
}
