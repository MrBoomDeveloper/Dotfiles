import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: root

    property var item: null
    property var anchorItem: null
    property int anchorY: 0
    signal dismissed()

    property var currentMenu: null
    property bool closing: false

    visible: false
    color: "transparent"
    grabFocus: true

    implicitWidth: 280
    implicitHeight: 420

    anchor.item: root.anchorItem
    anchor.rect.x: 0
    anchor.rect.y: root.anchorY
    anchor.rect.width: 32
    anchor.rect.height: 32
    anchor.edges: Edges.Top | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.Flip

    readonly property bool inSubmenu: root.currentMenu !== (root.item ? root.item.menu : null)

    onItemChanged: {
        if (root.item !== null && root.anchorItem !== null) {
            dismissTimer.stop()
            root.currentMenu = root.item.menu
            root.visible = true
            root.closing = false
            closeSlideTimer.stop()
            panel.slideX = -280
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
        onTriggered: panel.slideX = -280
    }

    Timer {
        id: dismissTimer
        interval: 220
        onTriggered: {
            root.visible = false
            root.closing = false
            root.dismissed()
        }
    }

    Component.onCompleted: panel.slideX = -280

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
        color: Qt.rgba(0, 0, 0, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

        property real slideX: 0
        transform: Translate { x: panel.slideX }

        Behavior on slideX {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: root.item ? root.item.title : ""
                    color: "white"; font.pixelSize: 14; font.bold: true
                    elide: Text.ElideRight
                }

                Rectangle {
                    implicitWidth: 24; implicitHeight: 24; radius: 6
                    color: closeMouse.containsMouse
                        ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.05); border.width: 1
                    Text {
                        anchors.centerIn: parent; text: "✕"
                        color: '#ffd0fa'; font.pixelSize: 12
                    }
                    MouseArea {
                        id: closeMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.closing = true
                            closeSlideTimer.restart()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; implicitHeight: 28; radius: 6
                visible: root.inSubmenu
                color: backMouse.containsMouse
                    ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05); border.width: 1
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "←"; color: '#ffd0fa'; font.pixelSize: 12 }
                    Text { text: "Back"; color: '#ffd0fa'; font.pixelSize: 12 }
                }
                MouseArea {
                    id: backMouse; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentMenu = root.item ? root.item.menu : null
                }
            }

            ListView {
                id: menuList
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 2
                model: menuOpener.children

                delegate: Rectangle {
                    id: menuItem
                    required property var modelData
                    readonly property var entry: modelData
                    width: menuList.width
                    height: entry.isSeparator ? 9 : 30; radius: 6
                    color: !entry.isSeparator && itemMouse.containsMouse
                        ? Qt.rgba(1, 0.65, 0.89, 0.175) : "transparent"

                    Rectangle {
                        visible: entry.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 1
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    RowLayout {
                        visible: !entry.isSeparator
                        anchors.fill: parent
                        anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8

                        Text {
                            visible: entry.buttonType !== QsMenuButtonType.None
                            text: entry.checkState === Qt.Checked ? "✓"
                                : (entry.buttonType === QsMenuButtonType.RadioButton ? "○" : "□")
                            color: entry.enabled ? '#ffd0fa' : '#6c7086'; font.pixelSize: 12
                        }
                        IconImage {
                            visible: entry.icon !== ""; implicitSize: 16; source: entry.icon
                        }
                        Text {
                            Layout.fillWidth: true; text: entry.text
                            color: entry.enabled ? "white" : '#6c7086'
                            font.pixelSize: 12; elide: Text.ElideRight
                        }
                        Text {
                            visible: entry.hasChildren; text: "▸"
                            color: '#c8a6c6'; font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: itemMouse; visible: !entry.isSeparator
                        anchors.fill: parent; hoverEnabled: true
                        enabled: entry.enabled; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.hasChildren) {
                                root.currentMenu = entry
                            } else {
                                entry.triggered()
                                root.closing = true
                                closeSlideTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    QsMenuOpener {
        id: menuOpener
        menu: root.currentMenu
    }
}