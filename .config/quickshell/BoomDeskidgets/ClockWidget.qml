import QtQuick
import QtQuick.Layouts

// ── BoomShell-styled clock card ──
// Right-click toggles edit mode: drag the body to move, drag the corner handle
// to resize. Position and size are persisted by shell.qml.
Item {
    id: clockRoot

    required property var currentTime

    property bool editMode: false
    property real surfaceOpacity: 0.92
    property real uiScale: 1.0

    signal moved(real x, real y)
    signal resized(real scale)

    M3Theme { id: theme }

    readonly property real pad: 24 * uiScale

    width: 264 * uiScale
    height: content.implicitHeight + pad * 2

    // ── Surface ──
    Rectangle {
        anchors.fill: parent
        radius: theme.radiusPanel
        color: Qt.rgba(0, 0, 0, clockRoot.surfaceOpacity)
        border.width: clockRoot.editMode ? 2 : 1
        border.color: clockRoot.editMode ? theme.primary : theme.outlineVariant

        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

        // State layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: theme.surfaceText
            opacity: clockRoot.editMode
                ? theme.stateEdit
                : (interaction.hovered ? theme.stateHover : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: clockRoot.pad
        spacing: 2 * clockRoot.uiScale

        // ── Weekday ──
        Text {
            Layout.fillWidth: true
            text: {
                const days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY",
                              "THURSDAY", "FRIDAY", "SATURDAY"]
                return days[clockRoot.currentTime.getDay()]
            }
            font.family: theme.fontFamily
            font.pixelSize: theme.labelMedium * clockRoot.uiScale
            font.weight: Font.Medium
            color: theme.primary
        }

        // ── Time ──
        Text {
            Layout.fillWidth: true
            text: {
                const h = clockRoot.currentTime.getHours()
                const m = clockRoot.currentTime.getMinutes()
                return String(h).padStart(2, "0") + ":" + String(m).padStart(2, "0")
            }
            font.family: theme.fontFamily
            font.pixelSize: theme.displayMedium * clockRoot.uiScale
            font.weight: Font.Light
            color: theme.surfaceText
        }

        // ── Date ──
        Text {
            Layout.fillWidth: true
            text: {
                const days = ["Sunday", "Monday", "Tuesday", "Wednesday",
                              "Thursday", "Friday", "Saturday"]
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                const d = clockRoot.currentTime
                return days[d.getDay()] + ", " + months[d.getMonth()] + " " + d.getDate()
            }
            font.family: theme.fontFamily
            font.pixelSize: theme.bodyMedium * clockRoot.uiScale
            color: theme.surfaceVariantText
        }
    }

    WidgetInteraction {
        id: interaction
        anchors.fill: parent
        target: clockRoot
        editMode: clockRoot.editMode
        uiScale: clockRoot.uiScale
        onEditToggled: clockRoot.editMode = !clockRoot.editMode
        onMoved: (x, y) => clockRoot.moved(x, y)
        onResized: scale => clockRoot.resized(scale)
    }
}
