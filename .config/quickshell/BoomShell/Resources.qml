import QtQuick
import Quickshell.Io

Column {
    id: root
    spacing: 4

    property real cpuPercent: 0
    property real ramPercent: 0
    property real storagePercent: 0

    signal cpuClicked()
    signal ramClicked()
    signal storageClicked()

    property var prevBusy: 0
    property var prevTotal: 0

    property string cmd: "awk '/^cpu /{print \"CPU \" $2+$3+$4+$7+$8+$9 \" \" $5+$6}' /proc/stat; awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print \"MEM \" t \" \" a}' /proc/meminfo; df -P / | awk 'NR==2{print \"DISK \" $3 \" \" $2}'"

    Process {
        id: proc
        stdout: StdioCollector { id: out }

        onExited: code => {
            if (code !== 0)
                return
            const lines = out.text.trim().split("\n")
            for (let i = 0; i < lines.length; i++) {
                const parts = lines[i].trim().split(/\s+/)
                if (parts[0] === "CPU" && parts.length >= 3) {
                    const busy = parseFloat(parts[1])
                    const idle = parseFloat(parts[2])
                    const total = busy + idle
                    if (root.prevTotal > 0 && total > root.prevTotal) {
                        root.cpuPercent = Math.max(0, Math.min(100,
                            (busy - root.prevBusy) / (total - root.prevTotal) * 100))
                    }
                    root.prevBusy = busy
                    root.prevTotal = total
                } else if (parts[0] === "MEM" && parts.length >= 3) {
                    const total = parseFloat(parts[1])
                    const avail = parseFloat(parts[2])
                    if (total > 0)
                        root.ramPercent = Math.max(0, Math.min(100, (total - avail) / total * 100))
                } else if (parts[0] === "DISK" && parts.length >= 3) {
                    const used = parseFloat(parts[1])
                    const total = parseFloat(parts[2])
                    if (total > 0)
                        root.storagePercent = Math.max(0, Math.min(100, used / total * 100))
                }
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: {
            if (!proc.running)
                proc.exec(["sh", "-c", root.cmd])
        }
    }

    Component.onCompleted: proc.exec(["sh", "-c", root.cmd])

    MetricRow {
        label: "CPU"
        icon: String.fromCodePoint(0xF2DB) // microchip
        value: root.cpuPercent
        onClicked: root.cpuClicked()
    }

    MetricRow {
        label: "RAM"
        icon: String.fromCodePoint(0xF538) // memory
        value: root.ramPercent
        onClicked: root.ramClicked()
    }

    MetricRow {
        label: "DSK"
        icon: String.fromCodePoint(0xF0A0) // hard drive
        value: root.storagePercent
        onClicked: root.storageClicked()
    }

    component MetricRow: Rectangle {
        id: row
        property string label: ""
        property string icon: ""
        property real value: 0
        signal clicked()

        width: 24
        height: 84
        radius: 6
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1
        color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 0.65, 0.89, 0.03)

        function barColor() {
            if (row.value >= 85) return "#f38ba8"
            if (row.value >= 60) return "#fab387"
            return '#c088db'
        }

        Column {
            anchors.centerIn: parent
            spacing: 3

            // Icon glyph
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: row.icon
                color: row.barColor()
                font.pixelSize: 12
                font.family: "Google Sans Flex"
            }

            // Real vertical (rotated) label
            Item {
                id: labelWrap
                anchors.horizontalCenter: parent.horizontalCenter
                width: labelText.height
                height: labelText.width

                Text {
                    id: labelText
                    anchors.centerIn: parent
                    text: row.label
                    rotation: 90
                    transformOrigin: Item.Center
                    color: "#cdd6f4"
                    font.pixelSize: 8
                    font.bold: true
                    font.family: "Google Sans Flex"
                }
            }

            // Vertical usage bar (fills bottom-up)
            Rectangle {
                width: 5
                height: 26
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.1)

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: parent.height * (row.value / 100)
                    radius: 3
                    color: row.barColor()
                }
            }

            // Percentage
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(row.value) + "%"
                color: row.barColor()
                font.pixelSize: 8
                font.family: "Google Sans Flex"
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
        }
    }
}
