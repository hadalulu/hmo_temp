import SwiftUI

struct AnnualChartView: View {
    @EnvironmentObject private var store: WeatherStore
    let month: Int
    let fahrenheit: Bool
    @State private var selectedKey: String?

    private var keys: [String] {
        month == 0 ? HermosilloDate.keys : HermosilloDate.keys.filter { Int($0.prefix(2)) == month }
    }
    private func model(for key: String) -> Temperatures? {
        let date = store.forecast.keys.sorted().first { HermosilloDate.key($0) == key }
        guard let date else { return nil }
        if date == store.yearThrough, let archive = store.year[date] { return archive }
        guard date >= (store.yearThrough ?? HermosilloDate.iso()) else { return nil }
        return store.forecast[date]
    }
    private func chartValues(_ keys: [String]) -> [Double] {
        let year = String(HermosilloDate.iso().prefix(4))
        return keys.flatMap { key -> [Double] in
            TemperatureMetric.allCases.flatMap { metric in
                [metric.stats(in: store.normals[key])?.p10,
                 metric.stats(in: store.normals[key])?.p90,
                 metric.value(in: store.year[year + "-" + key]),
                 metric.value(in: model(for: key))].compactMap { $0 }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geometry in
                Canvas { context, size in
                    let shown = keys
                    guard !shown.isEmpty else { return }
                    let values = chartValues(shown)
                    let lower = floor((values.min() ?? 0) / 5) * 5
                    let upper = max(lower + 5, ceil((values.max() ?? 50) / 5) * 5)
                    let left: CGFloat = 40, right: CGFloat = 10, top: CGFloat = 10, bottom: CGFloat = 30
                    let width = max(1, size.width - left - right)
                    let height = max(1, size.height - top - bottom)
                    func x(_ index: Int) -> CGFloat { left + CGFloat(index) / CGFloat(max(1, shown.count - 1)) * width }
                    func y(_ value: Double) -> CGFloat { top + CGFloat((upper - value) / (upper - lower)) * height }

                    for tick in stride(from: Int(ceil(lower / 10) * 10), through: Int(upper), by: 10) {
                        let level = y(Double(tick))
                        var line = Path()
                        line.move(to: CGPoint(x: left, y: level))
                        line.addLine(to: CGPoint(x: size.width - right, y: level))
                        context.stroke(line, with: .color(.gray.opacity(0.14)), lineWidth: 1)
                        context.draw(Text(TemperatureDisplay.value(Double(tick), fahrenheit: fahrenheit))
                            .font(.system(size: 10)).foregroundColor(.gray), at: CGPoint(x: 17, y: level))
                    }
                    for (index, key) in shown.enumerated() {
                        let day = Int(key.suffix(2)) ?? 0
                        if month == 0 ? day == 1 : [1, 8, 15, 22, 29].contains(day) {
                            let label = month == 0
                                ? String(HermosilloDate.monthNames[(Int(key.prefix(2)) ?? 1) - 1].prefix(3))
                                : String(day)
                            context.draw(Text(label).font(.system(size: 10)).foregroundColor(.gray),
                                         at: CGPoint(x: x(index), y: size.height - 10), anchor: .leading)
                        }
                    }
                    for metric in TemperatureMetric.allCases {
                        var lowerBand: [CGPoint] = [], upperBand: [CGPoint] = []
                        for (index, key) in shown.enumerated() {
                            guard let stats = metric.stats(in: store.normals[key]) else { continue }
                            lowerBand.append(CGPoint(x: x(index), y: y(stats.p10)))
                            upperBand.append(CGPoint(x: x(index), y: y(stats.p90)))
                        }
                        if let first = lowerBand.first {
                            var band = Path()
                            band.move(to: first)
                            lowerBand.dropFirst().forEach { band.addLine(to: $0) }
                            upperBand.reversed().forEach { band.addLine(to: $0) }
                            band.closeSubpath()
                            context.fill(band, with: .color(metric.color.opacity(0.12)))
                        }
                        func stroke(_ source: (String) -> Double?, width lineWidth: CGFloat, dash: [CGFloat], color: Color) {
                            var path = Path(), started = false
                            for (index, key) in shown.enumerated() {
                                guard let value = source(key) else { started = false; continue }
                                let point = CGPoint(x: x(index), y: y(value))
                                if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                            }
                            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: dash))
                        }
                        stroke({ metric.stats(in: store.normals[$0])?.average }, width: 2, dash: [], color: metric.color)
                        let year = String(HermosilloDate.iso().prefix(4))
                        stroke({ metric.value(in: store.year[year + "-" + $0]) }, width: 1.5, dash: [], color: metric.color.opacity(0.65))
                        stroke({ metric.value(in: model(for: $0)) }, width: 2.5, dash: [3, 5], color: metric.color)
                    }
                    if let selectedKey, let index = shown.firstIndex(of: selectedKey) {
                        var cursor = Path()
                        cursor.move(to: CGPoint(x: x(index), y: top))
                        cursor.addLine(to: CGPoint(x: x(index), y: size.height - bottom))
                        context.stroke(cursor, with: .color(.primary.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                    let left: CGFloat = 40, right: CGFloat = 10
                    let width = max(1, geometry.size.width - left - right)
                    let ratio = min(1, max(0, (gesture.location.x - left) / width))
                    let index = min(keys.count - 1, max(0, Int((ratio * CGFloat(keys.count - 1)).rounded())))
                    selectedKey = keys[index]
                })
            }
            if let selectedKey {
                let baseline = store.normals[selectedKey]
                let year = String(HermosilloDate.iso().prefix(4))
                VStack(alignment: .leading, spacing: 3) {
                    Text(HermosilloDate.label(selectedKey)).bold()
                    chartLine("Average", values: Temperatures(low: baseline?.low?.average, mean: baseline?.mean?.average, high: baseline?.high?.average))
                    if let actual = store.year[year + "-" + selectedKey] { chartLine("This year", values: actual) }
                    if let recent = model(for: selectedKey), store.yearThrough != year + "-" + selectedKey {
                        chartLine("Recent model / forecast", values: recent)
                    }
                }.font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onChange(of: month) { _, _ in selectedKey = nil }
        .accessibilityLabel("Temperature chart for \(month == 0 ? "the full year" : HermosilloDate.monthNames[month - 1])")
    }

    private func chartLine(_ title: String, values: Temperatures) -> some View {
        Text("\(title): low \(TemperatureDisplay.value(values.low, fahrenheit: fahrenheit)), mean \(TemperatureDisplay.value(values.mean, fahrenheit: fahrenheit)), high \(TemperatureDisplay.value(values.high, fahrenheit: fahrenheit))")
    }
}
