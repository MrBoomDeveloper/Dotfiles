import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// M3 settings row with trailing switch. Compact mode is a bare switch.
Rectangle {
    id: toggle
    property string label: ""
    property bool checked: false
    property bool compact: false
    signal toggled(bool value)

    Layout.fillWidth: !toggle.compact
    implicitWidth: toggle.compact ? 52 : 0
    implicitHeight: toggle.compact ? 32 : T.rowHeight
    radius: T.radiusCard
    color: !toggle.compact && rowMouse.containsMouse ? T.surfaceContainer : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: toggle.compact ? 0 : T.margin
        anchors.rightMargin: toggle.compact ? 0 : T.margin
        spacing: T.gapLarge

        Text {
            visible: !toggle.compact
            Layout.fillWidth: true
            text: toggle.label
            color: T.onSurface
            font.pixelSize: T.bodyLarge
            font.family: T.font
            elide: Text.ElideRight
        }

        M3Switch {
            checked: toggle.checked
            onToggled: value => toggle.toggled(value)
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        visible: !toggle.compact
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
