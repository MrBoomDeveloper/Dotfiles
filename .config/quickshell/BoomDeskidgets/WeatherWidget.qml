import QtQuick
import QtQuick.Layouts

Item {
    id: weatherRoot

    required property string temperature
    required property string condition
    required property string icon
    required property string city
    required property real humidity
    required property real wind
    required property bool loaded

    signal clicked()

    width: 220
    height: weatherColumn.implicitHeight + 48

    // ── M3 Surface card ──
    Rectangle {
        anchors.fill: parent
        radius: 28
        color: Qt.rgba(0, 0, 0, 0.45)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
    }

    // Click to open settings
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: weatherRoot.clicked()
    }

    Column {
        id: weatherColumn
        anchors.centerIn: parent
        spacing: 4

        // ── Loading state ──
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !weatherRoot.loaded
            text: "Loading..."
            font.family: "Google Sans"
            font.pixelSize: 16
            color: Qt.rgba(1, 1, 1, 0.5)
        }

        // ── Weather content ──
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: weatherRoot.loaded

            // ── City name ──
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherRoot.city
                font.family: "Google Sans"
                font.pixelSize: 14
                font.weight: Font.Normal
                color: Qt.rgba(1, 1, 1, 0.6)
            }

            // ── Main temperature + icon row ──
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                layoutDirection: Qt.RightToLeft

                Text {
                    text: weatherRoot.icon
                    font.pixelSize: 40
                    anchors.baseline: tempText.baseline
                }

                Text {
                    id: tempText
                    text: weatherRoot.temperature
                    font.family: "Google Sans"
                    font.pixelSize: 56
                    font.weight: Font.Light
                    color: "white"
                }
            }

            // ── Condition ──
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherRoot.condition
                font.family: "Google Sans"
                font.pixelSize: 14
                font.weight: Font.Normal
                color: Qt.rgba(1, 1, 1, 0.7)
            }

            // ── Divider ──
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: weatherRoot.width - 48
                height: 1
                color: Qt.rgba(1, 1, 1, 0.1)
            }

            // ── Details row ──
            RowLayout {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                // Humidity
                ColumnLayout {
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "💧"
                        font.pixelSize: 14
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(weatherRoot.humidity) + "%"
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                }

                // Wind
                ColumnLayout {
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "💨"
                        font.pixelSize: 14
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Math.round(weatherRoot.wind) + " km/h"
                        font.family: "Google Sans"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        color: Qt.rgba(1, 1, 1, 0.6)
                    }
                }
            }
        }
    }
}
