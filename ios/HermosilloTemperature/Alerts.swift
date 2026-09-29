import SwiftUI
import UserNotifications
import BackgroundTasks
import UIKit

final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()
    static func install() { UNUserNotificationCenter.current().delegate = shared }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

@MainActor
enum WeatherAlerts {
    static let taskIdentifier = "com.hadalulu.HermosilloTemperature.refresh"
    static let defaults = UserDefaults.standard
    static var enabled: Bool { defaults.bool(forKey: "weatherAlertsEnabled") }
    private static var checking = false

    static func schedule() {
        guard enabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date().addingTimeInterval(3_600)
        do {
            try BGTaskScheduler.shared.submit(request)
            defaults.removeObject(forKey: "alertScheduleError")
        } catch {
            defaults.set("Background refresh unavailable. Checks still run when you open or refresh the app.", forKey: "alertScheduleError")
        }
    }

    static func disable() {
        defaults.set(false, forKey: "weatherAlertsEnabled")
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    static func enable() async -> Bool {
        do {
            let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            defaults.set(allowed, forKey: "weatherAlertsEnabled")
            if allowed { schedule() }
            return allowed
        } catch {
            defaults.set("Could not request notification permission: \(error.localizedDescription)", forKey: "alertCheckStatus")
            return false
        }
    }

    static func backgroundCheck() async {
        guard enabled else { return }
        defer { schedule() }
        do {
            let snapshot = try await WeatherAPI.forecast()
            guard !Task.isCancelled else { return }
            await check(snapshot: snapshot, normals: WeatherAPI.cachedHistorical())
        } catch {
            defaults.set("Forecast check failed. Will retry on the next refresh.", forKey: "alertCheckStatus")
        }
    }

    static func check(snapshot: ForecastSnapshot, normals: [String: HistoricalDay]) async {
        guard enabled, !checking, !Task.isCancelled else { return }
        checking = true
        defer { checking = false; schedule() }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard enabled, settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            defaults.set("Notifications are blocked. Enable them in iPhone Settings.", forKey: "alertCheckStatus")
            return
        }
        let now = Date()
        let findings = AlertRules.findings(snapshot: snapshot, normals: normals, now: now,
                                           fahrenheit: defaults.bool(forKey: "usesFahrenheit"))
        let today = HermosilloDate.iso(now)
        var sent = defaults.dictionary(forKey: "sentWeatherFindings") as? [String: String] ?? [:]
        sent = sent.filter { $0.value >= today }
        let fresh = findings.filter { sent[$0.key] == nil }
        guard enabled, !Task.isCancelled else { return }
        if !fresh.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = "Hermosillo weather alert"
            content.body = fresh.prefix(4).map(\.message).joined(separator: "\n")
                + (fresh.count > 4 ? "\n+\(fresh.count - 4) more. Open Alerts for all details." : "")
            content.sound = .default
            do {
                try await UNUserNotificationCenter.current().add(UNNotificationRequest(
                    identifier: "weather-\(UUID().uuidString)", content: content, trigger: nil))
                for finding in fresh { sent[finding.key] = finding.date }
            } catch {
                defaults.set("Could not deliver alert. Will retry: \(error.localizedDescription)", forKey: "alertCheckStatus")
                return
            }
        }
        defaults.set(sent, forKey: "sentWeatherFindings")
        defaults.set(findings.map(\.message), forKey: "weatherFindingMessages")
        defaults.set(now.timeIntervalSince1970, forKey: "alertLastCheck")
        var status = findings.isEmpty ? "No alert conditions found." : "\(findings.count) alert conditions. \(fresh.count) new; repeats suppressed."
        if normals.isEmpty { status += " Temperature comparison unavailable: open Today to load historical data." }
        if snapshot.rain.isEmpty { status += " Rain probability unavailable." }
        defaults.set(status, forKey: "alertCheckStatus")
    }
}

struct AlertsView: View {
    @EnvironmentObject private var weather: WeatherStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("weatherAlertsEnabled") private var enabled = false
    @AppStorage("alertLastCheck") private var lastCheck = 0.0
    @AppStorage("alertCheckStatus") private var status = "No checks yet."
    @AppStorage("alertScheduleError") private var scheduleError = ""
    @State private var permissionBlocked = false
    @State private var busy = false
    @State private var messages: [String] = []

    var body: some View {
        Form {
            Section {
                Toggle("Weather notifications", isOn: Binding(get: { enabled }, set: { value in
                    if !value { WeatherAlerts.disable(); enabled = false; return }
                    busy = true
                    Task {
                        enabled = await WeatherAlerts.enable()
                        await updatePermission()
                        if enabled { await weather.load(); reloadMessages() }
                        busy = false
                    }
                }))
                .disabled(busy)
                if permissionBlocked {
                    Button("Open notification settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                }
            } footer: {
                Text("Alerts are checked on this iPhone. iOS chooses when background refresh runs; timing is not guaranteed. Allow Background App Refresh in Settings and open the app regularly. Force-quitting the app prevents background checks until reopened.")
            }
            Section("Starting rules") {
                Label("Rain probability > 50% within the next 48 hours", systemImage: "cloud.rain")
                Label("Any forecast low, mean, or high below the 10th or above the 90th historical percentile for that calendar date", systemImage: "thermometer.medium")
                Text("Temperature checks cover today and the next seven days, using the 1991–2020 baseline. Values equal to the boundaries do not trigger alerts. The same date, metric, and direction alert is sent only once.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Latest check") {
                if lastCheck > 0 { Text(Date(timeIntervalSince1970: lastCheck), format: .dateTime.month().day().hour().minute()) }
                Text(status)
                if !scheduleError.isEmpty { Text(scheduleError).foregroundStyle(.secondary) }
                Button(busy || weather.isLoading ? "Checking…" : "Check now") {
                    busy = true
                    Task { await weather.load(); reloadMessages(); busy = false }
                }.disabled(!enabled || busy || weather.isLoading)
                if let error = weather.errorMessage { Text(error).foregroundStyle(.secondary) }
            }
            if enabled && !messages.isEmpty {
                Section("Conditions found at last check") {
                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in Text(message) }
                }
            }
        }
        .navigationTitle("Weather alerts")
        .task { await updatePermission(); reloadMessages() }
        .onChange(of: lastCheck) { _, _ in reloadMessages() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await updatePermission(); reloadMessages() } }
        }
    }
    private func reloadMessages() { messages = UserDefaults.standard.stringArray(forKey: "weatherFindingMessages") ?? [] }
    private func updatePermission() async {
        permissionBlocked = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
