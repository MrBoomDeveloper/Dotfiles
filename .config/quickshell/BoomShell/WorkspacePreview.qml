import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

PopupWindow {
    id: root

    property bool open: false
    property var ws: null
    property var anchorItem: null
    property int anchorY: 0

    visible: open && ws !== null && anchorItem !== null
    color: "transparent"

    implicitWidth: 260
    implicitHeight: 240

    anchor.item: root.anchorItem
    anchor.rect.x: 0
    anchor.rect.y: root.anchorY
    anchor.rect.width: 32
    anchor.rect.height: 32
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.ws ? root.ws.name : ""
                color: "white"
                font.pixelSize: 14
                font.bold: true
                font.family: "Google Sans Flex"
                elide: Text.ElideRight
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: root.ws ? root.ws.toplevels : []

                    delegate: Text {
                        required property var modelData
                        width: list.width
                        text: modelData.title || "(untitled)"
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        font.family: "Google Sans Flex"
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No windows"
                    color: "#6c7086"
                    font.pixelSize: 12
                    font.family: "Google Sans Flex"
                }
            }
        }
    }
}
