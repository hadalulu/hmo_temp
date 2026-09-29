import SwiftUI
import BackgroundTasks

@main
struct HermosilloTemperatureApp: App {
    @StateObject private var weather = WeatherStore()
    @AppStorage("usesFahrenheit") private var fahrenheit = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        NotificationPresenter.install()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { TodayView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Today", systemImage: "sun.max.fill") }
                NavigationStack { YearView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Year", systemImage: "chart.xyaxis.line") }
                NavigationStack { CalendarView(fahrenheit: $fahrenheit) }
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                NavigationStack { AlertsView() }
                    .tabItem { Label("Alerts", systemImage: "bell.fill") }
            }
            .environmentObject(weather)
            .tint(Color(red: 0.72, green: 0.36, blue: 0.22))
            .task { await weather.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { WeatherAlerts.schedule() }
                guard phase == .active,
                      weather.updatedAt.map({ Date().timeIntervalSince($0) > 3_600 || HermosilloDate.iso($0) != HermosilloDate.iso() }) == true else { return }
                Task { await weather.load() }
            }
        }
        .backgroundTask(.appRefresh(WeatherAlerts.taskIdentifier)) {
            await WeatherAlerts.backgroundCheck()
        }
    }
}
