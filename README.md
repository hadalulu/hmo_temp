# Hermosillo Temperature Atlas

**[Open the live dashboard](https://hadalulu.github.io/hmo_temp/)**

A static, responsive dashboard for Hermosillo, Sonora. Open `index.html` directly in a browser or host the repository on any static site host. No build, API key, or dependencies are required.

## What it shows

- Historical calendar-day low, mean, and high temperatures, averaged across 1991–2020 from Open-Meteo's historical reanalysis archive. Shaded chart bands show the 10th–90th percentile of historical daily values, not forecast confidence intervals.
- Today's daily forecast low, mean, and high and individual values for each of the next seven days.
- Current-year archived temperatures plotted against the historical averages, with year-to-date average differences for low, mean, and high. The archive is requested only through seven days before today to allow for publication lag; the actual latest available date is displayed.
- Dotted recent model values bridging the archive to a low, mean, and high forecast on the annual chart, an interactive tooltip, a calendar table that starts at today's date, and a Celsius/Fahrenheit switch.

The page fetches the 30-year historical series, current-year archive, and live forecast with 14 prior days from Open-Meteo. It calculates the historical day-of-year averages and percentile ranges in the browser, caching those historical aggregates in `localStorage` for seven days. Current-year and forecast data are fetched on each load. Recent model days bridge the archive lag on the chart; they are not final observations. Feb 29 uses leap years only. Dates follow `America/Hermosillo`. Today's values are model forecasts rather than finalized station observations.

Data: [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) and [Forecast API](https://open-meteo.com/en/docs). Network access to both endpoints is needed to populate the dashboard.
