import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// Material 3 filter chip
Rectangle {
    id: chip

    property string label: ""
    property bool selected: false
    signal toggled(bool value)

    implicitWidth: contentRow.implicitWidth + 20
    implicitHeight: 28
    radius: T.radiusChip
    color: chip.selected ? T.secondaryContainerStrong
                         : (chipMouse.containsMouse ? T.surfaceContainer : "transparent")
    border.color: T.outline
    border.width: chip.selected ? 0 : 1

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: T.gap

        Text {
            visible: chip.selected
            text: String.fromCodePoint(0xF012C) // check
            color: T.onSecondaryContainer
            font.pixelSize: 14
            font.family: T.font
        }

        Text {
            text: chip.label
            color: chip.selected ? T.onSecondaryContainer : T.onSurfaceVariant
            font.pixelSize: T.labelMedium
            font.weight: Font.Medium
            font.family: T.font
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.toggled(!chip.selected)
    }
}
