import QtQuick
import Quickshell.Io

Item {
    id: root

    // Brightness percentage 0-100
    property real value: 100

    function setValue(v: real) {
        const pct = Math.max(0, Math.min(100, Math.round(v)))
        root.value = pct
        setProc.exec(["brightnessctl", "set", pct + "%"])
    }

    function increase(amount: real) {
        root.setValue(root.value + (amount || 5))
    }

    function decrease(amount: real) {
        root.setValue(root.value - (amount || 5))
    }

    Process {
        id: getProc

        stdout: StdioCollector {
            id: out
        }

        onExited: code => {
            if (code !== 0)
                return
            // e.g. "intel_backlight,backlight,255,25%,1023"
            const match = out.text.match(/(\d+)%/)
            if (match)
                root.value = parseInt(match[1], 10)
        }
    }

    Process {
        id: setProc
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            if (!getProc.running)
                getProc.exec(["brightnessctl", "-m", "get"])
        }
    }

    Component.onCompleted: getProc.exec(["brightnessctl", "-m", "get"])
}
