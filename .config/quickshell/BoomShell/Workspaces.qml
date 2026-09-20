import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

ColumnLayout {
    id: root
    spacing: 0

    // Currently open special workspace
    property string openSpecialName: ""

    // Workspace preview (shown on long hover)
    property var previewWorkspace: null
    property int previewY: 0
    property bool previewVisible: false

    Timer {
        id: showTimer
        interval: 600
        repeat: false
        onTriggered: root.previewVisible = true
    }

    Timer {
        id: hideTimer
        interval: 300
        repeat: false
        onTriggered: {
            root.previewVisible = false
            root.previewWorkspace = null
        }
    }

    function enterPreview(ws, y) {
        hideTimer.stop()
        root.previewWorkspace = ws
        root.previewY = y
        root.previewVisible = false
        showTimer.restart()
    }

    function leavePreview() {
        showTimer.stop()
        hideTimer.restart()
    }

    // Map special workspace names to nerd-font glyphs
    function specialIcon(name) {
        const n = String(name).replace("special:", "").toLowerCase()
        if (n === "telegram") return String.fromCodePoint(0xF1D8) // paper-plane
        if (n === "vpn")     return String.fromCodePoint(0xF132)  // shield
        if (n === "music")   return String.fromCodePoint(0xF001)  // music note
        return ""
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activespecial") {
                // "special:name,monitor" or ",monitor" when closed
                root.openSpecialName = event.data.split(",")[0]
            }
        }
    }

    // Sorted list: numbered first, then special
    readonly property var sortedWorkspaces: {
        const list = []
        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
            list.push(Hyprland.workspaces.values[i])
        }

        list.sort((a, b) => {
            const aSpecial = a.id < 0 || a.name.startsWith("special")
            const bSpecial = b.id < 0 || b.name.startsWith("special")

            // Numbered come before special
            if (aSpecial !== bSpecial)
                return aSpecial ? 1 : -1

            // Inside group — sort by id
            return a.id - b.id
        })

        return list
    }

    Repeater {
        model: root.sortedWorkspaces

        delegate: Rectangle {
            id: wsBtn

            required property var modelData
            required property int index

            readonly property bool isSpecial: modelData.id < 0 || modelData.name.startsWith("special")
            readonly property bool isFocused: modelData.focused
            readonly property bool isActive:  modelData.active
            readonly property bool isUrgent:  modelData.urgent
            readonly property bool hovered: wsMouse.containsMouse

            // Is this special currently open?
            readonly property bool isOpen: isSpecial && (
                root.openSpecialName === modelData.name ||
                root.openSpecialName === modelData.name.replace("special:", "") ||
                modelData.active ||
                modelData.focused
            )

            implicitWidth: 32
            implicitHeight: 32
            radius: 5

            color: {
                if (isSpecial) {
                    if (isOpen) return "#cba6f7"
                    if (isUrgent) return "#f38ba8"
                    if (hovered) return Qt.rgba(1, 1, 1, 0.15)
                    return '#00000000'
                } else {
                    if (isFocused) return '#ffbff9'
                    if (isUrgent)  return "#503250"
                    if (hovered)   return Qt.rgba(1, 1, 1, 0.15)
                    return '#00000000'
                }
            }

            opacity: isSpecial && !isOpen ? 0.7 : 1.0

            // Numbered workspace text
            Text {
                visible: !isSpecial
                anchors.centerIn: parent
                text: modelData.id
                color: (isFocused || isUrgent) ? '#2e1e2c' : '#f4cdef'
                font.pixelSize: 14
                font.bold: isFocused
                font.family: "Google Sans Flex"
            }

            // Special workspace text (icon glyph or first letter)
            Text {
                id: specialText
                visible: isSpecial
                anchors.centerIn: parent
                property string glyph: root.specialIcon(modelData.name)
                text: glyph !== "" ? glyph
                    : (modelData.name.replace("special:", "").charAt(0).toUpperCase() || "S")
                color: (isOpen || isUrgent) ? '#2d1e2e' : '#f4cded'
                font.pixelSize: glyph !== "" ? 16 : 12
                font.bold: isOpen
                font.family: "Google Sans Flex"
            }

            // Occupied dot
            Rectangle {
                visible: modelData.toplevels.count > 0 && !isFocused && !isOpen
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 2
                width: 4
                height: 4
                radius: 2
                color: "#a6e3a1"
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: root.enterPreview(modelData, wsBtn.y)
                onExited: root.leavePreview()

                onClicked: {
                    if (isSpecial) {
                        const name = modelData.name.startsWith("special:")
                            ? modelData.name.slice(8)
                            : modelData.name
                        Hyprland.dispatch('hl.dsp.workspace.toggle_special("' + name + '")')
                    } else {
                        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + modelData.id + ', on_current_monitor = true })')
                    }
                }
            }
        }
    }
}