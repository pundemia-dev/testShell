pragma Singleton

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
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

    // Location string that resolved `loc`; lets us skip geocode/IP lookup on
    // subsequent launches when the configured location is unchanged.
    property string _resolvedKey: ""

    function formatTemp(t: var): string {
        if (t === undefined || t === null)
            return "--°";
        const f = Config.dashboard.useFahrenheit;
        return `${Math.round(f ? t * 9 / 5 + 32 : t)}°${f ? "F" : "C"}`;
    }

    // Fetch via `curl -4` rather than Qt's XMLHttpRequest: open-meteo's
    // geocoder advertises a real IPv6 address, and on an IPv4-only host Qt
    // stalls ~40s on the IPv6 connect before falling back. curl with -4 forces
    // IPv4 and never hits that stall. --max-time caps a dead request at 10s.
    function _get(url: string, cb: var): void {
        fetchProc.createObject(root, { _url: url, _cb: cb });
    }

    Component {
        id: fetchProc

        Process {
            id: proc

            required property string _url
            required property var _cb

            command: ["curl", "-4", "-fsS", "--max-time", "10", _url]
            running: true

            stdout: StdioCollector {
                // Read on stream finish (fires when stdout closes on exit) so the
                // body is guaranteed collected. On an HTTP error `curl -fsS`
                // writes nothing, so parse simply no-ops.
                onStreamFinished: {
                    if (text && text.trim().length) {
                        try {
                            proc._cb(JSON.parse(text));
                        } catch (e) {
                            console.warn("[Weather] parse:", e, proc._url);
                        }
                    }
                    proc.destroy();
                }
            }

            onExited: code => {
                if (code !== 0)
                    console.warn("[Weather] curl exit", code, proc._url);
            }
        }
    }

    function reload(): void {
        const cfg = Config.dashboard.weatherLocation;
        // Reuse the previously resolved coordinates when the configured
        // location hasn't changed — a city name geocodes to the same lat/lon
        // every time, so this drops the launch cost from 2 requests to 1.
        if (root._resolvedKey === cfg && root.loc && root.loc.indexOf(",") !== -1) {
            _fetch();
            return;
        }
        if (cfg && cfg.indexOf(",") !== -1 && !isNaN(parseFloat(cfg.split(",")[0]))) {
            root._resolvedKey = cfg;
            loc = cfg;
        } else if (cfg) {
            _geocodeCity(cfg);
        } else {
            _get("https://ipinfo.io/json", r => {
                if (r.loc) {
                    city = r.city ?? "";
                    root._resolvedKey = cfg;
                    loc = r.loc;
                }
            });
        }
    }

    // open-meteo's geocoder only matches a bare place name — "Russia Ufa"
    // returns nothing. Try the whole string first, then each comma/space token
    // in order, preferring a populated place (feature_code PPL*) so a bare
    // country token like "Russia" doesn't win over the actual city.
    function _geocodeCity(name: string): void {
        const queries = [name];
        for (const tok of name.split(/[,\s]+/).filter(t => t.length > 1))
            if (queries.indexOf(tok) === -1)
                queries.push(tok);
        _geocodeTry(name, queries, 0, null);
    }

    function _geocodeTry(key: string, queries: var, i: int, fallback: var): void {
        if (i >= queries.length) {
            if (fallback) {
                city = fallback.name;
                root._resolvedKey = key;
                loc = `${fallback.latitude},${fallback.longitude}`;
            } else {
                console.warn("[Weather] could not geocode", key);
            }
            return;
        }
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(queries[i])}&count=1&language=en&format=json`;
        _get(url, r => {
            const hit = r.results && r.results.length > 0 ? r.results[0] : null;
            if (hit && String(hit.feature_code ?? "").startsWith("PPL")) {
                city = hit.name;
                root._resolvedKey = key;
                loc = `${hit.latitude},${hit.longitude}`;
            } else {
                _geocodeTry(key, queries, i + 1, fallback ?? hit);
            }
        });
    }

    // Set while restoring from cache so seeding `loc` doesn't kick off a fetch
    // that would duplicate the one reload() issues right after.
    property bool _suppressFetch: false
    onLocChanged: if (!_suppressFetch) _fetch()

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
            _persist();
        });
    }

    // Snapshot the resolved location + last weather so the next launch shows
    // data instantly (before the network refresh lands) and skips re-resolving
    // the coordinates.
    function _persist(): void {
        cacheFile.setText(JSON.stringify({
            key: root._resolvedKey,
            loc: root.loc,
            city: root.city,
            cc: root.cc,
            forecast: root.forecast,
            hourly: root.hourly,
            sunrise: root.sunrise,
            sunset: root.sunset
        }));
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

    // Load the persisted snapshot first (instant UI), then refresh from network.
    FileView {
        id: cacheFile

        path: `${Paths.cache}/weather.json`
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root._suppressFetch = true;
                root._resolvedKey = d.key ?? "";
                if (d.loc) root.loc = d.loc;
                root._suppressFetch = false;
                if (d.city) root.city = d.city;
                if (d.cc) root.cc = d.cc;
                if (d.forecast) root.forecast = d.forecast;
                if (d.hourly) root.hourly = d.hourly;
                if (d.sunrise) root.sunrise = d.sunrise;
                if (d.sunset) root.sunset = d.sunset;
            } catch (e) {
                console.warn("[Weather] cache parse:", e);
            }
            root.reload();
        }
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("[Weather] cache load:", err);
            root.reload();
        }
    }

    Connections {
        target: Config.dashboard
        function onWeatherLocationChanged(): void {
            root.loc = "";
            root._resolvedKey = "";
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
