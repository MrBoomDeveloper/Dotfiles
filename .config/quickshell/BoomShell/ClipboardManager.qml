import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Theme.js" as T

// Clipboard history browser on top of the clipvault database.
// Entries older than 7 days are pruned whenever the history is loaded.
PanelWindow {
    id: root

    // External control
    property bool open: false
    signal dismissed()
    signal copied()

    // Filter state
    property alias query: search.text
    property int selected: 0
    property bool shown: false
    property bool loading: false
    property bool _pendingReload: false
    property var items: []

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase()
        const list = []
        for (let i = 0; i < root.items.length; i++) {
            const item = root.items[i]
            const preview = String(item.preview || "").toLowerCase()
            if (q.length === 0
                || preview.indexOf(q) >= 0
                || (item.kind === "image" && String(item.mime).toLowerCase().indexOf(q) >= 0)
                || (item.kind !== "image" && "text".indexOf(q) === 0))
                list.push(item)
        }
        return list
    }

    function helper(args) {
        return ["python3", Quickshell.shellDir + "/clipboard.py"].concat(args)
    }

    function load() {
        if (listProc.running) {
            root._pendingReload = true
            return
        }
        root.loading = true
        listProc.exec(root.helper(["list", "--limit", "200"]))
    }

    function relTime(ts) {
        const seconds = Math.max(0, Math.floor(Date.now() / 1000) - ts)
        if (seconds < 60)
            return "just now"
        if (seconds < 3600)
            return Math.floor(seconds / 60) + " min ago"
        if (seconds < 86400)
            return Math.floor(seconds / 3600) + " h ago"
        return Math.floor(seconds / 86400) + " d ago"
    }

    function metaText(item) {
        const kind = item.kind === "image"
                   ? "Image" + (item.w > 0 ? " · " + item.w + "×" + item.h : "")
                   : "Text · " + item.chars + " chars"
        return kind + " · " + root.relTime(item.ts)
    }

    function move(delta) {
        if (root.filtered.length === 0)
            return
        root.selected = Math.max(0, Math.min(root.filtered.length - 1, root.selected + delta))
        history.positionViewAtIndex(root.selected, ListView.Contain)
    }

    function copySelected() {
        const item = root.filtered[root.selected]
        if (item)
            root.copyEntry(item.id)
    }

    function copyEntry(id) {
        if (!copyProc.running)
            copyProc.exec(root.helper(["copy", String(id)]))
    }

    function removeSelected() {
        const item = root.filtered[root.selected]
        if (item)
            root.removeEntry(item.id)
    }

    function removeEntry(id) {
        if (!deleteProc.running)
            deleteProc.exec(root.helper(["delete", String(id)]))
    }

    function clearAll() {
        if (!clearProc.running)
            clearProc.exec(root.helper(["clear"]))
    }

    onQueryChanged: root.selected = 0
    onFilteredChanged: {
        if (root.selected >= root.filtered.length)
            root.selected = Math.max(0, root.filtered.length - 1)
    }

    onOpenChanged: {
        if (root.open) {
            root.query = ""
            root.selected = 0
            root.shown = false
            showTimer.restart()
            focusTimer.restart()
            root.load()
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

    // Delete works while the search field has no text to edit.
    Shortcut {
        sequence: "Delete"
        enabled: root.open && root.query.length === 0
        onActivated: root.removeSelected()
    }

    // Enforce the 7-day retention even if the panel stays closed for days.
    Timer {
        interval: 3600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pruneProc.running)
                pruneProc.exec(root.helper(["prune"]))
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector { id: listOut }

        onExited: code => {
            root.loading = false
            if (code === 0) {
                try {
                    const data = JSON.parse(listOut.text)
                    root.items = data.items || []
                } catch (e) {
                    root.items = []
                }
            }
            if (root._pendingReload) {
                root._pendingReload = false
                root.load()
            }
        }
    }

    Process {
        id: copyProc

        onExited: code => {
            if (code === 0) {
                root.copied()
                root.dismissed()
            }
        }
    }

    Process {
        id: deleteProc

        onExited: code => root.load()
    }

    Process {
        id: clearProc

        onExited: code => {
            root.selected = 0
            root.load()
        }
    }

    Process {
        id: pruneProc
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
        width: Math.min(560, parent.width - 32)
        height: Math.min(620, parent.height - 64)
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

        // Absorb clicks so they don't close the panel
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            AppBar {
                title: "Clipboard"
                showClose: true
                onCloseClicked: root.dismissed()

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.filtered.length + " items"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.labelMedium
                    font.family: T.font
                }

                M3Button {
                    Layout.alignment: Qt.AlignVCenter
                    variant: "text"
                    text: "Clear all"
                    onClicked: root.clearAll()
                }
            }

            // Search field
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                TextField {
                    id: search
                    anchors.fill: parent
                    placeholderText: "Search clipboard…"
                    color: T.onSurface
                    placeholderTextColor: T.onSurfaceVariant
                    selectionColor: T.secondaryContainerStrong
                    selectedTextColor: T.onSurface
                    font.pixelSize: T.bodyLarge
                    font.family: T.font
                    leftPadding: 42
                    rightPadding: root.query.length > 0 ? 42 : T.margin
                    onAccepted: root.copySelected()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.move(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.move(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.query.length > 0)
                                root.query = ""
                            else
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

            // History list
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: history
                    anchors.fill: parent
                    clip: true
                    spacing: T.gapSmall
                    model: root.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 400

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index

                        width: history.width
                        height: rowLayout.implicitHeight + 20
                        radius: T.radiusCard
                        color: index === root.selected ? T.secondaryContainerStrong
                             : (rowMouse.containsMouse ? T.surfaceContainerHigh : T.surfaceContainer)

                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyEntry(row.modelData.id)
                        }

                        RowLayout {
                            id: rowLayout
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            // Image thumbnail
                            Rectangle {
                                visible: row.modelData.kind === "image"
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 56
                                radius: 8
                                clip: true
                                color: T.surfaceContainerHigh

                                Image {
                                    anchors.fill: parent
                                    source: row.modelData.kind === "image" && row.modelData.path
                                            ? "file://" + row.modelData.path
                                            : ""
                                    sourceSize.width: 192
                                    sourceSize.height: 112
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.kind === "image"
                                          ? "Image"
                                          : (row.modelData.preview || "(empty)")
                                    color: T.onSurface
                                    font.pixelSize: T.bodyMedium
                                    font.family: T.font
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.metaText(row.modelData)
                                    color: T.onSurfaceVariant
                                    font.pixelSize: T.labelSmall
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }
                            }

                            M3IconButton {
                                Layout.alignment: Qt.AlignVCenter
                                size: 30
                                iconSize: 15
                                glyph: String.fromCodePoint(0xF01B4) // trash
                                onClicked: root.removeEntry(row.modelData.id)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.loading ? "Loading…" : "Clipboard is empty"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Auto-deletes after 7 days · ↑↓ navigate · Enter copy · Del delete"
                color: T.onSurfaceVariant
                font.pixelSize: T.labelSmall
                font.family: T.font
            }
        }
    }
}
