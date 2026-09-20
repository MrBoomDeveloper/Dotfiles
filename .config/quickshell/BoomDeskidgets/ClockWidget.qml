import QtQuick
import QtQuick.Layouts

Item {
    id: clockRoot

    required property var currentTime

    width: 280
    height: clockColumn.implicitHeight + 48

    // ── M3 Surface card ──
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
    }

    Column {
        id: clockColumn
        anchors.centerIn: parent
        spacing: 2

        // ── Time ──
        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const h = clockRoot.currentTime.getHours()
                const m = clockRoot.currentTime.getMinutes()
                return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0")
            }
            font.family: "Google Sans"
            font.pixelSize: 72
            font.weight: Font.Light
            color: "white"
            lineHeight: 1.0
        }

        // ── Date line ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                const d = clockRoot.currentTime
                return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
            }
            font.family: "Google Sans"
            font.pixelSize: 16
            font.weight: Font.Normal
            color: Qt.rgba(1, 1, 1, 0.7)
        }
    }
}
