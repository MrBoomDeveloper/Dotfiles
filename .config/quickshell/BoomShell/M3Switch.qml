import QtQuick
import "Theme.js" as T

// Material 3 switch — 44x26 track, 20/24dp thumb
Item {
    id: toggle

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: toggle.checked ? T.primary : T.surfaceContainerHighest
        border.color: T.outline
        border.width: toggle.checked ? 0 : 2

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Rectangle {
        id: thumb
        width: toggle.checked ? 24 : 20
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: toggle.checked ? 17 : 3
        color: toggle.checked ? T.onPrimary : T.onSurfaceVariant

        Behavior on x {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
