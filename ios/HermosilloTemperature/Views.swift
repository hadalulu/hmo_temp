import SwiftUI

private let ink = Color(red: 0.14, green: 0.21, blue: 0.22)
private let sand = Color(red: 0.97, green: 0.96, blue: 0.93)

struct UnitButton: View {
    @Binding var fahrenheit: Bool
    var body: some View {
        Button(fahrenheit ? "°F" : "°C") { fahrenheit.toggle() }
            .font(.subheadline.bold())
            .accessibilityLabel("Switch to \(fahrenheit ? "Celsius" : "Fahrenheit")")
    }
}

struct WeatherNotice: View {
    @EnvironmentObject private var store: WeatherStore
    var body: some View {
        if let message = store.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        } else if store.isLoading && store.forecast.isEmpty {
            HStack { ProgressView(); Text("Loading Hermosillo weather…") }
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct MetricValue: View {
    let metric: TemperatureMetric
    let value: Double?
    let baseline: Double?
    let fahrenheit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(metric.title.uppercased()).font(.caption2.bold()).tracking(1.5).foregroundStyle(.secondary)
            Text(TemperatureDisplay.value(value, fahrenheit: fahrenheit))
                .font(.system(size: 34, weight: .regular, design: .serif))
                .foregroundStyle(metric.color)
                .minimumScaleFactor(0.7).lineLimit(1)
            if let value, let baseline {
                Text("\(TemperatureDisplay.difference(value - baseline, fahrenheit: fahrenheit)) vs avg")
                    .font(.caption2).foregroundStyle(value >= baseline ? Color.orange : Color.blue)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(ink.opacity(0.07)))
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: WeatherStore
    @Binding var fahrenheit: Bool

    private var today: String { HermosilloDate.iso() }
    private var upcoming: [String] { store.forecast.keys.filter { $0 > today }.sorted().prefix(7).map { $0 } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SONORA · MEXICO").font(.caption2.bold()).tracking(2).foregroundStyle(.orange)
                    Text("Feel the year.").font(.system(size: 39, design: .serif)).foregroundStyle(ink)
                    Text("Hermosillo · \(HermosilloDate.shortLabel(today))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.padding(.top, 12)
                WeatherNotice()
                SectionCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Today’s forecast", systemImage: "sun.max")
                            .font(.headline).foregroundStyle(ink)
                        HStack(alignment: .top, spacing: 5) {
                            ForEach(TemperatureMetric.allCases) { metric in
                                MetricValue(metric: metric, value: metric.value(in: store.forecast[today]),
                                            baseline: metric.stats(in: store.normals[HermosilloDate.key(today)])?.average,
                                            fahrenheit: fahrenheit)
                            }
                        }
                        Text("Daily model values may change. Differences are against the 1991–2020 average for this date.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Coming days").font(.system(.title2, design: .serif)).foregroundStyle(ink)
                    Text("Forecast low, mean, high · difference from historical average")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 6)
                if upcoming.isEmpty && !store.isLoading {
                    SectionCard { Text("Forecast unavailable. Pull down to retry.").foregroundStyle(.secondary) }
                }
                ForEach(upcoming, id: \.self) { date in
                    SectionCard {
                        VStack(alignment: .leading, spacing: 13) {
                            Text(HermosilloDate.shortLabel(date))
                                .font(.subheadline.bold()).foregroundStyle(ink)
                            HStack(alignment: .top, spacing: 5) {
                                ForEach(TemperatureMetric.allCases) { metric in
                                    MetricValue(metric: metric, value: metric.value(in: store.forecast[date]),
                                                baseline: metric.stats(in: store.normals[HermosilloDate.key(date)])?.average,
                                                fahrenheit: fahrenheit)
                                }
                            }
                        }
                    }
                }
                Text("Source: Open-Meteo forecast and historical reanalysis. Dates use Hermosillo local time.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.vertical, 8)
            }.padding(16)
        }
        .background(sand)
        .refreshable { await store.load() }
        .navigationTitle("Today")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { UnitButton(fahrenheit: $fahrenheit) } }
    }
}

struct YearView: View {
    @EnvironmentObject private var store: WeatherStore
    @Binding var fahrenheit: Bool
    @State private var month = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WeatherNotice()
                SectionCard {
                    VStack(alignment: .leading, spacing: 13) {
                        Text("A year of temperatures").font(.system(.title2, design: .serif)).foregroundStyle(ink)
                        Text("1991–2020 daily averages, this year, and recent model / forecast values")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Zoom to month", selection: $month) {
                            Text("Full year").tag(0)
                            ForEach(1...12, id: \.self) { index in
                                Text(HermosilloDate.monthNames[index - 1]).tag(index)
                            }
                        }.pickerStyle(.menu)
                        AnnualChartView(month: month, fahrenheit: fahrenheit)
                            .frame(height: 285)
                        HStack(spacing: 14) {
                            ForEach(TemperatureMetric.allCases) { metric in
                                Label(metric.title, systemImage: "line.diagonal")
                                    .font(.caption2).foregroundStyle(metric.color)
                            }
                        }
                        Text("Light bands: historical 10th–90th percentiles. Solid: archived current year. Dotted: recent model values and forecast.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                SectionCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(String(HermosilloDate.iso().prefix(4))) vs. historical averages")
                            .font(.system(.title2, design: .serif)).foregroundStyle(ink)
                        if let through = store.yearThrough {
                            Text("Archived daily values through \(HermosilloDate.shortLabel(through)). Differences average the same calendar dates across 1991–2020.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(alignment: .top, spacing: 6) {
                            ForEach(TemperatureMetric.allCases) { metric in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(metric.title.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                                    if let result = store.yearToDateDifference(metric) {
                                        Text(TemperatureDisplay.difference(result.difference, fahrenheit: fahrenheit))
                                            .font(.system(size: 28, design: .serif)).foregroundStyle(metric.color)
                                        Text("\(result.count) days").font(.caption2).foregroundStyle(.secondary)
                                    } else {
                                        Text("—").foregroundStyle(.secondary)
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }.padding(16)
        }
        .background(sand)
        .refreshable { await store.load() }
        .navigationTitle("Annual cycle")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { UnitButton(fahrenheit: $fahrenheit) } }
    }
}

struct CalendarView: View {
    @EnvironmentObject private var store: WeatherStore
    @Binding var fahrenheit: Bool
    @State private var selection = 0 // 0: start today; 13: January first; 1...12: month

    private var orderedKeys: [String] {
        let keys = HermosilloDate.keys
        if selection == 13 { return keys }
        if selection > 0 { return keys.filter { Int($0.prefix(2)) == selection } }
        let today = HermosilloDate.key(HermosilloDate.iso())
        return keys.filter { $0 >= today } + keys.filter { $0 < today }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                WeatherNotice()
                Text("Explore the calendar").font(.system(.title2, design: .serif)).foregroundStyle(ink)
                Text("Typical temperatures for every calendar date, with archived values, recent model estimates, and forecasts where available.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Dates", selection: $selection) {
                    Text("From today").tag(0)
                    Text("All months").tag(13)
                    ForEach(1...12, id: \.self) { index in
                        Text(HermosilloDate.monthNames[index - 1]).tag(index)
                    }
                }.pickerStyle(.menu)
                ForEach(orderedKeys, id: \.self) { key in
                    CalendarDayRow(key: key, fahrenheit: fahrenheit)
                }
            }.padding(16)
        }
        .background(sand)
        .refreshable { await store.load() }
        .navigationTitle("Calendar")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { UnitButton(fahrenheit: $fahrenheit) } }
    }
}

private struct CalendarDayRow: View {
    @EnvironmentObject private var store: WeatherStore
    let key: String
    let fahrenheit: Bool

    private var currentDate: String { String(HermosilloDate.iso().prefix(4)) + "-" + key }
    private var today: String { HermosilloDate.iso() }
    private var recent: (String, Temperatures)? {
        store.forecast.keys.sorted().first { $0 < today && HermosilloDate.key($0) == key }.flatMap { date in
            store.forecast[date].map { (date, $0) }
        }
    }
    private var future: (String, Temperatures)? {
        store.forecast.keys.sorted().first { $0 >= today && HermosilloDate.key($0) == key }.flatMap { date in
            store.forecast[date].map { (date, $0) }
        }
    }
    var body: some View {
        let archive = store.year[currentDate]
        let isModel = archive?.mean == nil && recent != nil
        let actual = isModel ? recent?.1 : archive
        SectionCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(HermosilloDate.label(key)).font(.subheadline.bold()).foregroundStyle(ink)
                    if key == HermosilloDate.key(today) { Text("TODAY").foregroundStyle(.orange) }
                    if isModel { Text("MODEL").foregroundStyle(.orange) }
                }.font(.caption2.bold())
                metricLine("Average", values: Temperatures(
                    low: store.normals[key]?.low?.average,
                    mean: store.normals[key]?.mean?.average,
                    high: store.normals[key]?.high?.average))
                if let actual { metricLine(isModel ? "Recent model" : "This year", values: actual) }
                if let future { metricLine("Forecast", values: future.1) }
            }
        }
    }
    private func metricLine(_ title: String, values: Temperatures) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).frame(width: 95, alignment: .leading).foregroundStyle(.secondary)
            ForEach(TemperatureMetric.allCases) { metric in
                Text(TemperatureDisplay.value(metric.value(in: values), fahrenheit: fahrenheit))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundStyle(metric.color)
            }
        }.font(.caption.monospacedDigit())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), low \(TemperatureDisplay.value(values.low, fahrenheit: fahrenheit)), mean \(TemperatureDisplay.value(values.mean, fahrenheit: fahrenheit)), high \(TemperatureDisplay.value(values.high, fahrenheit: fahrenheit))")
    }
}
