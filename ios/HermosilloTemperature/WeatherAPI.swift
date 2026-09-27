import Foundation

private struct DailyResponse: Decodable {
    let daily: Daily
    struct Daily: Decodable {
        let time: [String]
        let high: [Double?]
        let low: [Double?]
        let mean: [Double?]
        enum CodingKeys: String, CodingKey {
            case time
            case high = "temperature_2m_max"
            case low = "temperature_2m_min"
            case mean = "temperature_2m_mean"
        }
    }
}

private struct NormalCache: Codable {
    let saved: Date
    let days: [String: HistoricalDay]
}

private struct Samples {
    var low: [Double] = []
    var mean: [Double] = []
    var high: [Double] = []

    func stats() -> HistoricalDay {
        HistoricalDay(low: Self.summarize(low), mean: Self.summarize(mean), high: Self.summarize(high))
    }
    private static func summarize(_ values: [Double]) -> DayStats? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        func percentile(_ fraction: Double) -> Double {
            let position = Double(sorted.count - 1) * fraction
            let lower = Int(position)
            let upper = min(lower + 1, sorted.count - 1)
            return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
        }
        return DayStats(average: values.reduce(0, +) / Double(values.count), p10: percentile(0.1), p90: percentile(0.9))
    }
}

enum WeatherAPI {
    private static let latitude = "29.07297"
    private static let longitude = "-110.95592"
    private static let fields = "temperature_2m_max,temperature_2m_min,temperature_2m_mean"

    private static func request(host: String, path: String, parameters: [URLQueryItem]) async throws -> DailyResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "latitude", value: latitude),
            URLQueryItem(name: "longitude", value: longitude),
            URLQueryItem(name: "daily", value: fields),
            URLQueryItem(name: "timezone", value: "America/Hermosillo")
        ] + parameters
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 90
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(DailyResponse.self, from: data)
    }
    private static func archive(start: String, end: String) async throws -> DailyResponse {
        try await request(host: "archive-api.open-meteo.com", path: "/v1/archive", parameters: [
            URLQueryItem(name: "start_date", value: start), URLQueryItem(name: "end_date", value: end)
        ])
    }
    private static func dictionary(_ response: DailyResponse) -> [String: Temperatures] {
        var result: [String: Temperatures] = [:]
        for (index, date) in response.daily.time.enumerated() {
            result[date] = Temperatures(
                low: response.daily.low.indices.contains(index) ? response.daily.low[index] : nil,
                mean: response.daily.mean.indices.contains(index) ? response.daily.mean[index] : nil,
                high: response.daily.high.indices.contains(index) ? response.daily.high[index] : nil
            )
        }
        return result
    }
    private static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("hmo-normals-1991-2020-v2.json")
    }
    static func historical() async throws -> [String: HistoricalDay] {
        if let url = cacheURL,
           let data = try? Data(contentsOf: url),
           let cache = try? JSONDecoder().decode(NormalCache.self, from: data),
           Date().timeIntervalSince(cache.saved) < 7 * 86_400,
           cache.days["01-01"] != nil { return cache.days }

        let response = try await archive(start: "1991-01-01", end: "2020-12-31")
        var buckets: [String: Samples] = [:]
        for (index, date) in response.daily.time.enumerated() {
            let key = HermosilloDate.key(date)
            var sample = buckets[key] ?? Samples()
            if response.daily.low.indices.contains(index), let value = response.daily.low[index] { sample.low.append(value) }
            if response.daily.mean.indices.contains(index), let value = response.daily.mean[index] { sample.mean.append(value) }
            if response.daily.high.indices.contains(index), let value = response.daily.high[index] { sample.high.append(value) }
            buckets[key] = sample
        }
        let result = buckets.mapValues { $0.stats() }
        if let url = cacheURL, let data = try? JSONEncoder().encode(NormalCache(saved: .now, days: result)) {
            try? data.write(to: url, options: .atomic)
        }
        return result
    }
    static func currentYear() async throws -> YearHistory {
        let today = HermosilloDate.iso()
        let start = String(today.prefix(4)) + "-01-01"
        let end = HermosilloDate.offset(today, days: -7)
        guard end >= start else { return YearHistory(days: [:], through: nil) }
        let response = try await archive(start: start, end: end)
        let days = dictionary(response)
        let last = days.keys.sorted().last { days[$0]?.mean != nil }
        return YearHistory(days: days, through: last)
    }
    static func forecast() async throws -> [String: Temperatures] {
        let response = try await request(host: "api.open-meteo.com", path: "/v1/forecast", parameters: [
            URLQueryItem(name: "forecast_days", value: "8"),
            URLQueryItem(name: "past_days", value: "14")
        ])
        return dictionary(response)
    }
    static func historicalResult() async -> Result<[String: HistoricalDay], Error> {
        do { return .success(try await historical()) } catch { return .failure(error) }
    }
    static func yearResult() async -> Result<YearHistory, Error> {
        do { return .success(try await currentYear()) } catch { return .failure(error) }
    }
    static func forecastResult() async -> Result<[String: Temperatures], Error> {
        do { return .success(try await forecast()) } catch { return .failure(error) }
    }
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published private(set) var normals: [String: HistoricalDay] = [:]
    @Published private(set) var year: [String: Temperatures] = [:]
    @Published private(set) var forecast: [String: Temperatures] = [:]
    @Published private(set) var yearThrough: String?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        async let historical = WeatherAPI.historicalResult()
        async let currentYear = WeatherAPI.yearResult()
        async let upcoming = WeatherAPI.forecastResult()
        var failures: [String] = []
        switch await historical {
        case .success(let days): normals = days
        case .failure: failures.append("historical averages")
        }
        switch await currentYear {
        case .success(let history): year = history.days; yearThrough = history.through
        case .failure: failures.append("current-year history")
        }
        switch await upcoming {
        case .success(let days): forecast = days
        case .failure: failures.append("forecast")
        }
        updatedAt = .now
        errorMessage = failures.isEmpty ? nil : "Could not update \(failures.joined(separator: ", ")). Pull down to retry."
    }
    func forecastForKey(_ key: String) -> (date: String, temperatures: Temperatures)? {
        forecast.keys.sorted().first { HermosilloDate.key($0) == key }.flatMap { date in
            forecast[date].map { (date, $0) }
        }
    }
    func yearToDateDifference(_ metric: TemperatureMetric) -> (difference: Double, count: Int)? {
        let differences = year.compactMap { (date, value) -> Double? in
            guard let current = metric.value(in: value), let baseline = metric.stats(in: normals[HermosilloDate.key(date)])?.average else { return nil }
            return current - baseline
        }
        guard !differences.isEmpty else { return nil }
        return (differences.reduce(0, +) / Double(differences.count), differences.count)
    }
}
