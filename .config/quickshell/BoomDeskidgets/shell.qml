import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    // ── Weather data (shared across all screens) ──
    property string weatherTemp: ""
    property string weatherCondition: ""
    property string weatherIcon: ""
    property string weatherCity: "Detecting..."
    property real weatherHumidity: 0
    property real weatherWind: 0
    property bool weatherLoaded: false

    // ── Weather location ──
    property real weatherLat: 55.75
    property real weatherLon: 37.62
    property bool weatherLocationReady: false

    // ── Current time (shared across all screens) ──
    property var now: new Date()

    // ── Workspace window count per monitor name ──
    // e.g. { "eDP-1": 0, "HDMI-A-1": 3 }
    property var monitorWindowCounts: ({})

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    // ── Detect workspace changes via Hyprland events ──
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const name = event.name
            if (name === "workspace" || name === "closewindow"
                || name === "openwindow" || name === "movewindow"
                || name === "activespecial" || name === "focusedmon"
                || name === "createworkspace" || name === "destroyworkspace") {
                wsMonitorsProc.running = true
            }
        }
    }

    // ── Poll hyprctl for window counts on all monitors ──
    // Two-step: first get monitors (name → active workspace id),
    // then get workspaces (id → windows count).
    property var _monitorActiveWs: ({})  // name → active workspace id

    Process {
        id: wsMonitorsProc
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const monitors = JSON.parse(this.text)
                    const activeWs = {}
                    for (let i = 0; i < monitors.length; i++) {
                        const m = monitors[i]
                        activeWs[m.name] = m.activeWorkspace ? m.activeWorkspace.id : 0
                    }
                    root._monitorActiveWs = activeWs
                    wsWorkspacesProc.running = true
                } catch (e) {
                    console.log("wsMonitors error:", e)
                }
            }
        }
    }

    Process {
        id: wsWorkspacesProc
        command: ["hyprctl", "workspaces", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const workspaces = JSON.parse(this.text)
                    const wsWindows = {}
                    for (let i = 0; i < workspaces.length; i++) {
                        const ws = workspaces[i]
                        if (ws.id > 0)
                            wsWindows[ws.id] = ws.windows
                    }
                    const counts = {}
                    const activeWsMap = root._monitorActiveWs
                    for (const name in activeWsMap) {
                        counts[name] = wsWindows[activeWsMap[name]] || 0
                    }
                    root.monitorWindowCounts = counts
                } catch (e) {
                    console.log("wsWorkspaces error:", e)
                }
            }
        }
    }

    // ── Geolocation → weather location ──
    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "5", "https://ipapi.co/json/"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const geo = JSON.parse(this.text)
                    root.weatherCity = geo.city || "Unknown"
                    root.weatherLat = geo.latitude || 55.75
                    root.weatherLon = geo.longitude || 37.62
                } catch (e) {
                    root.weatherCity = "Moscow"
                    root.weatherLat = 55.75
                    root.weatherLon = 37.62
                }
                root.weatherLocationReady = true
                weatherFetchProc.running = true
            }
        }
    }

    // ── Fetch weather from Open-Meteo ──
    Process {
        id: weatherFetchProc
        property real lat: root.weatherLat
        property real lon: root.weatherLon
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code" +
            "&temperature_unit=celsius&wind_speed_unit=kmh&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text)
                    const c = data.current
                    root.weatherTemp = Math.round(c.temperature_2m) + "°"
                    root.weatherHumidity = c.relative_humidity_2m
                    root.weatherWind = c.wind_speed_10m
                    root.weatherCondition = weatherCodeToText(c.weather_code)
                    root.weatherIcon = weatherCodeToIcon(c.weather_code)
                    root.weatherLoaded = true
                } catch (e) {
                    console.log("Weather parse error:", e)
                }
            }
        }
    }

    // Refresh weather every 15 minutes
    Timer {
        interval: 900000
        repeat: true
        running: root.weatherLocationReady
        onTriggered: {
            weatherFetchProc.lat = root.weatherLat
            weatherFetchProc.lon = root.weatherLon
            weatherFetchProc.running = true
        }
    }

    function setWeatherLocation(lat, lon, cityName) {
        root.weatherLat = lat
        root.weatherLon = lon
        root.weatherCity = cityName
        weatherFetchProc.lat = lat
        weatherFetchProc.lon = lon
        weatherFetchProc.running = true
    }

    function weatherCodeToText(code) {
        const map = {
            0: "Clear sky", 1: "Mainly clear", 2: "Partly cloudy", 3: "Overcast",
            45: "Fog", 48: "Rime fog",
            51: "Light drizzle", 53: "Drizzle", 55: "Dense drizzle",
            61: "Slight rain", 63: "Rain", 65: "Heavy rain",
            71: "Slight snow", 73: "Snow", 75: "Heavy snow",
            80: "Slight showers", 81: "Showers", 82: "Violent showers",
            95: "Thunderstorm", 96: "Thunderstorm w/ hail", 99: "Thunderstorm w/ heavy hail"
        }
        return map[code] || "Unknown"
    }

    function weatherCodeToIcon(code) {
        if (code === 0) return "☀️"
        if (code <= 2) return "⛅"
        if (code === 3) return "☁️"
        if (code >= 45 && code <= 48) return "🌫️"
        if (code >= 51 && code <= 57) return "🌦️"
        if (code >= 61 && code <= 67) return "🌧️"
        if (code >= 71 && code <= 77) return "❄️"
        if (code >= 80 && code <= 82) return "🌧️"
        if (code >= 95) return "⛈️"
        return "🌡️"
    }

    // ── Settings state ──
    property bool settingsOpen: false

    // ── Per-screen desktop widgets ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            id: desktopPanel

            // Layer: above wallpaper, below windows
            aboveWindows: false

            // Fullscreen overlay
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            exclusiveZone: -1
            color: "transparent"

            // ── Hide when active workspace has windows ──
            // Use hyprctl-polled data (reliable, event-driven)
            property string monitorName: {
                try {
                    const m = Hyprland.monitorFor(modelData)
                    return m ? m.name : ""
                } catch (e) {
                    return ""
                }
            }

            property int windowCount: {
                if (!monitorName) return 0
                return root.monitorWindowCounts[monitorName] || 0
            }

            visible: windowCount === 0

            // ── Clock Widget (top-left area) ──
            ClockWidget {
                id: clockWidget
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 60
                anchors.leftMargin: 60
                currentTime: root.now
            }

            // ── Weather Widget (bottom-right area) ──
            WeatherWidget {
                id: weatherWidget
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.bottomMargin: 60
                anchors.rightMargin: 60
                temperature: root.weatherTemp
                condition: root.weatherCondition
                icon: root.weatherIcon
                city: root.weatherCity
                humidity: root.weatherHumidity
                wind: root.weatherWind
                loaded: root.weatherLoaded
                onClicked: root.settingsOpen = !root.settingsOpen
            }
        }
    }

    // ── Weather Settings Popup ──
    WeatherSettings {
        open: root.settingsOpen
        onDismissed: root.settingsOpen = false
        onLocationSelected: (lat, lon, name) => root.setWeatherLocation(lat, lon, name)
    }

    // Initial fetches
    Component.onCompleted: {
        geoProc.running = true
        wsMonitorsProc.running = true
    }
}
