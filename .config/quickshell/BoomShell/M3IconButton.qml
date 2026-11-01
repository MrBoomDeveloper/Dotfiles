import QtQuick
import "Theme.js" as T

// Material 3 icon button
Rectangle {
    id: btn

    property string glyph: ""
    property int size: 36
    property int iconSize: 18
    property bool active: false
    property color iconColor: T.onSurfaceVariant
    signal clicked()

    width: btn.size
    height: btn.size
    radius: btn.size / 2
    color: btn.active ? T.secondaryContainerStrong : (btnMouse.containsMouse ? T.surfaceContainerHigh : "transparent")

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: btn.active ? T.onSecondaryContainer : btn.iconColor
        font.pixelSize: btn.iconSize
        font.family: T.font
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
