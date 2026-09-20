import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: root

    property bool open: false
    property var anchorItem: null
    property bool selfHovered: false
    signal dismissed()

    property int year: 2026
    property int month: 0
    property bool closing: false

    visible: false
    color: "transparent"

    implicitWidth: 340
    implicitHeight: 360

    anchor.item: root.anchorItem
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var dayNames: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    readonly property var cells: {
        const first = new Date(root.year, root.month, 1)
        const offset = (first.getDay() + 6) % 7
        const daysInMonth = new Date(root.year, root.month + 1, 0).getDate()
        const now = new Date()
        const list = []
        for (let i = 0; i < offset; i++) list.push({ day: 0, today: false })
        for (let d = 1; d <= daysInMonth; d++) {
            list.push({ day: d, today: now.getFullYear() === root.year &&
                       now.getMonth() === root.month && now.getDate() === d })
        }
        return list
    }

    function prevMonth() { root.month--; if (root.month < 0) { root.month = 11; root.year-- } }
    function nextMonth() { root.month++; if (root.month > 11) { root.month = 0; root.year++ } }
    function resetToToday() {
        const now = new Date(); root.year = now.getFullYear(); root.month = now.getMonth()
    }

    onOpenChanged: {
        if (root.open) {
            dismissTimer.stop()
            root.visible = true
            root.closing = false
            closeSlideTimer.stop()
            panel.slideX = -340
            slideInTimer.restart()
        } else if (!root.closing && root.visible) {
            slideInTimer.stop()
            root.closing = true
            closeSlideTimer.restart()
        }
    }

    Timer {
        id: slideInTimer
        interval: 0
        onTriggered: panel.slideX = 0
    }

    Timer {
        id: closeSlideTimer
        interval: 0
        onTriggered: panel.slideX = -340
    }

    Timer {
        id: dismissTimer
        interval: 240
        onTriggered: {
            root.visible = false
            root.closing = false
            root.resetToToday()
            root.selfHovered = false
            root.dismissed()
        }
    }

    Component.onCompleted: { root.resetToToday(); panel.slideX = -340 }

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: root.selfHovered = hoverHandler.hovered
    }

    onClosed: {
        if (!root.closing) {
            slideInTimer.stop()
            root.closing = true
            closeSlideTimer.restart()
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.9)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

        property real slideX: 0
        transform: Translate { x: panel.slideX }

        Behavior on slideX {
            NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Calendar"; color: "white"
                    font.pixelSize: 15; font.bold: true
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                NavButton { label: "◀"; onClicked: root.prevMonth() }
                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                    text: root.monthNames[root.month] + " " + root.year
                    color: "white"; font.pixelSize: 14; font.bold: true
                }
                NavButton { label: "▶"; onClicked: root.nextMonth() }
            }

            Row {
                id: dayHeader; Layout.fillWidth: true
                Repeater {
                    model: root.dayNames
                    delegate: Text {
                        width: dayHeader.width / 7; horizontalAlignment: Text.AlignHCenter
                        text: modelData; color: '#c8a6c6'; font.pixelSize: 11; font.bold: true
                    }
                }
            }

            GridView {
                id: calGrid
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; interactive: false
                cellWidth: calGrid.width / 7; cellHeight: 34
                model: root.cells

                delegate: Rectangle {
                    required property var modelData
                    width: calGrid.cellWidth - 3; height: 32; radius: 6
                    visible: modelData.day > 0
                    color: modelData.today ? Qt.rgba(1, 0.65, 0.89, 0.25)
                        : (dayMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.12) : "transparent")
                    Text {
                        anchors.centerIn: parent
                        text: modelData.day > 0 ? modelData.day : ""
                        color: modelData.today ? '#ffd0fa' : '#f4cdf0'
                        font.pixelSize: 12; font.bold: modelData.today
                    }
                    MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }

    component NavButton: Rectangle {
        id: navBtn
        property string label: ""; signal clicked()
        width: 30; height: 30; radius: 6
        color: navMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
        border.color: Qt.rgba(1, 1, 1, 0.05); border.width: 1
        Text { anchors.centerIn: parent; text: navBtn.label; color: '#ffd0fa'; font.pixelSize: 14 }
        MouseArea {
            id: navMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }
    }
}