import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "Theme.js" as T

PanelWindow {
    id: root

    // External control
    property bool open: false
    property bool closing: false

    signal dismissed()

    // Device whose action row is expanded (BluetoothDevice or null)
    property var activeDevice: null

    onOpenChanged: {
        if (root.open) {
            dismissTimer.stop()
            root.visible = true
            root.closing = false
            closeSlideTimer.stop()
            panel.slideX = -360
            slideInTimer.restart()
        } else if (!root.closing && root.visible) {
            root.activeDevice = null
            slideInTimer.stop()
            root.closing = true
            closeSlideTimer.restart()
            dismissTimer.restart()
        }
    }

    Timer {
        id: slideInTimer
        interval: 0
        onTriggered: panel.slideX = 0
    }

    Timer {
        id: closeSlideTimer
        interval: 0
        onTriggered: panel.slideX = -360
    }

    Timer {
        id: dismissTimer
        interval: 130
        onTriggered: {
            root.visible = false
            root.closing = false
            root.dismissed()
        }
    }

    Component.onCompleted: panel.slideX = -360

    visible: false
    color: "transparent"
    focusable: false

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Default adapter
    readonly property var adapter: Bluetooth.defaultAdapter

    // Sorted device list: connected first, then paired, then by name
    readonly property var devices: {
        const list = []
        const values = Bluetooth.devices.values
        for (let i = 0; i < values.length; i++)
            list.push(values[i])
        list.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        return list
    }

    function handleAction(device) {
        if (device.connected) {
            device.disconnect()
        } else if (device.paired || device.bonded) {
            device.connect()
        } else {
            device.pair()
        }
    }

    // Maximum height for the device list before it starts scrolling
    readonly property real maxListHeight: Math.max(200, root.height * 0.55)

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    // Panel background — M3 bottom sheet, content stacks upward from the bottom
    Rectangle {
        id: panel
        width: 340
        anchors {
            bottom: parent.bottom
            left: parent.left
        }
        height: Math.min(parent.height, contentLayout.implicitHeight + 2 * T.margin)
        radius: 24
        bottomLeftRadius: 0
        bottomRightRadius: 0
        color: T.surface
        border.color: T.outline
        border.width: 1

        property real slideX: -360
        transform: Translate { x: panel.slideX }

        Behavior on slideX {
            NumberAnimation {
                duration: root.closing ? 100 : 120
                easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
            }
        }

        // Absorb clicks so they don't close the panel
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: contentLayout
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            AppBar {
                title: "Bluetooth"
                showClose: true
                onCloseClicked: root.dismissed()

                Toggle {
                    id: btToggle
                    compact: true
                    checked: root.adapter ? root.adapter.enabled : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.enabled = value
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: T.gap

                M3Chip {
                    label: "Discoverable"
                    selected: root.adapter ? root.adapter.discoverable : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.discoverable = value
                    }
                }

                M3Chip {
                    label: "Pairable"
                    selected: root.adapter ? root.adapter.pairable : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.pairable = value
                    }
                }

                M3Chip {
                    label: "Scan"
                    selected: root.adapter ? root.adapter.discovering : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.discovering = value
                    }
                }
            }

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(deviceList.contentHeight, 80), root.maxListHeight)
                clip: true
                spacing: T.gapSmall
                model: root.devices

                delegate: Rectangle {
                    id: deviceDelegate

                    required property var modelData
                    readonly property var device: modelData
                    readonly property bool busy: device.state === BluetoothDeviceState.Connecting ||
                                                 device.state === BluetoothDeviceState.Disconnecting
                    readonly property string subtitle: {
                        if (device.connected) return "Connected"
                        if (device.pairing) return "Pairing…"
                        if (device.state === BluetoothDeviceState.Connecting) return "Connecting…"
                        if (device.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…"
                        if (device.paired || device.bonded) return "Paired"
                        return "Not paired"
                    }

                    width: deviceList.width
                    height: contentCol.implicitHeight + 2 * T.margin
                    radius: T.radiusCard
                    color: device.connected ? T.secondaryContainer
                                            : (delegateMouse.containsMouse ? T.surfaceContainer : "transparent")

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeDevice = (root.activeDevice === device) ? null : device
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: T.margin
                        spacing: T.gapLarge

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: T.gap

                            // Device avatar (first letter)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 32
                                height: 32
                                radius: 16
                                color: device.connected ? T.primaryContainer : T.surfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: device.name ? device.name.charAt(0).toUpperCase() : "?"
                                    color: device.connected ? T.onPrimaryContainer : T.onSecondaryContainer
                                    font.pixelSize: T.titleMedium
                                    font.weight: Font.Medium
                                    font.family: T.font
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: device.name || device.address || "Unknown"
                                    color: device.connected ? T.onSecondaryContainer : T.onSurface
                                    font.pixelSize: T.titleMedium
                                    font.weight: Font.Medium
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: deviceDelegate.subtitle
                                    color: T.onSurfaceVariant
                                    font.pixelSize: T.bodyMedium
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }
                            }

                            M3Button {
                                Layout.alignment: Qt.AlignVCenter
                                compact: true
                                variant: device.connected ? "error" : "tonal"
                                text: device.connected ? "Disconnect" : (deviceDelegate.busy ? "…" : "Connect")
                                onClicked: root.handleAction(device)
                            }

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: root.activeDevice === device
                                      ? String.fromCodePoint(0xF013F) // chevron-up
                                      : String.fromCodePoint(0xF0140) // chevron-down
                                color: T.onSurfaceVariant
                                font.pixelSize: 14
                                font.family: T.font
                            }
                        }

                        // Expanded details / actions
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.activeDevice === device
                            spacing: T.gap

                            Text {
                                Layout.fillWidth: true
                                text: device.address
                                color: T.onSurfaceVariant
                                font.pixelSize: T.bodySmall
                                font.family: T.font
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: device.batteryAvailable
                                text: "Battery: " + Math.round(device.battery * 100) + "%"
                                color: T.onSurfaceVariant
                                font.pixelSize: T.bodySmall
                                font.family: T.font
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: T.gap

                                M3Button {
                                    Layout.fillWidth: true
                                    variant: (device.paired || device.bonded) ? "outlined" : "tonal"
                                    text: (device.paired || device.bonded) ? "Forget" : "Pair"
                                    onClicked: {
                                        if (device.paired || device.bonded)
                                            device.forget()
                                        else
                                            device.pair()
                                    }
                                }

                                M3Button {
                                    Layout.fillWidth: true
                                    variant: device.trusted ? "tonal" : "outlined"
                                    text: device.trusted ? "Untrust" : "Trust"
                                    onClicked: device.trusted = !device.trusted
                                }

                                M3Button {
                                    Layout.fillWidth: true
                                    variant: device.blocked ? "error" : "outlined"
                                    text: device.blocked ? "Unblock" : "Block"
                                    onClicked: device.blocked = !device.blocked
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: deviceList.count === 0
                    text: root.adapter ? "No devices found" : "No Bluetooth adapter"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }
        }
    }
}
