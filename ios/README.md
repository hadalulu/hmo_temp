# Hermosillo Temps for iPhone

This is a native SwiftUI companion to the [web dashboard](https://hadalulu.github.io/hmo_temp/). It uses no web views, external packages, or API keys.

## Run

1. On a Mac with Xcode 15 or newer, open `HermosilloTemperature.xcodeproj`.
2. Select the **HermosilloTemperature** scheme and an iPhone simulator running iOS 17 or newer, then press Run.
3. To install on a device, select your Apple development team in **Signing & Capabilities** and choose a unique bundle identifier if Xcode requests one.

An internet connection is required for the first load and for current weather. Historical calendar-day aggregates are cached on the device for seven days. Pull down on any screen to refresh; reopening the app on a new Hermosillo day also refreshes its data.

## Screens

- **Today**: daily low, mean, and high, the next seven days, and each forecast value's difference from the 1991–2020 average for that calendar date.
- **Year**: native Canvas time series with historical 10th–90th percentile bands, archived current-year values, dotted recent model / forecast values, a month zoom control, touch inspection, and year-to-date anomalies.
- **Alerts**: opt-in local notifications for rain probability >50% within 48 hours and forecast low, mean, or high outside that date’s historical 10th–90th percentiles. Includes Check now and the conditions found at the latest check.
- **Calendar**: historical averages for every day, archived current-year values, recent model values labeled MODEL, and available forecasts, starting at today.

Dates use `America/Hermosillo`. The 1991–2020 baseline is derived from Open-Meteo's Historical Weather API; February 29 uses leap years only. The current-year archive stops seven days before today to allow for publication lag. The forecast API supplies 14 prior model days to bridge that lag and eight days including today. Recent model values and forecasts are not finalized station observations. Temperatures can be switched between Celsius and Fahrenheit.

The web page in the repository root continues to work independently. The iPhone app has not been submitted to the App Store.

## App-only weather alerts

Install the updated app, open **Alerts**, enable **Weather notifications**, and allow notifications when iOS asks. Open Today once with internet access to cache the historical baseline. Enable Background App Refresh for the app in iPhone Settings. No server, push service, or API key is required.

Checks run on successful foreground refreshes and on background refresh opportunities granted by iOS. The app requests another opportunity no earlier than one hour later; iOS may delay or skip it, especially with Low Power Mode, Background App Refresh disabled, or infrequent use. Force-quitting stops background checks until you reopen the app. App-only alerts cannot guarantee a daily check or immediate warning.

Rain uses hourly precipitation probability for hours overlapping the next rolling 48 hours (Open-Meteo reports probability for the preceding hour). The threshold is strictly greater than 50%. Temperature checks cover all eight forecast dates, including today, and compare each daily low, mean, and high to its own calendar-date percentile range from 1991–2020. Exact percentile boundaries do not trigger alerts. Background checks use the cached baseline without downloading thirty years of data; missing rain or historical data is reported in Alerts, never interpreted as normal.

New conditions are combined into one notification. A rain alert repeats only for a different Hermosillo date; temperature alerts repeat only for a different forecast date, metric, or direction. Conditions from the latest check remain visible in Alerts. Notifications respect the device’s notification and Focus settings. Disable Weather notifications to stop future checks and alerts.

The iOS GitHub Actions workflow builds the simulator app and runs deterministic rule checks (thresholds, window boundaries, calendar dates, missing data, and units). Verify notification permission, delivery, and background behavior on your physical iPhone; a successful build cannot guarantee when iOS will run background work.
