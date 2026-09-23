# Hermosillo Temperature Atlas

A static, responsive dashboard for Hermosillo, Sonora. Open `index.html` directly in a browser or host the repository on any static site host. No build, API key, or dependencies are required.

## What it shows

- Historical calendar-day high, low, and mean temperatures, averaged across 1991–2020 from Open-Meteo's historical reanalysis archive.
- Today's daily forecast high, low, and mean, compared with the historical mean for the date.
- Seven-day forecast summary, daily forecast values alongside historical averages in a filterable table, and an interactive annual chart.
- Celsius/Fahrenheit switch. All dates follow `America/Hermosillo`; Feb 29 averages only leap years.

On load, the page fetches the 30-year historical daily series and the current eight-day forecast from Open-Meteo. It computes the daily climatology in the browser and caches it in `localStorage` for seven days. Live forecasts are fetched on each page load. Because these are model/reanalysis values, today's numbers are forecast daily values rather than finalized station observations.

Data: [Open-Meteo Historical Weather API](https://open-meteo.com/en/docs/historical-weather-api) and [Forecast API](https://open-meteo.com/en/docs). Network access to both endpoints is needed to populate the dashboard.
