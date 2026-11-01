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

    function applyWeatherLocation(lat, lon, cityName) {
        root.weatherLat = lat
        root.weatherLon = lon
        root.weatherCity = cityName
        root.weatherLocationReady = true
        weatherFetchProc.lat = lat
        weatherFetchProc.lon = lon
        weatherFetchProc.running = true
    }

    // Called when the user picks a city in the settings dialog — remember it.
    function setWeatherLocation(lat, lon, cityName) {
        root.savedLocation = { lat: lat, lon: lon, city: cityName }
        root.locationInitialized = true
        root.applyWeatherLocation(lat, lon, cityName)
        root.scheduleSave()
    }

    // Restored city wins over IP geolocation; only auto-detect when unset.
    function initLocation() {
        if (root.savedLocation.city) {
            root.locationInitialized = true
            root.applyWeatherLocation(
                root.savedLocation.lat, root.savedLocation.lon, root.savedLocation.city)
            return
        }
        if (root.locationInitialized)
            return
        root.locationInitialized = true
        geoProc.running = true
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

    // ── Desktop widget settings (persisted to settings.json) ──
    // "<monitor>/<widget>" → { x, y }: where each widget sits on each screen.
    property var widgetPositions: ({})
    // Card surface opacity for both widgets (0.3 … 1.0).
    property real widgetOpacity: 0.92
    // Explicitly picked city: { lat, lon, city }. Empty = auto-detect by IP.
    property var savedLocation: ({})
    property bool locationInitialized: false
    // Which widgets are on the desktop. The bare clock starts hidden.
    property var widgetVisibility: ({ clock: true, weather: true, bareClock: false, visualizer: true })
    // Per-widget size factor, changed by dragging the corner handle in edit mode.
    property var widgetSizes: ({ clock: 1.0, weather: 1.0, bareClock: 1.0 })
    // Bare clock layout: "stacked" (hours / minutes) or "inline" (HH:MM).
    property string bareClockStyle: "stacked"
    // Keep the visualizer on screen even when a window covers the desktop
    property bool visualizerAlwaysOn: false

    readonly property string settingsFile: Quickshell.shellPath("settings.json")

    FileView {
        id: settingsStore
        path: root.settingsFile
        blockLoading: true

        onLoaded: root.readSettings(settingsStore.text())
    }

    // Coalesce rapid updates (dragging, opacity slider) into a single write
    Timer {
        id: saveDebounce
        interval: 300
        onTriggered: root.writeSettings()
    }

    function scheduleSave() {
        saveDebounce.restart()
    }

    // Put every widget back into its default corner
    function resetWidgetPositions() {
        root.widgetPositions = ({})
        root.scheduleSave()
    }

    function widgetVisible(id) {
        return root.widgetVisibility[id] !== false
    }

    function setWidgetVisible(id, visible) {
        const next = Object.assign({}, root.widgetVisibility)
        next[id] = visible
        root.widgetVisibility = next
        root.scheduleSave()
    }

    function widgetScale(id) {
        const value = root.widgetSizes[id]
        return typeof value === "number" ? value : 1
    }

    function setWidgetScale(id, scale) {
        const next = Object.assign({}, root.widgetSizes)
        next[id] = Math.max(0.6, Math.min(4.0, scale))
        root.widgetSizes = next
        root.scheduleSave()
    }

    function readSettings(text) {
        try {
            const cfg = JSON.parse(text || "{}")
            if (cfg.positions && typeof cfg.positions === "object")
                root.widgetPositions = cfg.positions
            if (typeof cfg.opacity === "number")
                root.widgetOpacity = Math.max(0.3, Math.min(1, cfg.opacity))
            if (cfg.location && cfg.location.city)
                root.savedLocation = cfg.location
            if (cfg.visibility && typeof cfg.visibility === "object")
                root.widgetVisibility = Object.assign({}, root.widgetVisibility, cfg.visibility)
            if (cfg.sizes && typeof cfg.sizes === "object")
                root.widgetSizes = Object.assign({}, root.widgetSizes, cfg.sizes)
            if (typeof cfg.bareClockStyle === "string")
                root.bareClockStyle = cfg.bareClockStyle
            if (typeof cfg.visualizerAlwaysOn === "boolean")
                root.visualizerAlwaysOn = cfg.visualizerAlwaysOn
        } catch (e) {
            console.log("Settings parse error:", e)
        }
    }

    function writeSettings() {
        const cfg = {
            positions: root.widgetPositions,
            opacity: root.widgetOpacity,
            location: root.savedLocation,
            visibility: root.widgetVisibility,
            sizes: root.widgetSizes,
            bareClockStyle: root.bareClockStyle,
            visualizerAlwaysOn: root.visualizerAlwaysOn
        }
        settingsStore.setText(JSON.stringify(cfg, null, 2))
    }

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

            // Stable key for remembering widget positions on this monitor
            readonly property string monKey: monitorName || (modelData ? modelData.name : "")

            // True while the active workspace has no windows: the full widget layer shows
            readonly property bool onEmptyWorkspace: windowCount === 0

            // The visualizer can stay on screen even when a window covers the desktop
            visible: onEmptyWorkspace || root.visualizerAlwaysOn

            // ── Widget placement ──
            readonly property int widgetEdge: 56

            function widgetKey(id) {
                return monKey + "/" + id
            }

            // Restore a saved position, or fall back to the default corner.
            function placeWidget(item, id, defaultX, defaultY) {
                const saved = root.widgetPositions[widgetKey(id)]
                const maxX = Math.max(0, width - item.width)
                const maxY = Math.max(0, height - item.height)
                const x = saved ? saved.x : defaultX
                const y = saved ? saved.y : defaultY
                item.x = Math.max(0, Math.min(maxX, x))
                item.y = Math.max(0, Math.min(maxY, y))
            }

            function saveWidgetPosition(item, id) {
                const key = widgetKey(id)
                const next = Object.assign({}, root.widgetPositions)
                next[key] = { x: item.x, y: item.y }
                root.widgetPositions = next
                root.scheduleSave()
            }

            function layoutWidgets() {
                placeWidget(clockWidget, "clock", widgetEdge, widgetEdge)
                placeWidget(weatherWidget, "weather",
                    width - weatherWidget.width - widgetEdge,
                    height - weatherWidget.height - widgetEdge)
                placeWidget(bareClockWidget, "bareClock",
                    width - bareClockWidget.width - widgetEdge, widgetEdge)
            }

            // ── Music visualizer (bottom half, behind everything, never draggable) ──
            MusicVisualizer {
                id: musicVisualizer
                visible: root.widgetVisible("visualizer")
                        && (desktopPanel.onEmptyWorkspace || root.visualizerAlwaysOn)
                active: desktopPanel.visible
                x: 0
                y: desktopPanel.height / 2
                width: desktopPanel.width
                height: desktopPanel.height / 2
                z: -1
            }

            // ── Clock Widget (top-left by default) ──
            ClockWidget {
                id: clockWidget
                visible: root.widgetVisible("clock") && desktopPanel.onEmptyWorkspace
                currentTime: root.now
                surfaceOpacity: root.widgetOpacity
                uiScale: root.widgetScale("clock")
                onMoved: desktopPanel.saveWidgetPosition(clockWidget, "clock")
                onResized: scale => root.setWidgetScale("clock", scale)
            }

            // ── Weather Widget (bottom-right by default) ──
            WeatherWidget {
                id: weatherWidget
                visible: root.widgetVisible("weather") && desktopPanel.onEmptyWorkspace
                temperature: root.weatherTemp
                condition: root.weatherCondition
                icon: root.weatherIcon
                city: root.weatherCity
                humidity: root.weatherHumidity
                wind: root.weatherWind
                loaded: root.weatherLoaded
                surfaceOpacity: root.widgetOpacity
                uiScale: root.widgetScale("weather")
                onClicked: root.settingsOpen = !root.settingsOpen
                onMoved: desktopPanel.saveWidgetPosition(weatherWidget, "weather")
                onResized: scale => root.setWidgetScale("weather", scale)
                // Content grows once the forecast arrives
                onHeightChanged: desktopPanel.layoutWidgets()
            }

            // ── Bare clock (top-right by default, hidden until enabled) ──
            BareClockWidget {
                id: bareClockWidget
                visible: root.widgetVisible("bareClock") && desktopPanel.onEmptyWorkspace
                currentTime: root.now
                style: root.bareClockStyle
                uiScale: root.widgetScale("bareClock")
                onMoved: desktopPanel.saveWidgetPosition(bareClockWidget, "bareClock")
                onResized: scale => root.setWidgetScale("bareClock", scale)
            }

            // Reapply after settings arrive, or a widget was moved/resized/toggled
            Connections {
                target: root
                function onWidgetPositionsChanged() { desktopPanel.layoutWidgets() }
                function onWidgetSizesChanged() { desktopPanel.layoutWidgets() }
                function onWidgetVisibilityChanged() { desktopPanel.layoutWidgets() }
            }

            Component.onCompleted: layoutWidgets()
            onWidthChanged: layoutWidgets()
            onHeightChanged: layoutWidgets()
        }
    }

    // ── Settings screen (BoomShell-styled modal panel) ──
    WidgetSettings {
        open: root.settingsOpen
        cardOpacity: root.widgetOpacity
        currentCity: root.weatherCity
        visibility: root.widgetVisibility
        bareClockStyle: root.bareClockStyle
        visualizerAlwaysOn: root.visualizerAlwaysOn
        onDismissed: root.settingsOpen = false
        onLocationSelected: (lat, lon, name) => root.setWeatherLocation(lat, lon, name)
        onCardOpacityEdited: (value) => {
            root.widgetOpacity = value
            root.scheduleSave()
        }
        onWidgetVisibilityChanged: (id, value) => root.setWidgetVisible(id, value)
        onBareClockStylePicked: style => {
            root.bareClockStyle = style
            root.scheduleSave()
        }
        onVisualizerAlwaysOnToggled: value => {
            root.visualizerAlwaysOn = value
            root.scheduleSave()
        }
        onResetLayoutRequested: root.resetWidgetPositions()
    }

    // ── Open the settings screen from outside (desktop entry / rofi) ──
    Process {
        id: settingsFlagProc
        onExited: code => {
            if (code === 0)
                root.settingsOpen = !root.settingsOpen
        }
    }

    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (settingsFlagProc.running)
                return
            settingsFlagProc.exec(["sh", "-c",
                'if [ -f /tmp/buff_toggle_widget_settings ]; then ' +
                'rm -f /tmp/buff_toggle_widget_settings; exit 0; fi; exit 1'])
        }
    }

    // Apply a city that arrived from disk after the initial location setup
    onSavedLocationChanged: {
        const loc = root.savedLocation
        if (loc && loc.city && (loc.city !== root.weatherCity
                || loc.lat !== root.weatherLat || loc.lon !== root.weatherLon))
            root.initLocation()
    }

    // Initial fetches
    Component.onCompleted: {
        root.initLocation()
        wsMonitorsProc.running = true
    }
}
