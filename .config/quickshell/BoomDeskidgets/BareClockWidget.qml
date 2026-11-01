import QtQuick

// ── Bare desktop clock ──
// No card, no background: extra-bold Material 3 type straight on the wallpaper.
// style "stacked" puts hours above minutes, "inline" shows a single HH:MM line.
Item {
    id: bareRoot

    required property var currentTime

    property string style: "stacked"
    property bool editMode: false
    property real uiScale: 1.0

    signal moved(real x, real y)
    signal resized(real scale)

    M3Theme { id: theme }

    readonly property string hours: String(currentTime.getHours()).padStart(2, "0")
    readonly property string minutes: String(currentTime.getMinutes()).padStart(2, "0")

    width: content.implicitWidth
    height: content.implicitHeight

    Column {
        id: content
        x: 0
        y: 0
        spacing: 0

        // ── Stacked: hours on the first line, minutes on the second ──
        // Negative spacing pulls both lines together as tight as possible:
        // digits have no ascenders/descenders, so nothing gets clipped.
        Column {
            visible: bareRoot.style !== "inline"
            spacing: -84 * bareRoot.uiScale * 0.38

            Text {
                text: bareRoot.hours
                color: theme.surfaceText
                font.family: theme.fontFamily
                font.pixelSize: 84 * bareRoot.uiScale
                font.weight: Font.Black
            }

            Text {
                text: bareRoot.minutes
                color: theme.surfaceText
                font.family: theme.fontFamily
                font.pixelSize: 84 * bareRoot.uiScale
                font.weight: Font.Black
            }
        }

        // ── Inline: HH:MM on one line ──
        Row {
            visible: bareRoot.style === "inline"
            spacing: 0

            Text {
                text: bareRoot.hours
                color: theme.surfaceText
                font.family: theme.fontFamily
                font.pixelSize: 68 * bareRoot.uiScale
                font.weight: Font.Black
            }

            Text {
                text: ":"
                color: theme.surfaceText
                font.family: theme.fontFamily
                font.pixelSize: 68 * bareRoot.uiScale
                font.weight: Font.Black
            }

            Text {
                text: bareRoot.minutes
                color: theme.surfaceText
                font.family: theme.fontFamily
                font.pixelSize: 68 * bareRoot.uiScale
                font.weight: Font.Black
            }
        }
    }

    // ── Edit outline (the widget itself has no background) ──
    Rectangle {
        visible: bareRoot.editMode
        anchors.fill: parent
        anchors.margins: -10
        radius: theme.radiusChip
        color: "transparent"
        border.width: 1
        border.color: theme.primary
    }

    WidgetInteraction {
        id: interaction
        anchors.fill: parent
        anchors.margins: -10
        target: bareRoot
        editMode: bareRoot.editMode
        uiScale: bareRoot.uiScale
        onEditToggled: bareRoot.editMode = !bareRoot.editMode
        onMoved: (x, y) => bareRoot.moved(x, y)
        onResized: scale => bareRoot.resized(scale)
    }
}
