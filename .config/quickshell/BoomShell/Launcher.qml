import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "Theme.js" as T
import "MathEval.js" as M

// Application launcher: searches .desktop entries and launches them.
// Right-click opens a menu to hide an app or reveal its shortcut file.
PanelWindow {
    id: root

    // External control
    property bool open: false
    signal dismissed()
    signal launched()
    signal copied(string text)

    // Filter state
    property alias query: search.text
    property int selected: 0
    property bool closing: false
    property bool panelVisible: false
    property bool loading: false
    property var apps: []

    // Context menu state
    property bool menuOpen: false
    property var menuItem: null
    property real menuX: 0
    property real menuY: 0

    readonly property var filtered: {
        const q = root.query.trim().toLowerCase()
        const list = []
        for (let i = 0; i < root.apps.length; i++) {
            const app = root.apps[i]
            const name = String(app.name || "").toLowerCase()
            const comment = String(app.comment || "").toLowerCase()
            if (q.length === 0 || name.indexOf(q) >= 0 || comment.indexOf(q) >= 0)
                list.push(app)
        }
        return list
    }

    // Valid formula typed into the search field → { value, text }, else null.
    readonly property var mathResult: M.evaluate(root.query)

    function helper(args) {
        return ["python3", Quickshell.shellDir + "/launcher.py"].concat(args)
    }

    function copyMath() {
        if (!root.mathResult)
            return
        Quickshell.clipboardText = root.mathResult.text
        root.copied(root.mathResult.text)
        root.dismissed()
    }

    function load() {
        if (listProc.running)
            return
        root.loading = true
        listProc.exec(root.helper(["list"]))
    }

    function resolveIcon(icon) {
        if (!icon)
            return ""
        if (icon.indexOf("/") === 0)
            return "file://" + icon
        return Quickshell.iconPath(icon)
    }

    function move(delta) {
        if (root.filtered.length === 0)
            return
        root.selected = Math.max(0, Math.min(root.filtered.length - 1, root.selected + delta))
        list.positionViewAtIndex(root.selected, ListView.Contain)
    }

    function launchSelected() {
        const app = root.filtered[root.selected]
        if (app)
            root.launch(app)
    }

    function launch(app) {
        if (launchProc.running)
            return
        root.menuOpen = false
        launchProc.exec(root.helper(["launch", app.id]))
    }

    function openMenu(app, x, y) {
        root.menuItem = app
        root.menuX = Math.max(8, Math.min(x, panel.width - 220))
        root.menuY = Math.max(8, Math.min(y, panel.height - 84))
        root.menuOpen = true
    }

    function hideMenu() {
        root.menuOpen = false
        root.menuItem = null
    }

    function hideMenuSelected() {
        const app = root.menuItem
        if (!app)
            return
        root.menuOpen = false

        // Remove locally right away so the list and counter react instantly.
        const remaining = []
        for (let i = 0; i < root.apps.length; i++) {
            if (root.apps[i].id !== app.id)
                remaining.push(root.apps[i])
        }
        root.apps = remaining
        if (root.selected >= remaining.length)
            root.selected = Math.max(0, remaining.length - 1)
        scrollTimer.restart()

        if (!hideProc.running)
            hideProc.exec(root.helper(["hide", app.id]))
    }

    function revealMenuSelected() {
        const app = root.menuItem
        if (!app)
            return
        root.menuOpen = false
        if (!revealProc.running)
            revealProc.exec(root.helper(["reveal", app.id]))
        root.dismissed()
    }

    onQueryChanged: {
        root.selected = 0
        scrollTimer.restart()
    }

    onFilteredChanged: {
        if (root.selected >= root.filtered.length)
            root.selected = Math.max(0, root.filtered.length - 1)
    }

    onOpenChanged: {
        if (root.open) {
            root.closing = false
            root.panelVisible = true
            hideTimer.stop()
            // Park the panel below the screen without animating, then fly in.
            panel.sliding = false
            panel.slide = 1
            root.query = ""
            root.selected = 0
            root.menuOpen = false
            showTimer.restart()
            focusTimer.restart()
            scrollTimer.restart()
            root.load()
        } else if (root.panelVisible && !root.closing) {
            root.closing = true
            panel.sliding = true
            panel.slide = 1
            hideTimer.restart()
        }
    }

    Timer {
        id: showTimer
        interval: 0
        onTriggered: {
            panel.sliding = true
            panel.slide = 0
        }
    }

    // Window has to outlive the fly-out animation.
    Timer {
        id: hideTimer
        interval: 120
        onTriggered: {
            root.panelVisible = false
            root.closing = false
        }
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: search.forceActiveFocus()
    }

    Timer {
        id: scrollTimer
        interval: 0
        onTriggered: list.positionViewAtBeginning()
    }

    Process {
        id: listProc
        stdout: StdioCollector { id: listOut }

        onExited: code => {
            root.loading = false
            if (code === 0) {
                try {
                    const data = JSON.parse(listOut.text)
                    root.apps = data.apps || []
                } catch (e) {
                    root.apps = []
                }
            }
            root.selected = 0
            scrollTimer.restart()
        }
    }

    Process {
        id: launchProc

        onExited: code => {
            if (code === 0) {
                root.launched()
                root.dismissed()
            }
        }
    }

    Process {
        id: hideProc

        onExited: code => root.load()
    }

    Process {
        id: revealProc
    }

    visible: root.open || root.panelVisible
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
        enabled: root.open
        onClicked: root.dismissed()
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 32)
        height: Math.min(600, parent.height - 64)
        radius: T.radiusPanel
        color: T.surface
        border.color: T.outline
        border.width: 1

        // 0 = resting in the middle of the screen, 1 = parked below the bottom edge.
        property real slide: 1
        property bool sliding: false
        readonly property real slideDistance: (root.height + height) / 2 + 24
        transform: Translate { y: panel.slide * panel.slideDistance }

        Behavior on slide {
            enabled: panel.sliding
            NumberAnimation {
                duration: root.closing ? 110 : 160
                easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
            }
        }

        // Absorb clicks so they don't close the launcher
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            AppBar {
                title: "Apps"
                showClose: true
                onCloseClicked: root.dismissed()

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.filtered.length + " apps"
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
                    placeholderText: "Search apps…"
                    color: T.onSurface
                    placeholderTextColor: T.onSurfaceVariant
                    selectionColor: T.secondaryContainerStrong
                    selectedTextColor: T.onSurface
                    font.pixelSize: T.bodyLarge
                    font.family: T.font
                    leftPadding: 42
                    rightPadding: root.query.length > 0 ? 42 : T.margin
                    onAccepted: {
                        if (root.mathResult)
                            root.copyMath()
                        else
                            root.launchSelected()
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            root.move(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            root.move(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.menuOpen)
                                root.hideMenu()
                            else if (root.query.length > 0)
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

            // Live math: a valid formula turns Enter into "copy the answer".
            Rectangle {
                visible: root.mathResult !== null
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: T.radiusCard
                color: mathMouse.containsMouse ? T.secondaryContainerStrong : T.secondaryContainer
                border.color: T.outline
                border.width: 1

                MouseArea {
                    id: mathMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyMath()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 15
                        color: T.secondaryContainerStrong

                        Text {
                            anchors.centerIn: parent
                            text: "="
                            color: T.onSecondaryContainer
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            font.family: T.font
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.query.trim() + " = " + (root.mathResult ? root.mathResult.text : "")
                            color: T.onSurface
                            font.pixelSize: T.bodyLarge
                            font.weight: Font.Medium
                            font.family: T.font
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Enter copies the result"
                            color: T.onSurfaceVariant
                            font.pixelSize: T.labelSmall
                            font.family: T.font
                        }
                    }
                }
            }

            // Application list
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    spacing: T.gapSmall
                    model: root.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    cacheBuffer: 400

                    delegate: Rectangle {
                        id: appRow
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 56
                        radius: T.radiusCard
                        color: index === root.selected ? T.secondaryContainerStrong
                             : (appMouse.containsMouse ? T.surfaceContainerHigh : "transparent")

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                root.selected = appRow.index
                                if (mouse.button === Qt.RightButton) {
                                    const position = appRow.mapToItem(panel, mouse.x, mouse.y)
                                    root.openMenu(appRow.modelData, position.x, position.y)
                                } else {
                                    root.launch(appRow.modelData)
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32

                                IconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 28
                                    visible: appRow.modelData.icon !== ""
                                    source: root.resolveIcon(appRow.modelData.icon)
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 30
                                    height: 30
                                    radius: 8
                                    visible: appRow.modelData.icon === ""
                                    color: T.secondaryContainerStrong

                                    Text {
                                        anchors.centerIn: parent
                                        text: String(appRow.modelData.name || "?").charAt(0).toUpperCase()
                                        color: T.onSecondaryContainer
                                        font.pixelSize: 14
                                        font.family: T.font
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                Text {
                                    Layout.fillWidth: true
                                    text: appRow.modelData.name
                                    color: T.onSurface
                                    font.pixelSize: T.bodyLarge
                                    font.weight: Font.Medium
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: appRow.modelData.comment !== ""
                                    text: appRow.modelData.comment
                                    color: T.onSurfaceVariant
                                    font.pixelSize: T.labelSmall
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.filtered.length === 0
                    text: root.loading ? "Loading…" : "No apps found"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Right-click for options · ↑↓ navigate · Enter launch"
                color: T.onSurfaceVariant
                font.pixelSize: T.labelSmall
                font.family: T.font
            }
        }

        // Clicking anywhere else closes the context menu
        MouseArea {
            anchors.fill: parent
            visible: root.menuOpen
            z: 8
            onClicked: root.hideMenu()
        }

        Rectangle {
            id: contextMenu
            visible: root.menuOpen
            x: root.menuX
            y: root.menuY
            width: 212
            height: menuColumn.implicitHeight + 8
            radius: T.radiusCard
            color: T.surfaceContainerHighest
            border.color: T.outline
            border.width: 1
            z: 9

            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0

                MenuRow {
                    label: "Hide from launcher"
                    onClicked: root.hideMenuSelected()
                }

                MenuRow {
                    label: "Open shortcut folder"
                    onClicked: root.revealMenuSelected()
                }
            }
        }
    }

    component MenuRow: Rectangle {
        id: menuRow
        property string label: ""
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 6
        color: menuMouse.containsMouse ? T.secondaryContainerStrong : "transparent"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: menuRow.label
            color: T.onSurface
            font.pixelSize: T.bodyMedium
            font.family: T.font
        }

        MouseArea {
            id: menuMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: menuRow.clicked()
        }
    }
}
