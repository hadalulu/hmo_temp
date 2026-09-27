import SwiftUI

@main
struct HermosilloTemperatureApp: App {
    @StateObject private var weather = WeatherStore()
    @AppStorage("usesFahrenheit") private var fahrenheit = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { TodayView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                NavigationStack { YearView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Year", systemImage: "chart.xyaxis.line") }
                NavigationStack { CalendarView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Calendar", systemImage: "calendar") }
            }
            .environmentObject(weather)
            .tint(Color(red: 0.72, green: 0.36, blue: 0.22))
            .task { await weather.load() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, weather.updatedAt.map({ HermosilloDate.iso($0) != HermosilloDate.iso() }) == true else { return }
                Task { await weather.load() }
            }
        }
    }
}
