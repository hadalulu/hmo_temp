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
- **Calendar**: historical averages for every day, archived current-year values, recent model values labeled MODEL, and available forecasts, starting at today.

Dates use `America/Hermosillo`. The 1991–2020 baseline is derived from Open-Meteo's Historical Weather API; February 29 uses leap years only. The current-year archive stops seven days before today to allow for publication lag. The forecast API supplies 14 prior model days to bridge that lag and eight days including today. Recent model values and forecasts are not finalized station observations. Temperatures can be switched between Celsius and Fahrenheit.

The web page in the repository root continues to work independently. The iPhone app has not been submitted to the App Store.
