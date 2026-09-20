import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Column {
    id: root
    spacing: 4

    // Emitted when a tray icon is left-clicked and should open its menu.
    // `y` is the icon's y position within this column (for popup anchoring).
    signal openMenu(var item, int y)

    // Resolve an SNI icon string to something Image/IconImage can load.
    function resolveIcon(icon) {
        if (!icon)
            return ""
        // Already a path or URL
        if (icon.indexOf("/") >= 0 || icon.indexOf("file:") === 0)
            return icon
        // Freedesktop theme icon name
        return Quickshell.iconPath(icon)
    }

    Repeater {
        model: SystemTray.items

        delegate: Rectangle {
            id: trayBtn

            required property var modelData

            width: 32
            height: 32
            radius: 8
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            color: trayMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: root.resolveIcon(trayBtn.modelData.icon)
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        trayBtn.modelData.secondaryActivate()
                    } else {
                        root.openMenu(trayBtn.modelData, trayBtn.y)
                    }
                }
            }
        }
    }
}
