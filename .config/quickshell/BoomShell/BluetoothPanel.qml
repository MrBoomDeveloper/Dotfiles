import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth

PanelWindow {
    id: root

    // External control
    property bool open: false

    signal dismissed()

    // Device whose action row is expanded (BluetoothDevice or null)
    property var activeDevice: null

    visible: open
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

    // Click outside → close
    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    // Panel background
    Rectangle {
        id: panel
        width: 360
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.9)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

        // Absorb clicks so they don't close the panel
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Bluetooth"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Close panel
                Rectangle {
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: 8
                    color: closeMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#cdd6f4"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissed()
                    }
                }
            }

            Toggle {
                id: btToggle
                label: "Bluetooth"
                checked: root.adapter ? root.adapter.enabled : false
                onToggled: value => {
                    if (root.adapter)
                        root.adapter.enabled = value
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ChipToggle {
                    label: "Discoverable"
                    checked: root.adapter ? root.adapter.discoverable : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.discoverable = value
                    }
                }

                ChipToggle {
                    label: "Pairable"
                    checked: root.adapter ? root.adapter.pairable : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.pairable = value
                    }
                }

                ChipToggle {
                    label: "Scan"
                    checked: root.adapter ? root.adapter.discovering : false
                    onToggled: value => {
                        if (root.adapter)
                            root.adapter.discovering = value
                    }
                }
            }

            ListView {
                id: deviceList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
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
                    height: content.implicitHeight + 12
                    radius: 8
                    color: device.connected ? Qt.rgba(1, 0.58, 0.89) : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            // Device icon (first letter)
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 8
                                color: device.connected ? '#ffd0fa' : '#382432'

                                Text {
                                    anchors.centerIn: parent
                                    text: device.name ? device.name.charAt(0).toUpperCase() : "?"
                                    color: device.connected ? "black" : '#f4cdf0'
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: device.name || device.address || "Unknown"
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: device.connected
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: deviceDelegate.subtitle
                                    color: device.connected ? "black" : '#c8a6c0'
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            // Connect / disconnect
                            Rectangle {
                                implicitWidth: actionText.implicitWidth + 16
                                implicitHeight: 26
                                radius: 6
                                color: device.connected
                                       ? Qt.rgba(0.82, 0.2, 0.3)
                                       : (actionMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.28) : Qt.rgba(1, 0.65, 0.89, 0.16))

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: device.connected ? "Disconnect" : (busy ? "…" : "Connect")
                                    color: device.connected ? '#fff2f5' : '#fa8994'
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleAction(device)
                                }
                            }

                            // Expand details
                            Rectangle {
                                implicitWidth: 26
                                implicitHeight: 26
                                radius: 6
                                color: expandMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.activeDevice === device ? "▾" : "▸"
                                    color: "#cdd6f4"
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: expandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeDevice = (root.activeDevice === device) ? null : device
                                }
                            }
                        }

                        // Expanded details / actions
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.activeDevice === device
                            spacing: 6

                            Text {
                                Layout.fillWidth: true
                                text: device.address
                                color: "#6c7086"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: device.batteryAvailable
                                text: "Battery: " + Math.round(device.battery * 100) + "%"
                                color: '#c8a6c0'
                                font.pixelSize: 11
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SmallButton {
                                    label: device.paired || device.bonded ? "Forget" : "Pair"
                                    active: false
                                    onClicked: {
                                        if (device.paired || device.bonded)
                                            device.forget()
                                        else
                                            device.pair()
                                    }
                                }

                                SmallButton {
                                    label: device.trusted ? "Untrust" : "Trust"
                                    active: device.trusted
                                    onClicked: device.trusted = !device.trusted
                                }

                                SmallButton {
                                    label: device.blocked ? "Unblock" : "Block"
                                    active: device.blocked
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
                    color: "#6c7086"
                    font.pixelSize: 13
                }
            }
        }
    }



    component SmallButton: Rectangle {
        id: smallButton
        property string label: ""
        property bool active: false
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 28
        radius: 6
        color: active
               ? Qt.rgba(1, 0.65, 0.89, 0.22)
               : (btnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03))
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Text {
            id: labelText
            anchors.centerIn: parent
            text: label
            color: active ? '#ffd0fa' : '#f4cdf0'
            font.pixelSize: 12
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: smallButton.clicked()
        }
    }

    component ChipToggle: Rectangle {
        id: chip
        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        Layout.fillWidth: true
        implicitHeight: 32
        radius: 6
        color: chip.checked
               ? Qt.rgba(1, 0.65, 0.89, 0.22)
               : (chipMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03))
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: chip.label
            color: chip.checked ? '#ffd0fa' : '#f4cdf0'
            font.pixelSize: 11
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled(!chip.checked)
        }
    }
}
