import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: root

    property string icon: ""
    property string text: ""
    property bool shown: false

    visible: shown
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        top: true
        left: true
        right: true
    }

    margins.top: 46
    implicitHeight: 60

    function show(glyph, label) {
        root.icon = glyph
        root.text = label
        root.shown = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1600
        repeat: false
        onTriggered: root.shown = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(125, contentRow.implicitWidth + 52)
        height: 52
        radius: 26
        color: Qt.rgba(0, 0, 0, 0.82)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: root.icon
                color: "#ffd0fa"
                font.pixelSize: 18
                font.family: "Google Sans Flex"
            }

            Text {
                text: root.text
                color: "white"
                font.pixelSize: 14
                font.bold: true
                font.family: "Google Sans Flex"
            }
        }
    }
}
