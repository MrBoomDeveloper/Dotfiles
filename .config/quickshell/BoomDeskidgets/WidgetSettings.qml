import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// ── Widget settings screen ──
// Follows BoomShell's modal pattern: full-screen window, click-outside scrim,
// centered panel sliding up from the bottom edge, Theme.js tokens.
PanelWindow {
    id: root

    required property bool open
    required property real cardOpacity
    required property string currentCity
    required property var visibility
    required property string bareClockStyle
    required property bool visualizerAlwaysOn

    signal dismissed()
    signal locationSelected(real lat, real lon, string name)
    signal cardOpacityEdited(real value)
    signal widgetVisibilityChanged(string id, bool value)
    signal bareClockStylePicked(string style)
    signal visualizerAlwaysOnToggled(bool value)
    signal resetLayoutRequested()

    M3Theme { id: theme }

    property bool panelVisible: false
    property bool closing: false

    visible: root.open || root.panelVisible
    color: "transparent"
    focusable: root.open
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    onOpenChanged: {
        if (root.open) {
            root.closing = false
            root.panelVisible = true
            hideTimer.stop()
            panel.sliding = false
            panel.slide = 1
            search.text = ""
            suggestionModel.clear()
            showTimer.restart()
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
            search.forceActiveFocus()
        }
    }

    // Window has to outlive the fly-out animation
    Timer {
        id: hideTimer
        interval: 120
        onTriggered: {
            root.panelVisible = false
            root.closing = false
            suggestionModel.clear()
        }
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
        width: Math.min(460, parent.width - 32)
        height: layout.implicitHeight + theme.margin * 2
        radius: theme.radiusPanel
        color: theme.surface
        border.color: theme.outline
        border.width: 1

        // 0 = resting in the middle of the screen, 1 = parked below the bottom edge
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

        // Absorb clicks so they don't close the panel
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: layout
            anchors.fill: parent
            anchors.margins: theme.margin
            spacing: theme.gap

            // ── Header ──
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: theme.gap

                Text {
                    Layout.fillWidth: true
                    text: "Settings"
                    color: theme.surfaceText
                    font.pixelSize: theme.titleLarge
                    font.weight: Font.Medium
                    font.family: theme.fontFamily
                }

                IconButton {
                    glyph: String.fromCodePoint(0xF0156) // close
                    onClicked: root.dismissed()
                }
            }

            // ── Current city ──
            SectionLabel { text: "WEATHER LOCATION" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cityColumn.implicitHeight + theme.gapLarge * 2
                radius: theme.radiusCard
                color: theme.surfaceContainerHigh
                border.color: theme.outlineVariant
                border.width: 1

                ColumnLayout {
                    id: cityColumn
                    anchors.fill: parent
                    anchors.margins: theme.gapLarge
                    spacing: theme.gap

                    Text {
                        Layout.fillWidth: true
                        text: root.currentCity
                        color: theme.secondaryContainerText
                        font.pixelSize: theme.bodyLarge
                        font.weight: Font.Medium
                        font.family: theme.fontFamily
                        elide: Text.ElideRight
                    }

                    // ── Search field ──
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        TextField {
                            id: search
                            anchors.fill: parent
                            placeholderText: "Search city…"
                            color: theme.surfaceText
                            placeholderTextColor: theme.surfaceVariantText
                            selectionColor: theme.secondaryContainerStrong
                            selectedTextColor: theme.surfaceText
                            font.pixelSize: theme.bodyLarge
                            font.family: theme.fontFamily
                            leftPadding: 38
                            rightPadding: theme.margin
                            onTextChanged: searchDebounce.restart()
                            onAccepted: {
                                if (suggestionModel.count > 0) {
                                    const first = suggestionModel.get(0)
                                    root.locationSelected(first.lat, first.lon, first.cityName)
                                    root.dismissed()
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    if (search.text.length > 0) {
                                        search.text = ""
                                        suggestionModel.clear()
                                    } else {
                                        root.dismissed()
                                    }
                                    event.accepted = true
                                }
                            }

                            background: Rectangle {
                                radius: theme.radiusChip
                                color: theme.surfaceContainerHighest
                                border.color: search.activeFocus ? theme.primary : theme.outline
                                border.width: 1
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: String.fromCodePoint(0xF0349) // search
                            color: theme.surfaceVariantText
                            font.pixelSize: 16
                            font.family: theme.fontFamily
                        }

                        // Debounce timer for the geocoding request
                        Timer {
                            id: searchDebounce
                            interval: 400
                            onTriggered: {
                                if (search.text.length >= 2) {
                                    geocodeProc.query = search.text
                                    geocodeProc.running = true
                                } else {
                                    suggestionModel.clear()
                                }
                            }
                        }
                    }

                    // ── Suggestions ──
                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(suggestionModel.count * 42, 168)
                        visible: suggestionModel.count > 0
                        clip: true
                        spacing: 2
                        model: ListModel { id: suggestionModel }
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: 42
                            radius: theme.radiusChip
                            color: rowMouse.containsMouse ? theme.secondaryContainerStrong
                                                          : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: theme.gap

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.cityName
                                        color: theme.surfaceText
                                        font.pixelSize: theme.bodyLarge
                                        font.weight: Font.Medium
                                        font.family: theme.fontFamily
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: modelData.region !== ""
                                        text: modelData.region
                                        color: theme.surfaceVariantText
                                        font.pixelSize: theme.labelSmall
                                        font.family: theme.fontFamily
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: modelData.country
                                    color: theme.surfaceVariantText
                                    font.pixelSize: theme.labelSmall
                                    font.family: theme.fontFamily
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.locationSelected(
                                        modelData.lat, modelData.lon, modelData.cityName)
                                    root.dismissed()
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: geocodeProc.running
                        text: "Searching…"
                        color: theme.surfaceVariantText
                        font.pixelSize: theme.labelSmall
                        font.family: theme.fontFamily
                    }
                }
            }

            // ── Widgets ──
            SectionLabel { text: "WIDGETS" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: opacityColumn.implicitHeight + theme.gapLarge * 2
                radius: theme.radiusCard
                color: theme.surfaceContainerHigh
                border.color: theme.outlineVariant
                border.width: 1

                ColumnLayout {
                    id: opacityColumn
                    anchors.fill: parent
                    anchors.margins: theme.gapLarge
                    spacing: theme.gap

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: theme.gap

                        Text {
                            Layout.fillWidth: true
                            text: "Card opacity"
                            color: theme.surfaceText
                            font.pixelSize: theme.bodyLarge
                            font.weight: Font.Medium
                            font.family: theme.fontFamily
                        }

                        Text {
                            text: Math.round(root.cardOpacity * 100) + "%"
                            color: theme.secondaryContainerText
                            font.pixelSize: theme.labelLarge
                            font.family: theme.fontFamily
                        }
                    }

                    // ── M3 slider ──
                    Item {
                        id: opacitySlider
                        Layout.fillWidth: true
                        implicitHeight: 28

                        readonly property real minValue: 0.3
                        readonly property real maxValue: 1.0

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 4
                            radius: 2
                            color: theme.surfaceContainerHighest
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(handle.width / 2, handle.x + handle.width / 2)
                            height: 4
                            radius: 2
                            color: theme.primary
                        }

                        Rectangle {
                            id: handle
                            width: 18
                            height: 18
                            radius: theme.radiusFull
                            anchors.verticalCenter: parent.verticalCenter
                            color: theme.primary
                            border.color: theme.surface
                            border.width: 2
                            x: (root.cardOpacity - opacitySlider.minValue)
                               / (opacitySlider.maxValue - opacitySlider.minValue)
                               * Math.max(0, opacitySlider.width - width)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            function setFromX(px) {
                                const t = Math.max(0, Math.min(1, px / Math.max(1, opacitySlider.width)))
                                const value = opacitySlider.minValue
                                    + t * (opacitySlider.maxValue - opacitySlider.minValue)
                                root.cardOpacityEdited(Math.round(value * 100) / 100)
                            }

                            onPressed: mouse => setFromX(mouse.x)
                            onPositionChanged: mouse => {
                                if (mouse.buttons & Qt.LeftButton)
                                    setFromX(mouse.x)
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Applies to both desktop widgets"
                        color: theme.surfaceVariantText
                        font.pixelSize: theme.labelSmall
                        font.family: theme.fontFamily
                    }
                }
            }

            // ── Visibility ──
            SectionLabel { text: "VISIBILITY" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: visibilityColumn.implicitHeight + theme.gapLarge * 2
                radius: theme.radiusCard
                color: theme.surfaceContainerHigh
                border.color: theme.outlineVariant
                border.width: 1

                ColumnLayout {
                    id: visibilityColumn
                    anchors.fill: parent
                    anchors.margins: theme.gapLarge
                    spacing: theme.gap

                    ToggleRow {
                        label: "Clock"
                        checked: root.visibility["clock"] !== false
                        onToggled: value => root.widgetVisibilityChanged("clock", value)
                    }

                    ToggleRow {
                        label: "Weather"
                        checked: root.visibility["weather"] !== false
                        onToggled: value => root.widgetVisibilityChanged("weather", value)
                    }

                    ToggleRow {
                        label: "Bare clock"
                        checked: root.visibility["bareClock"] === true
                        onToggled: value => root.widgetVisibilityChanged("bareClock", value)
                    }

                    ToggleRow {
                        label: "Music visualizer"
                        checked: root.visibility["visualizer"] !== false
                        onToggled: value => root.widgetVisibilityChanged("visualizer", value)
                    }

                    ToggleRow {
                        label: "Always show visualizer"
                        checked: root.visualizerAlwaysOn
                        onToggled: value => root.visualizerAlwaysOnToggled(value)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Keeps the visualizer on screen when windows cover the desktop"
                        color: theme.surfaceVariantText
                        font.pixelSize: theme.labelSmall
                        font.family: theme.fontFamily
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: theme.outlineVariant
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: theme.gap

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: "Bare clock layout"
                                color: theme.surfaceText
                                font.pixelSize: theme.bodyLarge
                                font.family: theme.fontFamily
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Hours over minutes, or one HH:MM line"
                                color: theme.surfaceVariantText
                                font.pixelSize: theme.labelSmall
                                font.family: theme.fontFamily
                            }
                        }

                        Chip {
                            label: "Stacked"
                            active: root.bareClockStyle !== "inline"
                            onClicked: root.bareClockStylePicked("stacked")
                        }

                        Chip {
                            label: "Inline"
                            active: root.bareClockStyle === "inline"
                            onClicked: root.bareClockStylePicked("inline")
                        }
                    }
                }
            }

            // ── Layout ──
            SectionLabel { text: "LAYOUT" }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: layoutRow.implicitHeight + theme.gapLarge * 2
                radius: theme.radiusCard
                color: theme.surfaceContainerHigh
                border.color: theme.outlineVariant
                border.width: 1

                RowLayout {
                    id: layoutRow
                    anchors.fill: parent
                    anchors.margins: theme.gapLarge
                    spacing: theme.gap

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: "Widget positions"
                            color: theme.surfaceText
                            font.pixelSize: theme.bodyLarge
                            font.weight: Font.Medium
                            font.family: theme.fontFamily
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Right-click a widget to drag it"
                            color: theme.surfaceVariantText
                            font.pixelSize: theme.labelSmall
                            font.family: theme.fontFamily
                        }
                    }

                    Btn {
                        text: "Reset"
                        onClicked: root.resetLayoutRequested()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 2
                text: "Esc closes · click outside to dismiss"
                color: theme.surfaceVariantText
                font.pixelSize: theme.labelSmall
                font.family: theme.fontFamily
            }
        }
    }

    // ── Geocoding API call ──
    Process {
        id: geocodeProc
        property string query: ""
        command: ["curl", "-s", "--max-time", "5",
            "https://geocoding-api.open-meteo.com/v1/search?name=" + urlEncode(query) + "&count=8&language=en&format=json"]
        stdout: StdioCollector {
            onStreamFinished: {
                suggestionModel.clear()
                try {
                    const data = JSON.parse(this.text)
                    if (data.results) {
                        for (let i = 0; i < data.results.length; i++) {
                            const r = data.results[i]
                            suggestionModel.append({
                                cityName: r.name || "",
                                region: r.admin1 || "",
                                country: r.country_code || "",
                                lat: r.latitude || 0,
                                lon: r.longitude || 0
                            })
                        }
                    }
                } catch (e) {
                    console.log("Geocode error:", e)
                }
            }
        }
    }

    function urlEncode(s) {
        return s.replace(/ /g, "%20").replace(/,/g, "%2C")
    }

    // ── Small BoomShell-style components ──
    component SectionLabel: Text {
        text: ""
        color: theme.primary
        font.pixelSize: theme.labelSmall
        font.weight: Font.Medium
        font.family: theme.fontFamily
    }

    component IconButton: Rectangle {
        id: iconBtn
        property string glyph: ""
        signal clicked()

        implicitWidth: 32
        implicitHeight: 32
        radius: theme.radiusSmall
        color: iconMouse.containsMouse ? theme.surfaceContainerHigh : "transparent"

        Text {
            anchors.centerIn: parent
            text: iconBtn.glyph
            color: theme.surfaceVariantText
            font.pixelSize: 15
            font.family: theme.fontFamily
        }

        MouseArea {
            id: iconMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconBtn.clicked()
        }
    }

    component Btn: Rectangle {
        id: btn
        property string text: ""
        property string variant: "outlined"
        signal clicked()

        readonly property bool filled: btn.variant === "filled"

        implicitWidth: btnLabel.implicitWidth + 28
        implicitHeight: 32
        radius: height / 2
        color: btn.filled
            ? (btnMouse.containsMouse ? theme.primaryContainer : theme.primary)
            : (btnMouse.containsMouse ? theme.secondaryContainerStrong : "transparent")
        border.color: theme.outline
        border.width: btn.filled ? 0 : 1

        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: btn.text
            color: btn.filled ? theme.primaryText : theme.secondaryContainerText
            font.pixelSize: theme.labelLarge
            font.weight: Font.Medium
            font.family: theme.fontFamily
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow
        property string label: ""
        property bool checked: false
        signal toggled(bool value)

        Layout.fillWidth: true
        spacing: theme.gap

        Text {
            Layout.fillWidth: true
            text: toggleRow.label
            color: theme.surfaceText
            font.pixelSize: theme.bodyLarge
            font.family: theme.fontFamily
        }

        M3Toggle {
            checked: toggleRow.checked
            onToggled: value => toggleRow.toggled(value)
        }
    }

    component M3Toggle: Item {
        id: toggle
        property bool checked: false
        signal toggled(bool value)

        implicitWidth: 40
        implicitHeight: 22

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: toggle.checked ? theme.primary : theme.surfaceContainerHighest
            border.color: toggle.checked ? "transparent" : theme.outline
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Rectangle {
            width: 16
            height: 16
            radius: height / 2
            y: 3
            x: toggle.checked ? toggle.width - width - 3 : 3
            color: toggle.checked ? theme.primaryText : theme.surfaceVariantText
            Behavior on x {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled(!toggle.checked)
        }
    }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        signal clicked()

        implicitWidth: chipLabel.implicitWidth + 16
        implicitHeight: 24
        radius: theme.radiusChip
        color: chip.active
            ? theme.secondaryContainerStrong
            : (chipMouse.containsMouse ? theme.surfaceContainerHigh : "transparent")
        border.color: theme.outline
        border.width: chip.active ? 0 : 1

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? theme.secondaryContainerText : theme.surfaceVariantText
            font.pixelSize: theme.labelSmall
            font.weight: Font.Medium
            font.family: theme.fontFamily
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }
}
