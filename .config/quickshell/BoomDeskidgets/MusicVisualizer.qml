import QtQuick
import Quickshell
import Quickshell.Io

// ── Cava-style music visualizer ──
// Full-width backdrop for the bottom half of the screen. Not draggable and not
// resizable: it always sits under every other widget and just mirrors what cava
// hears. Bars are solid, unrounded rectangles with a two-tone cava gradient.
Item {
    id: visualizerRoot

    M3Theme { id: theme }

    readonly property int barCount: 100
    readonly property real barGap: 3

    // Normalized 0..1 bar heights, one entry per cava bar
    property var values: new Array(barCount).fill(0)

    // True only while something is actually audible — otherwise the bars are
    // hidden completely instead of sitting there as a flat line.
    property bool audible: false

    // False while the desktop panel is hidden, so cava stops burning CPU
    property bool active: true

    Process {
        id: cavaProc
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: visualizerRoot.visible && visualizerRoot.active

        // One frame per line: "v0;v1;…;vN"
        stdout: SplitParser {
            onRead: data => visualizerRoot.updateFrame(data)
        }

        // cava only writes here on failure — surface it instead of failing silently
        stderr: SplitParser {
            onRead: data => console.log("cava stderr:", data)
        }
    }

    // cava can die (PulseAudio hiccup, sink switch) — bring it back while visible
    Timer {
        interval: 3000
        repeat: true
        running: visualizerRoot.visible && visualizerRoot.active
        onTriggered: {
            if (!cavaProc.running)
                cavaProc.running = true
        }
    }

    // Holds the bars on screen through short gaps (quiet passages, beat breaks)
    Timer {
        id: silenceTimer
        interval: 1200
        repeat: false
        onTriggered: visualizerRoot.audible = false
    }

    function updateFrame(line) {
        const parts = line.split(";")
        const next = new Array(visualizerRoot.barCount)
        let peak = 0

        for (let i = 0; i < visualizerRoot.barCount; i++) {
            const raw = parseFloat(parts[i])
            const value = isNaN(raw) ? 0 : Math.max(0, Math.min(1, raw / 1000))
            next[i] = value
            if (value > peak)
                peak = value
        }

        visualizerRoot.values = next

        // Silent stream (nothing playing, muted or no sink) → hide the bars
        if (peak > 0.02) {
            visualizerRoot.audible = true
            silenceTimer.restart()
        }
    }

    Row {
        anchors.fill: parent
        spacing: visualizerRoot.barGap
        opacity: visualizerRoot.audible ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250 } }

        Repeater {
            model: visualizerRoot.barCount

            delegate: Item {
                id: bar
                required property int index

                width: (visualizerRoot.width
                        - visualizerRoot.barGap * (visualizerRoot.barCount - 1))
                       / visualizerRoot.barCount
                height: visualizerRoot.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: bar.width
                    height: (visualizerRoot.values[bar.index] || 0) * bar.height

                    // Solid two-tone gradient: no rounding, no transparency
                    gradient: Gradient {
                        GradientStop { position: 1.0; color: theme.primary }
                        GradientStop { position: 0.0; color: theme.primaryContainer }
                    }

                    Behavior on height {
                        NumberAnimation { duration: 70; easing.type: Easing.Linear }
                    }
                }
            }
        }
    }
}
