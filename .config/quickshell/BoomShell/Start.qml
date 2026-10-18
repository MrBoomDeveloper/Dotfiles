import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire

PanelWindow {
    id: root

    // External control
    property bool open: false
    property bool doNotDisturb: false
    required property var notifServer

    function resolveIcon(icon) {
        if (!icon)
            return "";
        if (icon.indexOf("/") >= 0 || icon.indexOf("file:") === 0)
            return icon;
        return Quickshell.iconPath(icon);
    }

    signal dismissed

    // Request an on-screen OSD (icon glyph + label) for a state change.
    signal osd(string icon, string text)

    // Request the Wi-Fi / Bluetooth panels
    signal wifiRequested
    signal bluetoothRequested

    // Quick tiles with actions
    readonly property var quickTiles: [
        {
            icon: String.fromCodePoint(0xF011),
            label: "Power",
            action: ["wlogout"]
        }
    ]

    function executeAction(action) {
        Quickshell.execDetached(action);
    }

    // Audio state
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: root.sink && root.sink.ready && root.sink.audio ? root.sink.audio.muted : false
    readonly property real volume: root.sink && root.sink.ready && root.sink.audio ? root.sink.audio.volume : 0

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool sourceMuted: root.source && root.source.ready && root.source.audio ? root.source.audio.muted : false
    readonly property real sourceVolume: root.source && root.source.ready && root.source.audio ? root.source.audio.volume : 0

    readonly property var sinks: {
        const list = [];
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (!n.isStream && n.isSink)
                list.push(n);
        }
        return list;
    }

    readonly property var sources: {
        const list = [];
        const nodes = Pipewire.nodes.values;
        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i];
            if (!n.isStream && !n.isSink && n.audio)
                list.push(n);
        }
        return list;
    }

    // Wi-Fi / Bluetooth state for the wide quick tiles
    readonly property bool wifiOn: Networking.wifiEnabled

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var connectedNetwork: {
        if (!root.wifiDevice)
            return null;
        const values = root.wifiDevice.networks.values;
        for (let i = 0; i < values.length; i++) {
            if (values[i].connected)
                return values[i];
        }
        return null;
    }

    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: root.btAdapter ? root.btAdapter.enabled : false

    readonly property var connectedBtDevice: {
        const values = Bluetooth.devices.values;
        for (let i = 0; i < values.length; i++) {
            if (values[i].connected)
                return values[i];
        }
        return null;
    }

    // Notifications on volume / mute change (armed after startup to skip the
    // initial bind change).
    property bool _notifyArmed: false

    Timer {
        id: armTimer
        interval: 2000
        repeat: false
        running: true
        onTriggered: root._notifyArmed = true
    }

    Timer {
        id: volNotifyTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.osd(root.muted ? String.fromCodePoint(0xF026) : String.fromCodePoint(0xF028), Math.round(root.volume * 100) + "%");
        }
    }

    onVolumeChanged: {
        if (root._notifyArmed)
            volNotifyTimer.restart();
    }

    onMutedChanged: {
        if (root._notifyArmed)
            root.osd(root.muted ? String.fromCodePoint(0xF026) : String.fromCodePoint(0xF028), root.muted ? "Muted" : "Unmuted");
    }

    visible: open
    color: "transparent"
    focusable: false

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

    Brightness {
        id: brightness
    }

    // Bind the default sink/source so their volume and mute properties work.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    // Menu panel
    Rectangle {
        id: menuPanel
        width: 360
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
            topMargin: 0
            bottomMargin: 0
            leftMargin: 0
        }
        radius: 12
        color: '#e6000000'
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 2

        // Absorb clicks so they don't close the menu
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            

            // Header
            RowLayout {
                Layout.fillWidth: true

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
                        color: '#f4cde6'
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

                Text {
                    text: "Notifications"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Clear all
                Rectangle {
                    implicitWidth: clearText.implicitWidth + 16
                    implicitHeight: 26
                    radius: 8
                    color: clearMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: '#f4cde4'
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            for (let i = notifServer.trackedNotifications.values.length - 1; i >= 0; i--) {
                                notifServer.trackedNotifications.values[i].dismiss();
                            }
                        }
                    }
                }
            }

            // Do Not Disturb
            Toggle {
                label: "Do not disturb"
                checked: root.doNotDisturb
                onToggled: value => root.doNotDisturb = value
            }

            // Notification list
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8
                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    required property var modelData
                    width: notifList.width
                    height: contentCol.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(1, 0.65, 0.89, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // App icon
                            IconImage {
                                visible: modelData.appIcon !== ""
                                implicitSize: 16
                                source: root.resolveIcon(modelData.appIcon)
                            }

                            // Fallback icon when no app icon
                            Rectangle {
                                visible: modelData.appIcon === ""
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 8
                                color: Qt.rgba(1, 0.65, 0.89, 0.3)
                                Text {
                                    anchors.centerIn: parent
                                    text: "🔔"
                                    font.pixelSize: 9
                                }
                            }

                            Text {
                                text: modelData.appName || "App"
                                color: "#a6adc8"
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "✕"
                                color: "#f38ba8"
                                font.pixelSize: 12

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.dismiss()
                                }
                            }
                        }

                        Text {
                            text: modelData.summary
                            color: "white"
                            font.pixelSize: 13
                            font.bold: true
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: "#bac2de"
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifList.count === 0
                    text: "No notifications"
                    color: "#6c7086"
                    font.pixelSize: 13
                }
            }

            // Quick settings: volume + brightness
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                // Quick tiles grid (Android 15 style)
                Grid {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    columns: 5
                    spacing: 6

                    Repeater {
                        model: root.quickTiles

                        delegate: QuickTile {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            onClicked: executeAction(modelData.action)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    // Input device
                    DevicePicker {
                        title: "Input"
                        devices: root.sources
                        current: root.source
                        onSelect: node => Pipewire.preferredDefaultAudioSource = node
                    }

                    // Output device
                    DevicePicker {
                        title: "Output"
                        devices: root.sinks
                        current: root.sink
                        onSelect: node => Pipewire.preferredDefaultAudioSink = node
                    }
                }

                // Microphone volume
                PillSlider {
                    icon: root.sourceMuted ? String.fromCodePoint(0xF131) // microphone-slash
                    : String.fromCodePoint(0xF130) // microphone
                    value: root.sourceVolume
                    inactive: root.sourceMuted
                    onMoved: v => {
                        if (root.source && root.source.ready && root.source.audio) {
                            root.source.audio.volume = v;
                            root.source.audio.muted = false;
                        }
                    }
                    onIconClicked: {
                        if (root.source && root.source.ready && root.source.audio)
                            root.source.audio.muted = !root.source.audio.muted;
                    }
                }

                // Volume
                PillSlider {
                    icon: root.muted ? String.fromCodePoint(0xF026) // volume-off
                    : String.fromCodePoint(0xF028) // volume-up
                    value: root.volume
                    inactive: root.muted
                    onMoved: v => {
                        if (root.sink && root.sink.ready && root.sink.audio) {
                            root.sink.audio.volume = v;
                            root.sink.audio.muted = false;
                        }
                    }
                    onIconClicked: {
                        if (root.sink && root.sink.ready && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted;
                    }
                }

                // Brightness
                PillSlider {
                    icon: String.fromCodePoint(0xF185) // sun
                    min: 0
                    max: 100
                    value: brightness.value
                    onMoved: v => brightness.setValue(v)
                }

                // Wi-Fi / Bluetooth panels (Android 12 style wide tiles)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 8

                    WideToggle {
                        icon: String.fromCodePoint(0xF1EB) // wifi
                        title: "Wi-Fi"
                        subtitle: root.connectedNetwork ? root.connectedNetwork.name : (root.wifiOn ? "Not connected" : "Off")
                        active: root.connectedNetwork !== null
                        powered: root.wifiOn
                        onClicked: root.wifiRequested()
                    }

                    WideToggle {
                        icon: String.fromCodePoint(0xF293) // bluetooth
                        title: "Bluetooth"
                        subtitle: root.connectedBtDevice ? (root.connectedBtDevice.name || root.connectedBtDevice.address) : (root.btOn ? "Not connected" : "Off")
                        active: root.connectedBtDevice !== null
                        powered: root.btOn
                        onClicked: root.bluetoothRequested()
                    }
                }
            }
        }
    }

    component PillSlider: Item {
        id: pill
        property string icon: ""
        property real min: 0
        property real max: 1
        property real value: 0
        property bool inactive: false
        property color accent: '#ffc0f7'
        signal moved(real value)
        signal iconClicked

        Layout.fillWidth: true
        implicitHeight: 38

        readonly property real ratio: (value - min) / (max - min)

        // Unfilled pill base
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: wifiBtnMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
        }

        // Fill — proportional to the value, like Android's quick-settings pill
        Rectangle {
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
            }
            width: parent.width * pill.ratio
            radius: height / 2
            color: pill.accent
            opacity: pill.inactive ? 0.4 : 1.0
        }

        // Icon inside the pill (left)
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: pill.icon
            color: pill.ratio > 0.075 ? '#000000' : '#c8a6c6'
            font.pixelSize: 20
            font.family: "Google Sans Flex"
        }

        // Value as a number with percent at the end of the pill
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(pill.ratio * 100) + "%"
            color: pill.ratio < 0.9 ? "#c8a6c6" : "black"
            font.pixelSize: 15
            font.bold: true
            font.family: "Google Sans Flex"
        }

        // Drag / wheel anywhere on the pill
        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            function setFromMouse(mx) {
                const r = Math.max(0, Math.min(1, mx / width));
                pill.moved(pill.min + r * (pill.max - pill.min));
            }

            onPressed: mouse => setFromMouse(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    setFromMouse(mouse.x);
            }
            onWheel: wheel => {
                const step = (pill.max - pill.min) * 0.05;
                const delta = wheel.angleDelta.y > 0 ? step : -step;
                pill.moved(Math.max(pill.min, Math.min(pill.max, pill.value + delta)));
            }
        }

        // Icon click target (on top of the drag area, at the left)
        MouseArea {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.iconClicked()
        }
    }

    component DevicePicker: ColumnLayout {
        id: picker
        property string title: ""
        property var devices: []
        property var current: null
        property bool expanded: false
        signal select(var node)

        Layout.fillWidth: true
        spacing: 4

        function displayName(node) {
            return node && node.description ? node.description : (node ? node.name : "");
        }

        ColumnLayout {
            visible: picker.expanded
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: picker.devices

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 6
                    color: modelData === picker.current ? Qt.rgba(0.55, 0.65, 1.0, 0.2) : (devMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10

                        Text {
                            Layout.fillWidth: true
                            text: modelData.description || modelData.name || "Unknown"
                            color: modelData === picker.current ? "#89b4fa" : "#cdd6f4"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Text {
                            visible: modelData === picker.current
                            text: "✓"
                            color: "#89b4fa"
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: devMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.select(modelData);
                            picker.expanded = false;
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: 8
            color: headMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: picker.title
                    color: "#a6adc8"
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    text: picker.displayName(picker.current) || "—"
                    color: "white"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    text: picker.expanded ? "▾" : "▸"
                    color: "#cdd6f4"
                    font.pixelSize: 12
                }
            }

            MouseArea {
                id: headMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: picker.expanded = !picker.expanded
            }
        }
    }

    component WideToggle: Rectangle {
        id: wide
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool powered: false
        signal clicked

        Layout.fillWidth: true
        implicitHeight: 62
        radius: 18
        color: wide.active ? '#ffc0f7' : (wide.powered ? (wideMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.28) : Qt.rgba(1, 0.65, 0.89, 0.22)) : (wideMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)))
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 10

            Text {
                text: wide.icon
                color: wide.active ? "black" : (wide.powered ? '#ffd0fa' : '#f4cdf0')
                font.pixelSize: 22
                font.family: "Google Sans Flex"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: wide.title
                    color: wide.active ? "black" : "white"
                    font.pixelSize: 13
                    font.bold: true
                    font.family: "Google Sans Flex"
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: wide.subtitle
                    color: wide.active ? Qt.rgba(0, 0, 0, 0.7) : '#c8a6c0'
                    font.pixelSize: 11
                    font.family: "Google Sans Flex"
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: wideMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wide.clicked()
        }
    }

    component QuickTile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        signal clicked

        width: 60
        height: 60
        radius: 8
        color: tileMouse.containsMouse ? Qt.rgba(1, 0.65, 0.89, 0.175) : Qt.rgba(1, 0.65, 0.89, 0.03)
        border.color: Qt.rgba(1, 1, 1, 0.05)
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.icon
                color: '#ffbee6'
                font.pixelSize: 20
                font.family: "Google Sans Flex"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 58
                text: tile.label
                color: '#f4cdf0'
                font.pixelSize: 9
                font.family: "Google Sans Flex"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }
}
