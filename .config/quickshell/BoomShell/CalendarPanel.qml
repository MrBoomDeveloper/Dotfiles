import QtQuick
import QtQuick.Layouts
import Quickshell

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

    implicitWidth: 340
    implicitHeight: 384

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
        radius: 20
        color: Qt.rgba(0, 0, 0, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

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
            anchors.margins: 16
            spacing: 10

            // Header — month/year + Today chip + chevron navigation
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.monthNames[root.month] + " " + root.year
                    color: "white"
                    font.pixelSize: 17
                    font.bold: true
                    font.family: "Google Sans Flex"
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: todayText.implicitWidth + 22
                    implicitHeight: 28
                    radius: 14
                    color: todayMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.26) : Qt.rgba(1, 0.65, 0.89, 0.12)

                    Text {
                        id: todayText
                        anchors.centerIn: parent
                        text: "Today"
                        color: '#ffd0fa'
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Google Sans Flex"
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToToday()
                    }
                }

                NavButton {
                    glyph: String.fromCodePoint(0xF0141) // chevron-left
                    onClicked: root.prevMonth()
                }

                NavButton {
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
                        color: '#c8a6c6'
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Google Sans Flex"
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
                cellHeight: 40
                model: root.cells

                delegate: Item {
                    required property var modelData
                    width: calGrid.cellWidth
                    height: calGrid.cellHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: 36
                        height: 36
                        radius: 18
                        color: modelData.today ? '#ffc0f7'
                             : (modelData.inMonth && dayMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.12) : "transparent")

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day
                            color: modelData.today ? "black" : (modelData.inMonth ? '#f4cdf0' : '#6c7086')
                            font.pixelSize: 12
                            font.bold: modelData.today
                            font.family: "Google Sans Flex"
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

    component NavButton: Rectangle {
        id: navBtn
        property string glyph: ""
        signal clicked()
        width: 32
        height: 32
        radius: 16
        color: navMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : "transparent"

        Text {
            anchors.centerIn: parent
            text: navBtn.glyph
            color: '#ffd0fa'
            font.pixelSize: 14
            font.family: "Google Sans Flex"
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: navBtn.clicked()
        }
    }
}
