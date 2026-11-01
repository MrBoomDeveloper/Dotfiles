import QtQuick
import QtQuick.Layouts

// ── BoomShell-styled weather card ──
// Left click opens the settings screen; right-click toggles edit mode for
// moving and resizing the card.
Item {
    id: weatherRoot

    required property string temperature
    required property string condition
    required property string icon
    required property string city
    required property real humidity
    required property real wind
    required property bool loaded

    property bool editMode: false
    property real surfaceOpacity: 0.92
    property real uiScale: 1.0

    signal clicked()
    signal moved(real x, real y)
    signal resized(real scale)

    M3Theme { id: theme }

    readonly property real pad: 24 * uiScale

    width: 240 * uiScale
    height: content.implicitHeight + pad * 2

    // ── Surface ──
    Rectangle {
        anchors.fill: parent
        radius: theme.radiusPanel
        color: Qt.rgba(0, 0, 0, weatherRoot.surfaceOpacity)
        border.width: weatherRoot.editMode ? 2 : 1
        border.color: weatherRoot.editMode ? theme.primary : theme.outlineVariant

        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }

        // State layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: theme.surfaceText
            opacity: weatherRoot.editMode
                ? theme.stateEdit
                : (interaction.hovered ? theme.stateHover : 0)
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    ColumnLayout {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: weatherRoot.pad
        spacing: 2 * weatherRoot.uiScale

        // ── City ──
        Text {
            Layout.fillWidth: true
            text: weatherRoot.city
            font.family: theme.fontFamily
            font.pixelSize: theme.labelMedium * weatherRoot.uiScale
            font.weight: Font.Medium
            color: theme.primary
            elide: Text.ElideRight
        }

        // ── Loading ──
        Text {
            visible: !weatherRoot.loaded
            text: "Loading…"
            font.family: theme.fontFamily
            font.pixelSize: theme.bodyLarge * weatherRoot.uiScale
            color: theme.surfaceVariantText
        }

        // ── Temperature ──
        RowLayout {
            visible: weatherRoot.loaded
            Layout.fillWidth: true
            Layout.topMargin: 2 * weatherRoot.uiScale
            spacing: 10 * weatherRoot.uiScale

            Text {
                text: weatherRoot.icon
                font.pixelSize: 30 * weatherRoot.uiScale
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: weatherRoot.temperature
                font.family: theme.fontFamily
                font.pixelSize: theme.displayMedium * weatherRoot.uiScale
                font.weight: Font.Light
                color: theme.surfaceText
            }
        }

        Text {
            visible: weatherRoot.loaded
            Layout.fillWidth: true
            text: weatherRoot.condition
            font.family: theme.fontFamily
            font.pixelSize: theme.bodyMedium * weatherRoot.uiScale
            color: theme.surfaceVariantText
            elide: Text.ElideRight
        }

        // ── Divider ──
        Rectangle {
            visible: weatherRoot.loaded
            Layout.fillWidth: true
            Layout.topMargin: 10 * weatherRoot.uiScale
            Layout.bottomMargin: 4 * weatherRoot.uiScale
            implicitHeight: 1
            color: theme.outlineVariant
        }

        // ── Detail chips ──
        RowLayout {
            visible: weatherRoot.loaded
            Layout.fillWidth: true
            spacing: 8 * weatherRoot.uiScale

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32 * weatherRoot.uiScale
                radius: theme.radiusChip
                color: theme.secondaryContainerStrong

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5 * weatherRoot.uiScale

                    Text {
                        text: "💧"
                        font.pixelSize: theme.labelMedium * weatherRoot.uiScale
                    }

                    Text {
                        text: Math.round(weatherRoot.humidity) + "%"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.labelMedium * weatherRoot.uiScale
                        font.weight: Font.Medium
                        color: theme.secondaryContainerText
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32 * weatherRoot.uiScale
                radius: theme.radiusChip
                color: theme.secondaryContainerStrong

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5 * weatherRoot.uiScale

                    Text {
                        text: "💨"
                        font.pixelSize: theme.labelMedium * weatherRoot.uiScale
                    }

                    Text {
                        text: Math.round(weatherRoot.wind) + " km/h"
                        font.family: theme.fontFamily
                        font.pixelSize: theme.labelMedium * weatherRoot.uiScale
                        font.weight: Font.Medium
                        color: theme.secondaryContainerText
                    }
                }
            }
        }
    }

    WidgetInteraction {
        id: interaction
        anchors.fill: parent
        target: weatherRoot
        editMode: weatherRoot.editMode
        uiScale: weatherRoot.uiScale
        onEditToggled: weatherRoot.editMode = !weatherRoot.editMode
        onActivated: weatherRoot.clicked()
        onMoved: (x, y) => weatherRoot.moved(x, y)
        onResized: scale => weatherRoot.resized(scale)
    }
}
