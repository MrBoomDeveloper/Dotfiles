import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    property var activePlayer: null
    property int position: 0

    readonly property bool hasMedia: root.activePlayer !== null
    readonly property bool hasLength: root.activePlayer !== null && root.activePlayer.length > 0

    visible: hasMedia
    color: Qt.rgba(0, 0, 0, 0.85)
    focusable: false

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 32

    readonly property real progress: {
        const p = root.activePlayer
        if (!p || !p.length)
            return 0
        return Math.max(0, Math.min(1, root.position / p.length))
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0)
            return "--:--"
        const s = Math.floor(seconds)
        const mins = Math.floor(s / 60)
        const secs = (s % 60).toString().padStart(2, "0")
        const hours = Math.floor(mins / 60)
        if (hours > 0)
            return hours + ":" + (mins % 60).toString().padStart(2, "0") + ":" + secs
        return mins + ":" + secs
    }

    function refresh() {
        const list = Mpris.players.values
        let best = null
        let bestScore = -1
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (!p.trackTitle)
                continue
            let score = 0
            if (p.isPlaying) score += 8
            if (p.trackArtist && p.trackArtist.length > 0) score += 4
            if (p.trackAlbum && p.trackAlbum.length > 0) score += 2
            if (p.canControl) score += 1
            if (score > bestScore) {
                bestScore = score
                best = p
            }
        }
        root.activePlayer = best
        if (best)
            root.position = best.position
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 24
                height: 24
                radius: 5
                color: Qt.rgba(1, 1, 1, 0.08)

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!root.hasMedia) return
                        if (detailPopup.popupOpen && !detailPopup.closing)
                            detailPopup.close()
                        else if (detailPopup.closing || detailPopup.popupOpen) {
                            detailPopup.close()
                            detailReopenTimer.restart()
                        } else {
                            detailPopup.open()
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF001)
                    color: "#6c7086"
                    font.pixelSize: 12
                    font.family: "Google Sans Flex"
                    visible: !root.activePlayer || root.activePlayer.trackArtUrl === ""
                }
            }

            Text {
                Layout.preferredWidth: 200
                text: {
                    const p = root.activePlayer
                    if (!p) return ""
                    const t = p.trackTitle || "Unknown"
                    const a = p.trackArtist || ""
                    return a ? t + "  —  " + a : t
                }
                color: "white"
                font.pixelSize: 11
                font.bold: true
                font.family: "Google Sans Flex"
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: root.hasMedia ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (!root.hasMedia) return
                        if (detailPopup.popupOpen && !detailPopup.closing)
                            detailPopup.close()
                        else if (detailPopup.closing || detailPopup.popupOpen) {
                            detailPopup.close()
                            detailReopenTimer.restart()
                        } else {
                            detailPopup.open()
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        Visualizer {
            active: root.activePlayer !== null && root.activePlayer.isPlaying
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            spacing: 8

            Text {
                text: root.formatTime(root.position)
                color: "#cdd6f4"
                font.pixelSize: 10
                font.family: "Google Sans Flex"
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 22
                visible: root.hasLength

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * root.progress
                    height: 4
                    radius: 2
                    color: '#ffc8f8'
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width - width) * root.progress
                    color: "white"
                    visible: root.activePlayer && root.activePlayer.canSeek
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    function seek(mx) {
                        const r = Math.max(0, Math.min(1, mx / width))
                        const p = root.activePlayer
                        if (p && p.length > 0) {
                            p.position = r * p.length
                            root.position = p.position
                        }
                    }

                    onPressed: mouse => seek(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seek(mouse.x) }
                }
            }

            Text {
                visible: root.hasLength
                text: root.formatTime(root.activePlayer ? root.activePlayer.length : 0)
                color: "#cdd6f4"
                font.pixelSize: 10
                font.family: "Google Sans Flex"
            }
        }

        RowLayout {
            spacing: 6

            MediaButton {
                glyph: String.fromCodePoint(0xF048)
                enabled: root.activePlayer && root.activePlayer.canGoPrevious
                onClicked: if (root.activePlayer) root.activePlayer.previous()
            }

            MediaButton {
                glyph: root.activePlayer && root.activePlayer.isPlaying
                       ? String.fromCodePoint(0xF04C)
                       : String.fromCodePoint(0xF04B)
                enabled: root.activePlayer && root.activePlayer.canTogglePlaying
                onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
            }

            MediaButton {
                glyph: String.fromCodePoint(0xF051)
                enabled: root.activePlayer && root.activePlayer.canGoNext
                onClicked: if (root.activePlayer) root.activePlayer.next()
            }
        }
    }

    // Detailed info popup with slide animation (hover based)
    PopupWindow {
        id: detailPopup

        property bool popupOpen: false
        property bool closing: false

        visible: popupOpen || closing
        color: "transparent"

        implicitWidth: 320
        implicitHeight: detailCol.implicitHeight + 28

        anchor.item: headerRow
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.Flip

        function open() {
            detailDismissTimer.stop()
            detailReopenTimer.stop()
            detailPopup.popupOpen = true
            detailPopup.closing = false
            detailCloseTimer.stop()
            detailPopup.visible = true
            slidePanel.slideY = -200
            detailSlideInTimer.restart()
        }

        function close() {
            if (detailPopup.closing || !detailPopup.popupOpen) return
            detailReopenTimer.stop()
            detailSlideInTimer.stop()
            detailPopup.closing = true
            detailCloseTimer.restart()
        }

        Timer {
            id: detailReopenTimer
            interval: 250
            onTriggered: detailPopup.open()
        }

        Connections {
            target: root
            function onHasMediaChanged() {
                if (!root.hasMedia) {
                    detailReopenTimer.stop()
                    detailPopup.close()
                }
            }
        }

        Timer {
            id: detailSlideInTimer
            interval: 0
            onTriggered: slidePanel.slideY = 0
        }

        Timer {
            id: detailCloseTimer
            interval: 0
            onTriggered: slidePanel.slideY = -200
        }

        Timer {
            id: detailDismissTimer
            interval: 220
            onTriggered: {
                detailReopenTimer.stop()
                detailPopup.visible = false
                detailPopup.closing = false
                detailPopup.popupOpen = false
            }
        }

        Component.onCompleted: slidePanel.slideY = -200

        Rectangle {
            id: slidePanel
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(0, 0, 0, 0.9)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 2

            property real slideY: 0
            transform: Translate { y: slidePanel.slideY }

            Behavior on slideY {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: detailCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: String.fromCodePoint(0xF108)
                        color: "#89b4fa"
                        font.pixelSize: 14
                        font.family: "Google Sans Flex"
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.activePlayer
                              ? (root.activePlayer.identity || "Unknown app")
                              : ""
                        color: "#cdd6f4"
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown") : ""
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.activePlayer && root.activePlayer.trackArtist !== ""
                    text: root.activePlayer ? (root.activePlayer.trackArtist || "") : ""
                    color: "#bac2de"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.activePlayer && root.activePlayer.trackAlbum !== ""
                    text: root.activePlayer ? (root.activePlayer.trackAlbum || "") : ""
                    color: "#a6adc8"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    component Visualizer: Item {
        id: viz
        property bool active: true

        Layout.minimumWidth: 80
        implicitWidth: 350
        implicitHeight: 24

        property var heights: {
            const arr = []
            for (let i = 0; i < 24; i++)
                arr.push(0.12)
            return arr
        }

        Timer {
            interval: 80
            repeat: true
            running: true
            onTriggered: {
                const arr = []
                for (let i = 0; i < 24; i++) {
                    const cur = viz.heights[i] || 0.12
                    const target = viz.active ? (0.08 + Math.random() * 0.92) : 0.10
                    arr.push(cur * 0.6 + target * 0.4)
                }
                viz.heights = arr
            }
        }

        Row {
            anchors.fill: parent
            spacing: 2

            Repeater {
                model: 24

                delegate: Item {
                    width: (viz.width - 2 * 23) / 24
                    height: viz.height

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(1, parent.height * (viz.heights[index] || 0.12))
                        radius: 1
                        color: '#f6c1ff'
                        opacity: viz.active ? 1.0 : 0.35

                        Behavior on height {
                            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: btn
        property string glyph: ""
        property bool enabled: true
        signal clicked()

        width: 26
        height: 26
        color: btn.enabled
               ? (btnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03))
               : "transparent"

        radius: 10
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: "#ffd0fa"
            font.pixelSize: 12
            font.family: "Google Sans Flex"
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: btn.enabled
            onClicked: btn.clicked()
        }
    }
}