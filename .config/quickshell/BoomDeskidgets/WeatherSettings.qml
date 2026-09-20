import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: settingsRoot

    required property bool open
    signal dismissed()
    signal locationSelected(real lat, real lon, string name)

    visible: open
    aboveWindows: true
    focusable: true

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: -1
    color: "transparent"

    // ── Dismiss on click outside the card ──
    MouseArea {
        anchors.fill: parent
        onClicked: settingsRoot.dismissed()
    }

    // ── Center card ──
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 380
        height: cardLayout.implicitHeight + 48
        radius: 28
        color: Qt.rgba(0.12, 0.12, 0.12, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // Block clicks from reaching the backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                // Focus the search input when clicking inside the card
                searchInput.forceActiveFocus()
            }
        }

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // ── Title ──
            Text {
                text: "Weather Location"
                font.family: "Google Sans"
                font.pixelSize: 22
                font.weight: Font.Medium
                color: "white"
            }

            // ── Search input ──
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 24
                color: Qt.rgba(1, 1, 1, 0.08)
                border.color: searchInput.activeFocus
                    ? Qt.rgba(0.6, 0.8, 1, 0.5)
                    : Qt.rgba(1, 1, 1, 0.12)
                border.width: searchInput.activeFocus ? 2 : 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: 16
                        opacity: 0.5
                    }

                    // Use TextField-like TextInput with explicit focus handling
                    Rectangle {
                        Layout.fillWidth: true
                        height: 36
                        color: "transparent"

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.verticalCenter: parent.verticalCenter
                            color: "white"
                            font.family: "Google Sans"
                            font.pixelSize: 16
                            clip: true
                            activeFocusOnPress: true
                            selectByMouse: true
                            cursorVisible: activeFocus

                            // Ensure clicking this area focuses the input
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.IBeamCursor
                                onClicked: {
                                    searchInput.forceActiveFocus()
                                    // Move cursor to click position
                                    var pos = mapToItem(searchInput, mouse.x, mouse.y)
                                    searchInput.positionAt(pos.x)
                                }
                                // Don't propagate — the parent card MouseArea handles dismiss
                                propagateComposedEvents: true
                            }

                            // Debounce timer for search
                            Timer {
                                id: searchDebounce
                                interval: 400
                                onTriggered: {
                                    if (searchInput.text.length >= 2) {
                                        geocodeProc.query = searchInput.text
                                        geocodeProc.running = true
                                    } else {
                                        suggestionModel.clear()
                                    }
                                }
                            }

                            onTextChanged: searchDebounce.restart()

                            // Placeholder
                            Text {
                                visible: !searchInput.text && !searchInput.activeFocus
                                text: "Search city..."
                                font.family: "Google Sans"
                                font.pixelSize: 16
                                color: Qt.rgba(1, 1, 1, 0.3)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Clear button
                    Text {
                        visible: searchInput.text.length > 0
                        text: "✕"
                        font.pixelSize: 14
                        color: Qt.rgba(1, 1, 1, 0.4)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                suggestionModel.clear()
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ── Suggestions list ──
            ListView {
                id: suggestionList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(suggestionModel.count * 48, 240)
                visible: suggestionModel.count > 0
                clip: true
                spacing: 2

                model: ListModel { id: suggestionModel }

                delegate: Rectangle {
                    width: suggestionList.width
                    height: 44
                    radius: 12
                    color: suggestionMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.08)
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: model.cityName
                                font.family: "Google Sans"
                                font.pixelSize: 15
                                font.weight: Font.Normal
                                color: "white"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.region
                                font.family: "Google Sans"
                                font.pixelSize: 12
                                color: Qt.rgba(1, 1, 1, 0.45)
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: model.country
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            color: Qt.rgba(1, 1, 1, 0.35)
                        }
                    }

                    MouseArea {
                        id: suggestionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            settingsRoot.locationSelected(
                                model.lat, model.lon, model.cityName
                            )
                            settingsRoot.dismissed()
                        }
                    }
                }
            }

            // ── Loading indicator ──
            Text {
                visible: geocodeProc.running
                text: "Searching..."
                font.family: "Google Sans"
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.4)
                Layout.alignment: Qt.AlignHCenter
            }

            // ── No results ──
            Text {
                visible: !geocodeProc.running && suggestionModel.count === 0
                         && searchInput.text.length >= 2
                text: "No cities found"
                font.family: "Google Sans"
                font.pixelSize: 13
                color: Qt.rgba(1, 1, 1, 0.35)
                Layout.alignment: Qt.AlignHCenter
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

    // Force focus when opened
    onOpenChanged: {
        if (open) {
            searchInput.text = ""
            suggestionModel.clear()
            searchInput.forceActiveFocus()
        }
    }
}
