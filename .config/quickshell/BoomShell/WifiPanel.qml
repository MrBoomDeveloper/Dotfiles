import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Networking
import "Theme.js" as T

PanelWindow {
    id: root

    // External control
    property bool open: false
    property bool closing: false

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
        if (root.open) {
            dismissTimer.stop()
            root.visible = true
            root.closing = false
            closeSlideTimer.stop()
            panel.slideX = -360
            slideInTimer.restart()
        } else if (!root.closing && root.visible) {
            root.activeNetwork = null
            root.password = ""
            root.showPassword = false
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
        interval: 260
        onTriggered: {
            root.visible = false
            root.closing = false
            root.dismissed()
        }
    }

    Component.onCompleted: panel.slideX = -360

    visible: false
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

    // Maximum height for the network list before it starts scrolling
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
                duration: root.closing ? 200 : 240
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
                title: "Wi-Fi"
                showClose: true
                onCloseClicked: root.dismissed()

                Toggle {
                    id: wifiToggle
                    compact: true
                    checked: Networking.wifiEnabled
                    onToggled: value => Networking.wifiEnabled = value
                }
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
                Layout.leftMargin: T.margin
                visible: root.connectedNetwork !== null
                text: root.connectedNetwork ? "Connected to " + root.connectedNetwork.name : ""
                color: T.onSurfaceVariant
                font.pixelSize: T.labelMedium
                font.family: T.font
                elide: Text.ElideRight
            }

            ListView {
                id: netList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Math.max(netList.contentHeight, 80), root.maxListHeight)
                clip: true
                spacing: T.gapSmall
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
                    height: contentCol.implicitHeight + 2 * T.margin
                    radius: T.radiusCard
                    color: net.connected ? T.secondaryContainer
                                        : (delegateMouse.containsMouse ? T.surfaceContainer : "transparent")

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (!net.connected && root.activeNetwork !== net) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!net.connected && root.activeNetwork !== net)
                                root.handleAction(net)
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: T.margin
                        spacing: T.gapLarge

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: T.gap

                            // Signal strength
                            Item {
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: 18
                                implicitHeight: 18

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Repeater {
                                        model: 4
                                        delegate: Item {
                                            width: 3
                                            height: 18

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: parent.width
                                                height: 5 + index * 3
                                                radius: 1.5
                                                color: index < netDelegate.sigLevel ? T.primary
                                                     : Qt.rgba(1, 1, 1, 0.24)
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: net.name || "Unknown"
                                    color: net.connected ? T.onSecondaryContainer : T.onSurface
                                    font.pixelSize: T.titleMedium
                                    font.weight: Font.Medium
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: netDelegate.subtitle
                                    color: T.onSurfaceVariant
                                    font.pixelSize: T.bodyMedium
                                    font.family: T.font
                                    elide: Text.ElideRight
                                }
                            }

                            M3Button {
                                Layout.alignment: Qt.AlignVCenter
                                visible: net.known && !net.connected
                                compact: true
                                variant: "text"
                                text: "Forget"
                                onClicked: net.forget()
                            }

                            M3Button {
                                Layout.alignment: Qt.AlignVCenter
                                compact: true
                                variant: net.connected ? "error" : "tonal"
                                text: net.connected ? "Disconnect" : (netDelegate.isConnecting ? "…" : "Connect")
                                onClicked: root.handleAction(net)
                            }
                        }

                        // Password entry — M3 filled text field
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.activeNetwork === net
                            spacing: T.gap

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: T.gap

                                TextField {
                                    id: pskField
                                    Layout.fillWidth: true
                                    placeholderText: "Password"
                                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                    color: T.onSurface
                                    placeholderTextColor: T.onSurfaceVariant
                                    selectionColor: T.secondaryContainerStrong
                                    selectedTextColor: T.onSurface
                                    font.pixelSize: T.bodyLarge
                                    font.family: T.font
                                    leftPadding: T.margin
                                    rightPadding: T.margin
                                    implicitHeight: 44
                                    text: root.password
                                    onTextChanged: root.password = text
                                    onAccepted: root.connectWithPassword(net)
                                    onVisibleChanged: if (visible) forceActiveFocus()

                                    background: Rectangle {
                                        radius: 4
                                        color: T.surfaceContainerHigh

                                        Rectangle {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                bottom: parent.bottom
                                            }
                                            height: pskField.activeFocus ? 2 : 1
                                            color: pskField.activeFocus ? T.primary : T.outline
                                        }
                                    }
                                }

                                M3IconButton {
                                    Layout.alignment: Qt.AlignVCenter
                                    glyph: root.showPassword
                                           ? String.fromCodePoint(0xF070) // eye-slash
                                           : String.fromCodePoint(0xF06E) // eye
                                    iconSize: 18
                                    onClicked: root.showPassword = !root.showPassword
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: T.gap

                                M3Button {
                                    variant: "text"
                                    text: "Cancel"
                                    onClicked: {
                                        root.activeNetwork = null
                                        root.password = ""
                                    }
                                }

                                M3Button {
                                    variant: "filled"
                                    text: "Connect"
                                    enabled: root.password.length > 0
                                    onClicked: root.connectWithPassword(net)
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: netList.count === 0
                    text: root.wifiDevice ? "No networks found" : "No Wi-Fi device"
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }
        }
    }
}
