import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import "Theme.js" as T

PanelWindow {
    id: root

    // External control
    property bool open: false
    property bool doNotDisturb: false
    property bool closing: false
    required property var notifServer

    onOpenChanged: {
        if (root.open) {
            dismissTimer.stop()
            root.visible = true
            root.closing = false
            closeSlideTimer.stop()
            menuPanel.slideX = -360
            slideInTimer.restart()
        } else if (!root.closing && root.visible) {
            slideInTimer.stop()
            root.closing = true
            closeSlideTimer.restart()
            dismissTimer.restart()
        }
    }

    Timer {
        id: slideInTimer
        interval: 0
        onTriggered: menuPanel.slideX = 0
    }

    Timer {
        id: closeSlideTimer
        interval: 0
        onTriggered: menuPanel.slideX = -360
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

    Component.onCompleted: menuPanel.slideX = -360

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

    visible: false
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

    // Menu panel — M3 navigation drawer
    Rectangle {
        id: menuPanel
        width: 340
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        radius: T.radiusPanel
        topLeftRadius: 0
        bottomLeftRadius: 0
        color: T.surface
        border.color: T.outline
        border.width: 1

        property real slideX: -360
        transform: Translate { x: menuPanel.slideX }

        Behavior on slideX {
            NumberAnimation {
                duration: root.closing ? 200 : 240
                easing.type: root.closing ? Easing.InCubic : Easing.OutCubic
            }
        }

        // Absorb clicks so they don't close the menu
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: T.margin
            spacing: T.gap

            // Header — Material 3 top app bar
            AppBar {
                title: "Notifications"
                showClose: true
                onCloseClicked: root.dismissed()

                M3Button {
                    Layout.alignment: Qt.AlignVCenter
                    variant: "text"
                    text: "Clear all"
                    onClicked: {
                        for (let i = notifServer.trackedNotifications.values.length - 1; i >= 0; i--) {
                            notifServer.trackedNotifications.values[i].dismiss();
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

            // Notification list — M3 cards
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: T.gap
                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    required property var modelData
                    width: notifList.width
                    height: contentCol.implicitHeight + 2 * T.margin
                    radius: T.radiusCard
                    color: T.surfaceContainerHigh

                    ColumnLayout {
                        id: contentCol
                        anchors.fill: parent
                        anchors.margins: T.margin
                        spacing: T.gapSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: T.gap

                            // App icon
                            IconImage {
                                visible: modelData.appIcon !== ""
                                implicitSize: 18
                                source: root.resolveIcon(modelData.appIcon)
                            }

                            // Fallback icon when no app icon
                            Rectangle {
                                visible: modelData.appIcon === ""
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                radius: 9
                                color: T.secondaryContainerStrong

                                Text {
                                    anchors.centerIn: parent
                                    text: String.fromCodePoint(0xF009A) // bell
                                    color: T.onSecondaryContainer
                                    font.pixelSize: 11
                                    font.family: T.font
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.appName || "App"
                                color: T.onSurfaceVariant
                                font.pixelSize: T.labelMedium
                                font.family: T.font
                                elide: Text.ElideRight
                            }

                            M3IconButton {
                                size: 28
                                iconSize: 14
                                glyph: String.fromCodePoint(0xF0156) // close
                                onClicked: modelData.dismiss()
                            }
                        }

                        Text {
                            text: modelData.summary
                            color: T.onSurface
                            font.pixelSize: T.titleMedium
                            font.weight: Font.Medium
                            font.family: T.font
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: modelData.body !== ""
                            text: modelData.body
                            color: T.onSurfaceVariant
                            font.pixelSize: T.bodyMedium
                            font.family: T.font
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
                    color: T.onSurfaceVariant
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                }
            }

            // Quick settings
            ColumnLayout {
                Layout.fillWidth: true
                spacing: T.gap

                // Quick tiles (Android 15 style wide tiles)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: T.gap

                    Repeater {
                        model: root.quickTiles

                        delegate: QuickTile {
                            required property var modelData
                            icon: modelData.icon
                            label: modelData.label
                            onClicked: executeAction(modelData.action)
                        }
                    }

                    // Shortcuts: wallpaper + emoji pickers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: T.gap

                        QuickTile {
                            icon: String.fromCodePoint(0xF03E) // picture
                            label: "Wallpaper"
                            onClicked: {
                                root.executeAction(["skwd", "wall", "toggle"]);
                                root.dismissed();
                            }
                        }

                        QuickTile {
                            icon: String.fromCodePoint(0xF118) // smile
                            label: "Emoji"
                            onClicked: {
                                root.executeAction(["rofimoji"]);
                                root.dismissed();
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: T.gap

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

                // Wi-Fi / Bluetooth quick tiles
                RowLayout {
                    Layout.fillWidth: true
                    spacing: T.gap

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
        property color accent: T.primary
        signal moved(real value)
        signal iconClicked

        Layout.fillWidth: true
        implicitHeight: 32

        readonly property real ratio: (value - min) / (max - min)

        // M3 slider track
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: hoverArea.containsMouse ? T.surfaceContainerHigh : T.surfaceContainer
        }

        // Active track — proportional to the value
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

        // Icon inside the track (left)
        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: pill.icon
            color: pill.ratio > 0.075 ? T.onPrimary : T.onSurfaceVariant
            font.pixelSize: 18
            font.family: T.font
        }

        // Value label (right)
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(pill.ratio * 100) + "%"
            color: pill.ratio < 0.9 ? T.onSurfaceVariant : T.onPrimary
            font.pixelSize: T.labelLarge
            font.weight: Font.Medium
            font.family: T.font
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
        }

        // Drag / wheel anywhere on the pill
        MouseArea {
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
            width: 44
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
        spacing: T.gapSmall

        function displayName(node) {
            return node && node.description ? node.description : (node ? node.name : "");
        }

        // Expanded device list — M3 menu items
        ColumnLayout {
            visible: picker.expanded
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: picker.devices

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: T.radiusSmall
                    color: devMouse.containsMouse ? T.surfaceContainer : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: T.margin
                        anchors.rightMargin: T.margin
                        spacing: T.gap

                        Text {
                            visible: modelData === picker.current
                            text: String.fromCodePoint(0xF012C) // check
                            color: T.onSecondaryContainer
                            font.pixelSize: 14
                            font.family: T.font
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.description || modelData.name || "Unknown"
                            color: modelData === picker.current ? T.onSecondaryContainer : T.onSurface
                            font.pixelSize: T.bodyMedium
                            font.family: T.font
                            elide: Text.ElideRight
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

        // Selector head
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: height / 2
            color: headMouse.containsMouse ? T.surfaceContainerHighest : T.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: T.margin
                anchors.rightMargin: T.margin
                spacing: T.gap

                Text {
                    text: picker.title
                    color: T.onSurfaceVariant
                    font.pixelSize: T.labelMedium
                    font.family: T.font
                }

                Text {
                    Layout.fillWidth: true
                    text: picker.displayName(picker.current) || "—"
                    color: T.onSurface
                    font.pixelSize: T.bodyMedium
                    font.family: T.font
                    elide: Text.ElideRight
                }

                Text {
                    text: picker.expanded
                          ? String.fromCodePoint(0xF013F) // chevron-up
                          : String.fromCodePoint(0xF0140) // chevron-down
                    color: T.onSurfaceVariant
                    font.pixelSize: 14
                    font.family: T.font
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
        implicitHeight: 52
        radius: T.radiusCard
        color: wide.active ? T.primary
                          : (wide.powered ? T.secondaryContainer
                                          : (wideMouse.containsMouse ? T.surfaceContainerHigh : T.surfaceContainer))

        Behavior on color {
            ColorAnimation { duration: 140 }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: T.margin
            anchors.rightMargin: T.margin
            spacing: T.gap

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: wide.icon
                color: wide.active ? T.onPrimaryContainer
                                   : (wide.powered ? T.onSecondaryContainer : T.onSurfaceVariant)
                font.pixelSize: 20
                font.family: T.font
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: wide.title
                    color: wide.active ? T.onPrimaryContainer : T.onSurface
                    font.pixelSize: T.labelLarge
                    font.weight: Font.Medium
                    font.family: T.font
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: wide.subtitle
                    color: wide.active ? Qt.rgba(0.2, 0, 0.16, 0.72) : T.onSurfaceVariant
                    font.pixelSize: T.bodySmall
                    font.family: T.font
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

        Layout.fillWidth: true
        implicitHeight: 44
        radius: 22
        color: tileMouse.containsMouse ? T.surfaceContainerHigh : T.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: T.gap

            Text {
                text: tile.icon
                color: T.onSecondaryContainer
                font.pixelSize: 18
                font.family: T.font
            }

            Text {
                Layout.fillWidth: true
                text: tile.label
                color: T.onSurface
                font.pixelSize: T.labelLarge
                font.weight: Font.Medium
                font.family: T.font
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
