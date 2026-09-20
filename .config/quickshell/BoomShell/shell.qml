import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications

Scope {
    id: root
    property bool startMenuOpen: false
    property bool wifiOpen: false
    property bool bluetoothOpen: false
    property bool calendarOpen: false
    property bool trayMenuOpen: false
    property var activeTrayItem: null
    property int activeTrayY: 0
    property var now: new Date()

    property var _pendingTray: null
    property int _pendingTrayY: 0

    property bool wifiOn: Networking.wifiEnabled
    property bool bluetoothOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

    readonly property var wifiDevice: {
        const devices = Networking.devices.values
        for (let i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi)
                return devices[i]
        return null
    }

    readonly property var connectedNetwork: {
        if (!root.wifiDevice)
            return null
        const values = root.wifiDevice.networks.values
        for (let i = 0; i < values.length; i++)
            if (values[i].connected)
                return values[i]
        return null
    }

    readonly property int wifiSignal: root.connectedNetwork ? root.connectedNetwork.signalStrength : 0

    function toggleWifi() {
        root.wifiOpen = !root.wifiOpen
        if (root.wifiOpen) {
            root.bluetoothOpen = false
            root.startMenuOpen = false
            root.calendarOpen = false
            root.trayMenuOpen = false
            root.activeTrayItem = null
        }
    }

    function toggleBluetooth() {
        root.bluetoothOpen = !root.bluetoothOpen
        if (root.bluetoothOpen) {
            root.wifiOpen = false
            root.startMenuOpen = false
            root.calendarOpen = false
            root.trayMenuOpen = false
            root.activeTrayItem = null
        }
    }

    function toggleStart() {
        root.startMenuOpen = !root.startMenuOpen
        if (root.startMenuOpen) {
            root.wifiOpen = false
            root.bluetoothOpen = false
            root.calendarOpen = false
            root.trayMenuOpen = false
            root.activeTrayItem = null
        }
    }

    function toggleCalendar() {
        root.calendarOpen = !root.calendarOpen
        if (root.calendarOpen) {
            root.wifiOpen = false
            root.bluetoothOpen = false
            root.startMenuOpen = false
            root.trayMenuOpen = false
            root.activeTrayItem = null
        }
    }

    function openTrayMenu(item, y) {
        if (item.hasMenu) {
            root.startMenuOpen = false
            root.wifiOpen = false
            root.bluetoothOpen = false
            root.calendarOpen = false

            if (root.activeTrayItem !== null) {
                // Previous open still dirty — force close then reopen
                root.trayMenuOpen = false
                root.activeTrayItem = null
                root._pendingTray = item
                root._pendingTrayY = y
                trayReopenTimer.restart()
            } else {
                root.activeTrayItem = item
                root.activeTrayY = y
                root.trayMenuOpen = true
            }
        } else {
            item.activate()
        }
    }

    Timer {
        id: trayReopenTimer
        interval: 250
        onTriggered: {
            root.activeTrayItem = root._pendingTray
            root.activeTrayY = root._pendingTrayY
            root.trayMenuOpen = true
        }
    }

    function openResources() {
        Quickshell.execDetached(["flatpak", "run", "net.nokyan.Resources"])
    }

    function openNemo() {
        Quickshell.execDetached(["nemo"])
    }

    // Clock
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    // Keyboard state (active layout + caps lock)
    Keyboard {
        id: keyboard
        onLayoutChanged: code => osd.show(String.fromCodePoint(0xF11C), code)
        onCapsChanged: on => osd.show(String.fromCodePoint(0xF023), "Caps Lock " + (on ? "ON" : "OFF"))
        onNumChanged: on => osd.show(String.fromCodePoint(0xF292), "Num Lock " + (on ? "ON" : "OFF"))
    }

    // Transient on-screen display for state changes
    Osd {
        id: osd
    }

    // Notification server — always running at root level
    NotificationServer {
        id: notifServer
        keepOnReload: true
    }

    // Toast popups for incoming notifications
    NotificationPopup {
        id: notifPopup
        notifServer: notifServer
    }

    PanelWindow {
        id: leftBar
        implicitWidth: 42
        color: Qt.rgba(0, 0, 0, 0.9)

        anchors {
            top: true
            left: true
            bottom: true
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 3

            Rectangle {
                id: startBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignHCenter
                radius: 8
                color: startBtnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.pixelSize: 22
                    color: '#ffd0fa'
                    font.family: "Google Sans Flex"
                }

                MouseArea {
                    id: startBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.startMenuOpen = !root.startMenuOpen
                        if (root.startMenuOpen) {
                            root.wifiOpen = false
                            root.bluetoothOpen = false
                            root.calendarOpen = false
                            root.trayMenuOpen = false
                            root.activeTrayItem = null
                        }
                    }
                }
            }


            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 38
                Layout.preferredHeight: wsList.implicitHeight + 8
                radius: 10
                color: Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Workspaces {
                    id: wsList
                    anchors.centerIn: parent
                }
            }

            Item { Layout.fillHeight: true }

            // Resources (CPU / RAM / storage)
            Resources {
                Layout.alignment: Qt.AlignHCenter
                onCpuClicked: root.openResources()
                onRamClicked: root.openResources()
                onStorageClicked: root.openNemo()
            }

            Item { Layout.fillHeight: true }

            // System tray
            Tray {
                id: tray
                Layout.alignment: Qt.AlignHCenter
                onOpenMenu: (item, y) => root.openTrayMenu(item, y)
            }

            // Caps lock indicator
            Rectangle {
                id: capsIndicator
                visible: keyboard.capsLock
                Layout.preferredWidth: 32
                Layout.preferredHeight: 24
                Layout.alignment: Qt.AlignHCenter
                radius: 6
                color: Qt.rgba(0.95, 0.55, 0.55, 0.25)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF023) // lock
                    color: "#f38ba8"
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "Google Sans Flex"
                }
            }

            // Clock button
            Rectangle {
                id: clockBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 46
                Layout.alignment: Qt.AlignHCenter
                radius: 8
                color: clockMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: -3

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(root.now.getHours()).padStart(2, "0")
                        color:  "#ffd0fa"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Google Sans Flex"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(root.now.getMinutes()).padStart(2, "0")
                        color:  "#ffd0fa"
                        font.pixelSize: 14
                        font.family: "Google Sans Flex"
                    }
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleCalendar()
                }
            }

            // Language indicator
            Rectangle {
                id: langIndicator
                Layout.preferredWidth: 32
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignHCenter
                radius: 6
                color: Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: keyboard.layoutCode
                    color: "#ffd0fa"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "Google Sans Flex"
                }
            }

            // Bluetooth button
            Rectangle {
                id: bluetoothBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignHCenter
                radius: 8
                color: bluetoothBtnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF293) // bluetooth
                    font.pixelSize: 15
                    color: "#ffd0fa"
                    font.family: "Google Sans Flex"
                }

                // Slash overlay when bluetooth is off
                Rectangle {
                    visible: !root.bluetoothOn
                    width: 22
                    height: 2
                    radius: 1
                    anchors.centerIn: parent
                    rotation: -45
                    color: "#f38ba8"
                }

                MouseArea {
                    id: bluetoothBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleBluetooth()
                }
            }

            // WiFi button
            Rectangle {
                id: wifiBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.bottomMargin: 1
                Layout.alignment: Qt.AlignHCenter
                radius: 8
                color: wifiBtnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF1EB) // nerd font: wifi
                    font.pixelSize: 13
                    color: "#ffd0fa"
                    font.family: "Google Sans Flex"
                }

                // Slash overlay when wifi is off
                Rectangle {
                    visible: !root.wifiOn
                    width: 22
                    height: 2
                    radius: 1
                    anchors.centerIn: parent
                    rotation: -45
                    color: "#f38ba8"
                }

                MouseArea {
                    id: wifiBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleWifi()
                }
            }
        }
    }

    MediaBar {
    }

    // Flag-file watchers for global shortcuts
    Process {
        id: flagProc
        onExited: code => {
            switch (code) {
            case 10: root.toggleWifi(); break
            case 20: root.toggleBluetooth(); break
            case 30: root.toggleStart(); break
            case 40: root.toggleCalendar(); break
            }
        }
    }

    Timer {
        id: flagTimer
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (flagProc.running) return
            flagProc.exec(["sh", "-c",
                'if [ -f /tmp/buff_toggle_wifi ]; then ' +
                'rm -f /tmp/buff_toggle_wifi /tmp/buff_toggle_bluetooth /tmp/buff_toggle_start /tmp/buff_toggle_calendar; ' +
                'exit 10; ' +
                'elif [ -f /tmp/buff_toggle_bluetooth ]; then ' +
                'rm -f /tmp/buff_toggle_wifi /tmp/buff_toggle_bluetooth /tmp/buff_toggle_start /tmp/buff_toggle_calendar; ' +
                'exit 20; ' +
                'elif [ -f /tmp/buff_toggle_start ]; then ' +
                'rm -f /tmp/buff_toggle_wifi /tmp/buff_toggle_bluetooth /tmp/buff_toggle_start /tmp/buff_toggle_calendar; ' +
                'exit 30; ' +
                'elif [ -f /tmp/buff_toggle_calendar ]; then ' +
                'rm -f /tmp/buff_toggle_wifi /tmp/buff_toggle_bluetooth /tmp/buff_toggle_start /tmp/buff_toggle_calendar; ' +
                'exit 40; fi'])
        }
    }

    function closeAllPanels() {
        root.startMenuOpen = false
        root.wifiOpen = false
        root.bluetoothOpen = false
        root.calendarOpen = false
        root.trayMenuOpen = false
        root.activeTrayItem = null
    }

    Start {
        open: root.startMenuOpen
        notifServer: notifServer
        onDismissed: root.closeAllPanels()
        onOsd: (icon, text) => osd.show(icon, text)
    }

    WifiPanel {
        open: root.wifiOpen
        onDismissed: root.closeAllPanels()
    }

    BluetoothPanel {
        open: root.bluetoothOpen
        onDismissed: root.closeAllPanels()
    }

    CalendarPanel {
        id: calendar
        open: root.calendarOpen
        anchorItem: clockBtn
        onDismissed: root.closeAllPanels()
    }

    TrayMenu {
        item: root.trayMenuOpen ? root.activeTrayItem : null
        anchorItem: tray
        anchorY: root.activeTrayY
        onDismissed: root.closeAllPanels()
    }
}