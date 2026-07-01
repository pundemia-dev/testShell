pragma Singleton

import qs.config
import qs.utils
import Quickshell
import QtQuick

// Weather via open-meteo (no API key). Location comes from
// Config.dashboard.weatherLocation ("" = auto by IP, "City" name, or "lat,lon").
// Port of caelestia Weather using plain XMLHttpRequest (pShell has no Requests
// helper). Icons resolve to tabler glyphs via Icons.getWeatherIconWmo.
Singleton {
    id: root

    property string city: ""
    property string loc: "" // "lat,lon"
    property var cc: null
    property var forecast: []
    property var hourly: []

    readonly property string icon: cc ? Icons.getWeatherIconWmo(cc.weatherCode) : ""
    readonly property string description: cc?.desc ?? qsTr("No weather")
    readonly property string temp: formatTemp(cc?.tempC)
    readonly property string feelsLike: formatTemp(cc?.feelsLikeC)
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    property string sunrise: "--:--"
    property string sunset: "--:--"

    function formatTemp(t: var): string {
        if (t === undefined || t === null)
            return "--°";
        const f = Config.dashboard.useFahrenheit;
        return `${Math.round(f ? t * 9 / 5 + 32 : t)}°${f ? "F" : "C"}`;
    }

    function _get(url: string, cb: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                try {
                    cb(JSON.parse(xhr.responseText));
                } catch (e) {
                    console.warn("[Weather] parse:", e);
                }
            } else {
                console.warn("[Weather] http", xhr.status, url);
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function reload(): void {
        const cfg = Config.dashboard.weatherLocation;
        if (cfg && cfg.indexOf(",") !== -1 && !isNaN(parseFloat(cfg.split(",")[0]))) {
            loc = cfg;
        } else if (cfg) {
            _geocodeCity(cfg);
        } else {
            _get("https://ipinfo.io/json", r => {
                if (r.loc) {
                    city = r.city ?? "";
                    loc = r.loc;
                }
            });
        }
    }

    function _geocodeCity(name: string): void {
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(name)}&count=1&language=en&format=json`;
        _get(url, r => {
            if (r.results && r.results.length > 0) {
                city = r.results[0].name;
                loc = `${r.results[0].latitude},${r.results[0].longitude}`;
            }
        });
    }

    onLocChanged: _fetch()

    function _fetch(): void {
        if (!loc || loc.indexOf(",") === -1)
            return;
        const [lat, lon] = loc.split(",").map(s => s.trim());
        const url = "https://api.open-meteo.com/v1/forecast"
            + `?latitude=${lat}&longitude=${lon}`
            + "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset"
            + "&hourly=weather_code,temperature_2m,precipitation_probability"
            + "&timezone=auto&forecast_days=7";
        _get(url, j => {
            if (!j.current || !j.daily)
                return;
            cc = {
                weatherCode: j.current.weather_code,
                desc: describe(j.current.weather_code),
                tempC: j.current.temperature_2m,
                feelsLikeC: j.current.apparent_temperature,
                humidity: j.current.relative_humidity_2m,
                windSpeed: j.current.wind_speed_10m,
                isDay: j.current.is_day
            };

            const fc = [];
            for (let i = 0; i < j.daily.time.length; i++)
                fc.push({
                    date: j.daily.time[i],
                    max: Math.round(j.daily.temperature_2m_max[i]),
                    min: Math.round(j.daily.temperature_2m_min[i]),
                    code: j.daily.weather_code[i]
                });
            forecast = fc;

            const fmtHM = t => Qt.formatDateTime(new Date(t), Config.services?.useTwelveHourClock ?? false ? "h:mm AP" : "h:mm");
            if (j.daily.sunrise?.[0]) sunrise = fmtHM(j.daily.sunrise[0]);
            if (j.daily.sunset?.[0]) sunset = fmtHM(j.daily.sunset[0]);

            const hl = [];
            const now = new Date();
            for (let i = 0; i < j.hourly.time.length; i++) {
                const tm = new Date(j.hourly.time[i]);
                if (tm < now)
                    continue;
                hl.push({
                    hour: tm.getHours(),
                    tempC: Math.round(j.hourly.temperature_2m[i]),
                    code: j.hourly.weather_code[i],
                    precip: j.hourly.precipitation_probability[i]
                });
            }
            hourly = hl.slice(0, 24);
        });
    }

    function describe(code: var): string {
        const c = {
            "0": qsTr("Clear"),
            "1": qsTr("Mainly clear"),
            "2": qsTr("Partly cloudy"),
            "3": qsTr("Overcast"),
            "45": qsTr("Fog"),
            "48": qsTr("Fog"),
            "51": qsTr("Drizzle"),
            "53": qsTr("Drizzle"),
            "55": qsTr("Drizzle"),
            "56": qsTr("Freezing drizzle"),
            "57": qsTr("Freezing drizzle"),
            "61": qsTr("Light rain"),
            "63": qsTr("Rain"),
            "65": qsTr("Heavy rain"),
            "66": qsTr("Freezing rain"),
            "67": qsTr("Freezing rain"),
            "71": qsTr("Light snow"),
            "73": qsTr("Snow"),
            "75": qsTr("Heavy snow"),
            "77": qsTr("Snow grains"),
            "80": qsTr("Rain showers"),
            "81": qsTr("Rain showers"),
            "82": qsTr("Heavy showers"),
            "85": qsTr("Snow showers"),
            "86": qsTr("Snow showers"),
            "95": qsTr("Thunderstorm"),
            "96": qsTr("Thunderstorm"),
            "99": qsTr("Thunderstorm")
        };
        return c[String(code)] ?? qsTr("Unknown");
    }

    Component.onCompleted: reload()

    Connections {
        target: Config.dashboard
        function onWeatherLocationChanged(): void {
            root.loc = "";
            root.reload();
        }
    }

    // Refresh hourly.
    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root._fetch()
    }
}
