import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "Theme.js" as T
import "EmojiData.js" as E

// Custom emoji picker: search (English + Russian queries), category filter,
// keyboard navigation. Enter copies the highlighted emoji to the clipboard.
PanelWindow {
    id: root

    // External control
    property bool open: false
    signal dismissed()
    signal copied(string emoji)

    // Filter state
    property alias query: search.text
    property int category: -1
    property int selected: 0
    property bool shown: false

    readonly property int columns: 9

    readonly property var chipModel: {
        const list = [{ label: "All", index: -1 }]
        for (let i = 0; i < E.categories.length; i++)
            list.push({ label: E.categories[i].split(" & ")[0], index: i })
        return list
    }

    // Expand a search query into the keywords used by EmojiData.js. Russian
    // words are translated through the keyword table, so "кот" finds 🐱.
    function translateTokens(q) {
        const tokens = q.length > 0 ? q.split(/\s+/) : []
        const needles = []
        for (let i = 0; i < tokens.length; i++) {
            const token = tokens[i]
            needles.push(token)
            const direct = E.ruKeywords[token]
            if (direct !== undefined) {
                needles.push(direct)
                continue
            }
            for (const key in E.ruKeywords) {
                if (token.length >= 3 && token.indexOf(key) === 0) {
                    needles.push(E.ruKeywords[key])
                    break
                }
            }
        }
        return needles
    }

    readonly property var results: {
        const needles = root.translateTokens(root.query.trim().toLowerCase())
        const list = []
        for (let i = 0; i < E.emojis.length; i++) {
            const item = E.emojis[i]
            if (root.category >= 0 && item[3] !== root.category)
                continue
            if (needles.length > 0) {
                const hay = item[1] + " " + item[2] + " " + E.categories[item[3]].toLowerCase()
                let match = true
                for (let n = 0; n < needles.length; n++) {
                    if (hay.indexOf(needles[n]) < 0) {
                        match = false
                        break
                    }
                }
                if (!match)
                    continue
            }
            list.push(item)
        }
        return list
    }

    function pick(emoji) {
        if (!emoji)
            return
        Quickshell.clipboardText = emoji
        root.copied(emoji)
        root.dismissed()
    }

    function pickSelected() {
        const item = root.results[root.selected]
        if (item)
            root.pick(item[0])
    }

    function move(delta) {
        if (root.results.length === 0)
            return
        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + delta))
        grid.positionViewAtIndex(root.selected, GridView.Contain)
    }

    onQueryChanged: {
        root.selected = 0
        scrollTimer.restart()
    }
    onCategoryChanged: {
        root.selected = 0
        scrollTimer.restart()
    }
    onResultsChanged: {
        if (root.selected >= root.results.length)
            root.selected = 0
        scrollTimer.restart()
    }

    onOpenChanged: {
        if (root.open) {
            root.query = ""
            root.category = -1
            root.selected = 0
            root.shown = false
            showTimer.restart()
            focusTimer.restart()
            scrollTimer.restart()
        }
    }

    Timer {
        id: showTimer
        interval: 0
        onTriggered: root.shown = true
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: search.forceActiveFocus()
    }

    // Keep the grid at the top when the picker is reopened or filtered.
    Timer {
        id: scrollTimer
        interval: 0
        onTriggered: grid.positionViewAtBeginning()
    }

    visible: root.open
    color: "transparent"
    focusable: root.open
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 32)
        height: Math.min(560, parent.height - 64)
        radius: T.radiusPanel
        color: T.surface
        border.color: T.outline
        border.width: 1
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        // Absorb clicks so they don't close the picker
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            AppBar {
                title: "Emoji"
                showClose: true
                onCloseClicked: root.dismissed()

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.results.length + " emoji"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.labelMedium
                    font.family: T.font
                }
            }

            // Search field
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                TextField {
                    id: search
                    anchors.fill: parent
                    placeholderText: "Search emoji…"
                    color: T.onSurface
                    placeholderTextColor: T.onSurfaceVariant
                    selectionColor: T.secondaryContainerStrong
                    selectedTextColor: T.onSurface
                    font.pixelSize: T.bodyLarge
                    font.family: T.font
                    leftPadding: 42
                    rightPadding: root.query.length > 0 ? 42 : T.margin
                    onAccepted: root.pickSelected()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.move(root.columns)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.move(-root.columns)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.dismissed()
                            event.accepted = true
                        }
                    }

                    background: Rectangle {
                        radius: 12
                        color: T.surfaceContainerHigh
                        border.color: search.activeFocus ? T.primary : T.outline
                        border.width: 1
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0349) // search
                    color: T.onSurfaceVariant
                    font.pixelSize: 18
                    font.family: T.font
                }

                M3IconButton {
                    visible: root.query.length > 0
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    iconSize: 15
                    glyph: String.fromCodePoint(0xF0156) // close
                    onClicked: {
                        root.query = ""
                        search.forceActiveFocus()
                    }
                }
            }

            // Category filter
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: T.gapSmall

                Repeater {
                    model: root.chipModel

                    delegate: M3Chip {
                        required property var modelData
                        label: modelData.label
                        selected: root.category === modelData.index
                        onToggled: root.category = root.category === modelData.index ? -1 : modelData.index
                    }
                }
            }

            // Emoji grid
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true
                    cellWidth: width / root.columns
                    cellHeight: 44
                    model: root.results
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.centerIn: parent
                            width: 38
                            height: 38
                            radius: 10
                            color: index === root.selected ? T.secondaryContainerStrong
                                 : (cellMouse.containsMouse ? T.surfaceContainerHigh : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: modelData[0]
                                font.pixelSize: 22
                                font.family: "Noto Color Emoji"
                            }
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pick(modelData[0])
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.results.length === 0
                    text: "No emoji found"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }

            Text {
                Layout.fillWidth: true
                text: "↑↓ navigate · Enter copy · Esc close"
                color: T.onSurfaceVariant
                font.pixelSize: T.labelSmall
                font.family: T.font
            }
        }
    }
}
