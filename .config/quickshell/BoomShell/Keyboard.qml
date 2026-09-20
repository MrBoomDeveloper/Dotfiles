import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // Two-letter language code for the active layout, e.g. "EN", "RU"
    property string layoutCode: "EN"

    // Whether caps lock is currently active
    property bool capsLock: false

    // Whether num lock is currently active
    property bool numLock: false

    // Skip change notifications until the first poll has completed
    property bool _initialized: false

    // Emitted on state changes (used to drive an on-screen OSD instead of
    // spawning notify-send toasts).
    signal layoutChanged(string code)
    signal capsChanged(bool on)
    signal numChanged(bool on)

    Process {
        id: proc

        stdout: StdioCollector {
            id: out
        }

        onExited: code => {
            if (code !== 0)
                return

            try {
                const data = JSON.parse(out.text)
                const keyboards = data.keyboards || []
                const kb = keyboards.find(k => k.main) || keyboards[0]
                if (!kb)
                    return

                const layouts = (kb.layout || "").split(",")
                const idx = kb.active_layout_index || 0
                const raw = layouts[idx] || ""

                const newLayout = root.toLanguage(raw)
                const newCaps = kb.capsLock === true
                const newNum = kb.numLock === true

                if (root._initialized) {
                    if (newLayout !== root.layoutCode)
                        root.layoutChanged(newLayout)
                    if (newCaps !== root.capsLock)
                        root.capsChanged(newCaps)
                    if (newNum !== root.numLock)
                        root.numChanged(newNum)
                } else {
                    root._initialized = true
                }

                root.layoutCode = newLayout
                root.capsLock = newCaps
                root.numLock = newNum
            } catch (e) {
                // ignore malformed output
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            if (!proc.running)
                proc.exec(["hyprctl", "devices", "-j"])
        }
    }

    Component.onCompleted: proc.exec(["hyprctl", "devices", "-j"])

    function toLanguage(code) {
        const map = {
            "us": "EN", "gb": "EN", "ca": "EN", "au": "EN", "nz": "EN", "ie": "EN",
            "ru": "RU", "ua": "UA", "by": "BY",
            "de": "DE", "fr": "FR", "es": "ES", "it": "IT", "pt": "PT", "br": "BR",
            "nl": "NL", "pl": "PL", "tr": "TR", "se": "SV", "no": "NO", "dk": "DA",
            "fi": "FI", "jp": "JA", "cn": "ZH", "kr": "KO", "il": "HE", "gr": "EL",
            "cz": "CS", "sk": "SK", "hu": "HU", "ro": "RO", "bg": "BG",
            "lt": "LT", "lv": "LV", "ee": "ET", "kz": "KK", "ge": "KA", "am": "HY"
        }
        const key = String(code).toLowerCase()
        return map[key] || key.toUpperCase()
    }
}
