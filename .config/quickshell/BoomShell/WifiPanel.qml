import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking

PanelWindow {
    id: root

    // External control
    property bool open: false

    signal dismissed()

    // Network whose password prompt is expanded (WifiNetwork or null)
    property var activeNetwork: null
    property string password: ""
    property bool showPassword: false

    onActiveNetworkChanged: {
        if (!root.activeNetwork)
            root.showPassword = false
    }

    onOpenChanged: {
        if (!root.open) {
            root.activeNetwork = null
            root.password = ""
            root.showPassword = false
        }
    }

    visible: open
    color: "transparent"
    focusable: root.activeNetwork !== null

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // The WiFi device, if any
    readonly property var wifiDevice: {
        const devices = Networking.devices.values
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i]
        }
        return null
    }

    // Sorted list of networks: connected first, then by signal strength
    readonly property var networks: {
        if (!root.wifiDevice)
            return []
        const list = []
        const values = root.wifiDevice.networks.values
        for (let i = 0; i < values.length; i++)
            list.push(values[i])
        list.sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        return list
    }

    // Currently connected network
    readonly property var connectedNetwork: {
        if (!root.wifiDevice)
            return null
        const values = root.wifiDevice.networks.values
        for (let i = 0; i < values.length; i++) {
            if (values[i].connected)
                return values[i]
        }
        return null
    }

    function securityLabel(sec) {
        switch (sec) {
        case WifiSecurityType.Open: return "Open"
        case WifiSecurityType.Owe: return "Enhanced open"
        case WifiSecurityType.Sae: return "WPA3"
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3"
        case WifiSecurityType.Wpa2Psk: return "WPA2"
        case WifiSecurityType.WpaPsk: return "WPA"
        case WifiSecurityType.Wpa2Eap: return "WPA2 Enterprise"
        case WifiSecurityType.WpaEap: return "WPA Enterprise"
        case WifiSecurityType.StaticWep: return "WEP"
        case WifiSecurityType.DynamicWep: return "WEP"
        case WifiSecurityType.Leap: return "LEAP"
        default: return "Secured"
        }
    }

    function needsPsk(net) {
        return net.security !== WifiSecurityType.Open &&
               net.security !== WifiSecurityType.Owe
    }

    function handleAction(net) {
        if (net.connected ||
            net.state === ConnectionState.Connecting ||
            net.state === ConnectionState.Disconnecting) {
            net.disconnect()
            root.activeNetwork = null
            root.password = ""
            return
        }

        // Unknown secured network → ask for a password
        if (root.needsPsk(net) && !net.known) {
            if (root.activeNetwork === net) {
                root.activeNetwork = null
                root.password = ""
            } else {
                root.activeNetwork = net
                root.password = ""
            }
            return
        }

        net.connect()
        root.activeNetwork = null
        root.password = ""
    }

    function connectWithPassword(net) {
        if (root.password.length === 0)
            return
        net.connectWithPsk(root.password)
        root.activeNetwork = null
        root.password = ""
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
                    text: "Wi-Fi"
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
                id: wifiToggle
                label: "Wi-Fi"
                checked: Networking.wifiEnabled
                onToggled: value => Networking.wifiEnabled = value
            }

            Toggle {
                id: scanToggle
                label: "Scan for networks"
                checked: root.wifiDevice ? root.wifiDevice.scannerEnabled : false
                onToggled: value => {
                    if (root.wifiDevice)
                        root.wifiDevice.scannerEnabled = value
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.connectedNetwork !== null
                text: root.connectedNetwork ? "Connected to " + root.connectedNetwork.name : ""
                color: '#e7bbd7'
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            ListView {
                id: netList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: root.networks

                delegate: Rectangle {
                    id: netDelegate

                    required property var modelData
                    readonly property var net: modelData
                    readonly property bool isConnecting: net.state === ConnectionState.Connecting || net.state === ConnectionState.Disconnecting
                    readonly property int sigLevel: Math.min(4, Math.max(0, Math.round(net.signalStrength / 25)))
                    readonly property string subtitle: {
                        if (net.connected) return "Connected"
                        if (net.state === ConnectionState.Connecting) return "Connecting…"
                        if (net.state === ConnectionState.Disconnecting) return "Disconnecting…"
                        return (net.known ? "Saved · " : "") + root.securityLabel(net.security)
                    }

                    width: netList.width
                    height: content.implicitHeight + 12
                    radius: 8
                    color: net.connected ? Qt.rgba(1, 0.58, 0.89) : Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        id: content
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            // Signal strength bars
                            Row {
                                spacing: 2
                                Layout.alignment: Qt.AlignVCenter

                                Repeater {
                                    model: 4
                                    delegate: Rectangle {
                                        width: 3
                                        height: 4 + index * 3
                                        radius: 1
                                        anchors.bottom: parent.bottom
                                        color: index < netDelegate.sigLevel ? "#a6e3a1" : "#45475a"
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: net.name || "Unknown"
                                    color: net.connected ? "black" : "white"
                                    font.pixelSize: 13
                                    font.bold: net.connected
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: netDelegate.subtitle
                                    color: net.connected ? "black" : '#c8a6c0'
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            // Forget (saved networks only)
                            Rectangle {
                                visible: net.known
                                implicitWidth: forgetText.implicitWidth + 14
                                implicitHeight: 26
                                radius: 6
                                color: forgetMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(0, 0, 0, 0.65)

                                Text {
                                    id: forgetText
                                    anchors.centerIn: parent
                                    text: "Forget"
                                    color: "#cdd6f4"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: forgetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: net.forget()
                                }
                            }

                            // Connect / disconnect
                            Rectangle {
                                implicitWidth: actionText.implicitWidth + 16
                                implicitHeight: 26
                                radius: 6
                                color: net.connected
                                       ? Qt.rgba(0.82, 0.2, 0.3)
                                       : (actionMouse.containsMouse ? Qt.rgba(0.55, 0.65, 1.0, 0.28) : Qt.rgba(0.55, 0.65, 1.0, 0.16))

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: net.connected ? "Disconnect" : (isConnecting ? "…" : "Connect")
                                    color: net.connected ? '#fff2f5' : '#fa8994'
                                    font.pixelSize: 12
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.handleAction(net)
                                }
                            }
                        }

                        // Password entry
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.activeNetwork === net
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                TextField {
                                    id: pskField
                                    Layout.fillWidth: true
                                    placeholderText: "Password"
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    color: "white"
                                    placeholderTextColor: "#6c7086"
                                    font.pixelSize: 13
                                    text: root.password
                                    onTextChanged: root.password = text
                                    onAccepted: root.connectWithPassword(net)
                                    onVisibleChanged: if (visible) forceActiveFocus()

                                    background: Rectangle {
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        border.color: "#89b4fa"
                                        border.width: 1
                                    }
                                }

                                // Show / hide password
                                Rectangle {
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    radius: 6
                                    color: eyeMouse.containsMouse
                                           ? Qt.rgba(1, 1, 1, 0.15)
                                           : Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.showPassword
                                              ? String.fromCodePoint(0xF070) // eye-slash
                                              : String.fromCodePoint(0xF06E) // eye
                                        color: "#cdd6f4"
                                        font.pixelSize: 15
                                    }

                                    MouseArea {
                                        id: eyeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.showPassword = !root.showPassword
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: 6
                                    color: cancelMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        color: "#cdd6f4"
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: cancelMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeNetwork = null
                                            root.password = ""
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 30
                                    radius: 6
                                    color: connectMouse.containsMouse ? Qt.rgba(0.55, 0.65, 1.0, 0.38) : Qt.rgba(0.55, 0.65, 1.0, 0.2)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: "#89b4fa"
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: connectMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.connectWithPassword(net)
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: netList.count === 0
                    text: root.wifiDevice ? "No networks found" : "No Wi-Fi device"
                    color: "#6c7086"
                    font.pixelSize: 13
                }
            }
        }
    }


}
