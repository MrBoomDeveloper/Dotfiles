import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "Theme.js" as T

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

    implicitWidth: 260
    implicitHeight: 360

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

        property real slideX: 0
        transform: Translate { x: panel.slideX }

        Behavior on slideX {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.gap
            spacing: 2

            AppBar {
                title: root.item ? root.item.title : ""
                titleSize: 20
                showClose: true
                onCloseClicked: {
                    root.closing = true
                    closeSlideTimer.restart()
                    dismissTimer.restart()
                }
            }

            // Back to main menu
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: T.radiusSmall
                visible: root.inSubmenu
                color: backMouse.containsMouse ? T.surfaceContainer : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: T.gap

                    Text {
                        text: String.fromCodePoint(0xF004D) // arrow-left
                        color: T.onSecondaryContainer
                        font.pixelSize: 16
                        font.family: T.font
                    }

                    Text {
                        text: "Back"
                        color: T.onSurface
                        font.pixelSize: T.labelLarge
                        font.family: T.font
                    }
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentMenu = root.item ? root.item.menu : null
                }
            }

            ListView {
                id: menuList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: menuOpener.children

                delegate: Rectangle {
                    id: menuItem
                    required property var modelData
                    readonly property var entry: modelData
                    width: menuList.width
                    height: entry.isSeparator ? 7 : 38
                    radius: T.radiusSmall
                    color: !entry.isSeparator && itemMouse.containsMouse
                        ? T.surfaceContainer : "transparent"

                    Rectangle {
                        visible: entry.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 1
                        color: T.outlineVariant
                    }

                    RowLayout {
                        visible: !entry.isSeparator
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: T.gap

                        Text {
                            visible: entry.buttonType !== QsMenuButtonType.None
                            text: {
                                if (entry.checkState === Qt.Checked)
                                    return String.fromCodePoint(0xF012C); // check
                                if (entry.buttonType === QsMenuButtonType.RadioButton)
                                    return String.fromCodePoint(0xF043D); // radio-blank
                                return String.fromCodePoint(0xF0131); // checkbox-blank
                            }
                            color: entry.enabled ? T.onSecondaryContainer : T.disabled
                            font.pixelSize: 14
                            font.family: T.font
                        }

                        IconImage {
                            visible: entry.icon !== ""
                            implicitSize: 16
                            source: entry.icon
                        }

                        Text {
                            Layout.fillWidth: true
                            text: entry.text
                            color: entry.enabled ? T.onSurface : T.disabled
                            font.pixelSize: T.labelLarge
                            font.family: T.font
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: entry.hasChildren
                            text: String.fromCodePoint(0xF0142) // chevron-right
                            color: T.onSurfaceVariant
                            font.pixelSize: 14
                            font.family: T.font
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        visible: !entry.isSeparator
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entry.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.hasChildren) {
                                root.currentMenu = entry
                            } else {
                                entry.triggered()
                                root.closing = true
                                closeSlideTimer.restart()
                                dismissTimer.restart()
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
