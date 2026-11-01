import QtQuick
import QtQuick.Layouts
import Quickshell
import "Theme.js" as T

PopupWindow {
    id: root

    property bool open: false
    property var anchorItem: null
    signal dismissed()

    property int year: 2026
    property int month: 0
    property bool closing: false

    visible: false
    color: "transparent"

    implicitWidth: 320
    implicitHeight: 344

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
        const daysInPrevMonth = new Date(root.year, root.month, 0).getDate()
        const now = new Date()
        const list = []
        for (let i = offset - 1; i >= 0; i--)
            list.push({ day: daysInPrevMonth - i, inMonth: false, today: false })
        for (let d = 1; d <= daysInMonth; d++)
            list.push({ day: d, inMonth: true, today: now.getFullYear() === root.year &&
                       now.getMonth() === root.month && now.getDate() === d })
        const trailing = (7 - (list.length % 7)) % 7
        for (let d = 1; d <= trailing; d++)
            list.push({ day: d, inMonth: false, today: false })
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
            dismissTimer.restart()
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
        interval: 260
        onTriggered: {
            root.visible = false
            root.closing = false
            root.resetToToday()
            root.dismissed()
        }
    }

    Component.onCompleted: { root.resetToToday(); panel.slideX = -340 }

    onClosed: {
        if (!root.closing) {
            slideInTimer.stop()
            root.closing = true
            closeSlideTimer.restart()
            dismissTimer.restart()
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: T.radiusPanel
        color: T.surface
        border.color: T.outline
        border.width: 1

        property real slideX: -340
        transform: Translate { x: panel.slideX }

        Behavior on slideX {
            NumberAnimation {
                duration: root.closing ? 200 : 240
                easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            // Header — Material 3 top app bar
            AppBar {
                title: root.monthNames[root.month] + " " + root.year

                Rectangle {
                    implicitWidth: todayText.implicitWidth + 18
                    implicitHeight: 26
                    Layout.alignment: Qt.AlignVCenter
                    radius: 13
                    color: todayMouse.containsMouse ? T.secondaryContainerStrong : T.secondaryContainer

                    Text {
                        id: todayText
                        anchors.centerIn: parent
                        text: "Today"
                        color: T.onSecondaryContainer
                        font.pixelSize: T.labelMedium
                        font.weight: Font.Medium
                        font.family: T.font
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToToday()
                    }
                }

                M3IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: String.fromCodePoint(0xF0141) // chevron-left
                    onClicked: root.prevMonth()
                }

                M3IconButton {
                    Layout.alignment: Qt.AlignVCenter
                    glyph: String.fromCodePoint(0xF0142) // chevron-right
                    onClicked: root.nextMonth()
                }
            }

            // Weekday labels
            Row {
                id: dayHeader
                Layout.fillWidth: true
                Repeater {
                    model: root.dayNames
                    delegate: Text {
                        width: dayHeader.width / 7
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: T.onSurfaceVariant
                        font.pixelSize: T.labelMedium
                        font.weight: Font.Medium
                        font.family: T.font
                    }
                }
            }

            // Day grid — circular cells, today filled, adjacent month dimmed
            GridView {
                id: calGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: false
                cellWidth: calGrid.width / 7
                cellHeight: 34
                model: root.cells

                delegate: Item {
                    required property var modelData
                    width: calGrid.cellWidth
                    height: calGrid.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        radius: 15
                        color: modelData.today ? T.primaryContainer
                             : (modelData.inMonth && dayMouse.containsMouse ? T.secondaryContainer : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.today ? T.onPrimaryContainer : (modelData.inMonth ? T.onSurface : T.disabled)
                            font.pixelSize: 12
                            font.weight: modelData.today ? Font.Medium : Font.Normal
                            font.family: T.font
                        }
                    }

                    MouseArea {
                        id: dayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }
                }
            }
        }
    }
}
