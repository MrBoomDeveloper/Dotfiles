import QtQuick

// ── Shared desktop-widget interaction ──
// Tracks hover, forwards left clicks (activated) and implements BoomShell-style
// edit mode: right-click enables it, then the body drags the widget and the
// corner handle resizes it.
Item {
    id: root

    property Item target: null
    property bool editMode: false
    property real uiScale: 1.0

    property bool hovered: false

    signal activated()
    signal editToggled()
    signal moved(real x, real y)
    signal resized(real scale)

    M3Theme { id: theme }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: root.hovered = true
        onExited: root.hovered = false

        cursorShape: root.editMode
            ? (pointer.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
            : Qt.PointingHandCursor

        property point pressPoint: Qt.point(0, 0)
        property real pressX: 0
        property real pressY: 0
        property bool dragging: false

        onPressed: mouse => {
            pressPoint = Qt.point(mouse.x, mouse.y)
            pressX = root.target ? root.target.x : 0
            pressY = root.target ? root.target.y : 0
            dragging = false
        }

        onPositionChanged: mouse => {
            if (!root.editMode || !root.target || !(mouse.buttons & Qt.LeftButton))
                return

            const dx = mouse.x - pressPoint.x
            const dy = mouse.y - pressPoint.y
            if (!dragging && Math.abs(dx) < 4 && Math.abs(dy) < 4)
                return
            dragging = true

            const bounds = root.target.parent
            const maxX = bounds ? Math.max(0, bounds.width - root.target.width) : Infinity
            const maxY = bounds ? Math.max(0, bounds.height - root.target.height) : Infinity
            root.target.x = Math.max(0, Math.min(maxX, pressX + dx))
            root.target.y = Math.max(0, Math.min(maxY, pressY + dy))
        }

        onReleased: {
            if (dragging && root.target)
                root.moved(root.target.x, root.target.y)
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.editToggled()
            } else if (root.editMode) {
                if (!dragging)
                    root.editToggled()
            } else {
                root.activated()
            }
        }
    }

    // ── Finish-editing badge ──
    Rectangle {
        z: 1
        visible: root.editMode
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.top
        width: 26
        height: 26
        radius: theme.radiusFull
        color: theme.primary

        Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
            color: theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editToggled()
        }
    }

    // ── Resize handle ──
    Rectangle {
        z: 1
        visible: root.editMode
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.bottom
        width: 26
        height: 26
        radius: theme.radiusFull
        color: theme.primary

        Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0453) // resize
            font.family: theme.fontFamily
            font.pixelSize: 12
            color: theme.primaryText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor

            property point pressScene: Qt.point(0, 0)
            property real startScale: 1

            onPressed: mouse => {
                pressScene = mapToItem(null, mouse.x, mouse.y)
                startScale = root.uiScale
            }

            onPositionChanged: mouse => {
                if (!(mouse.buttons & Qt.LeftButton))
                    return
                const p = mapToItem(null, mouse.x, mouse.y)
                const delta = (p.x - pressScene.x) + (p.y - pressScene.y)
                root.resized(Math.max(0.6, Math.min(4.0, startScale + delta / 260)))
            }
        }
    }
}
