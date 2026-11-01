import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// Material 3 top app bar: leading close icon, title, trailing actions.
Item {
    id: appBar

    property string title: ""
    property int titleSize: T.titleLarge
    property bool showClose: false
    signal closeClicked()

    // Trailing actions go here
    default property alias actions: actionsRow.data

    Layout.fillWidth: true
    implicitHeight: T.appBarHeight

    RowLayout {
        anchors.fill: parent
        spacing: T.gapSmall

        M3IconButton {
            visible: appBar.showClose
            Layout.alignment: Qt.AlignVCenter
            glyph: String.fromCodePoint(0xF0156) // close
            iconSize: 18
            onClicked: appBar.closeClicked()
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: T.gapSmall
            text: appBar.title
            color: T.onSurface
            font.pixelSize: appBar.titleSize
            font.weight: Font.Medium
            font.family: T.font
            elide: Text.ElideRight
        }

        RowLayout {
            id: actionsRow
            Layout.alignment: Qt.AlignVCenter
            spacing: T.gap
        }
    }
}
