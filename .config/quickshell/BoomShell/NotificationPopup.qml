import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    required property var notifServer

    function resolveIcon(icon) {
        if (!icon) return ""
        if (icon.indexOf("/") >= 0 || icon.indexOf("file:") === 0) return icon
        return Quickshell.iconPath(icon)
    }

    visible: popupModelCount > 0
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins.top: 8
    margins.right: 8
    implicitWidth: 380
    implicitHeight: popupColumn.implicitHeight + 16

    // Model that tracks active popups
    property var activePopups: []
    property int popupCount: activePopups.length

    property int popupModelCount: 0

    function addPopup(notif) {
            const popup = {
            notif: notif,
            appName: notif.appName || "Notification",
            summary: notif.summary || "",
            body: notif.body || "",
            icon: notif.image || "",
            appIcon: notif.appIcon || "",
            expireTime: Date.now() + 5000
        }
        activePopups.push(popup)
        popupModelCount = activePopups.length
    }

    function dismissPopup(index) {
        if (index >= 0 && index < activePopups.length) {
            activePopups.splice(index, 1)
            popupModelCount = activePopups.length
        }
    }

    // Watch for new notifications
    property bool _ready: false

    Timer {
        id: readyTimer
        interval: 500
        running: true
        repeat: false
        onTriggered: root._ready = true
    }

    Connections {
        target: root.notifServer

        function onNotification(notification) {
            if (!root._ready) return

            // Track the notification so it appears in history
            notification.tracked = true

            // Show toast popup
            root.addPopup(notification)
            autoDismissTimer.restart()
        }
    }

    Timer {
        id: autoDismissTimer
        interval: 5000
        repeat: false
        onTriggered: {
            // Dismiss oldest popup
            if (root.activePopups.length > 0) {
                root.dismissPopup(0)
                if (root.activePopups.length > 0)
                    autoDismissTimer.restart()
            }
        }
    }

    // Visual layout
    Column {
        id: popupColumn
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8
        width: 360

        Repeater {
            model: root.popupModelCount

            Rectangle {
                id: popupCard
                required property int index
                property var popupData: index < root.activePopups.length ? root.activePopups[index] : null
                width: popupColumn.width
                height: popupContent.implicitHeight + 20
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.85)
                border.color: Qt.rgba(1, 0.65, 0.89, 0.3)
                border.width: 1

                // Fade in / out animation
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 200 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.dismissPopup(popupCard.index)
                    }
                }

                ColumnLayout {
                    id: popupContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    // App icon + name header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        IconImage {
                            visible: popupCard.popupData && popupCard.popupData.appIcon !== ""
                            implicitSize: 16
                            source: popupCard.popupData ? root.resolveIcon(popupCard.popupData.appIcon) : ""
                        }

                        // Fallback icon circle when no app icon
                        Rectangle {
                            visible: popupCard.popupData && popupCard.popupData.appIcon === ""
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
                            text: popupCard.popupData ? popupCard.popupData.appName : ""
                            color: "#a6adc8"
                            font.pixelSize: 11
                            font.bold: true
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
                                onClicked: root.dismissPopup(popupCard.index)
                            }
                        }
                    }

                    // Summary
                    Text {
                        text: popupCard.popupData ? popupCard.popupData.summary : ""
                        color: "white"
                        font.pixelSize: 13
                        font.bold: true
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Body
                    Text {
                        visible: popupCard.popupData && popupCard.popupData.body !== ""
                        text: popupCard.popupData ? popupCard.popupData.body : ""
                        color: "#bac2de"
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
