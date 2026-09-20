import QtQuick
import QtQuick.Layouts

Rectangle {
    id: toggle
    property string label: ""
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true
    implicitHeight: 42
    radius: 8
    color: Qt.rgba(1, 0.65, 0.89, 0.03)
    border.color: Qt.rgba(1, 1, 1, 0.05)
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            text: toggle.label
            color: '#f4cdf1'
            font.pixelSize: 13
            Layout.fillWidth: true
        }

        Rectangle {
            width: 42
            height: 22
            radius: 11
            color: toggle.checked ? '#ffa9e5' : '#382432'

            Rectangle {
                width: 16
                height: 16
                radius: 8
                anchors.verticalCenter: parent.verticalCenter
                x: toggle.checked ? parent.width - width - 3 : 3
                color: toggle.checked ? "black" : "white"

                Behavior on x {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.toggled(!toggle.checked)
            }
        }
    }
}