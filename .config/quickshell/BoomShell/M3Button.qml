import QtQuick
import QtQuick.Layouts
import "Theme.js" as T

// Material 3 button: variant is "filled" | "tonal" | "text" | "outlined" | "error"
Rectangle {
    id: btn

    property string text: ""
    property string glyph: ""
    property string variant: "filled"
    property bool compact: false
    signal clicked()

    readonly property bool textured: variant === "filled" || variant === "tonal"
    readonly property color containerColor: {
        switch (variant) {
        case "filled": return T.primary
        case "tonal": return T.secondaryContainerStrong
        case "error": return T.errorFilled
        default: return "transparent"
        }
    }
    readonly property color labelColor: {
        switch (variant) {
        case "filled": return T.onPrimary
        case "tonal": return T.onSecondaryContainer
        case "error": return T.onErrorFilled
        default: return T.onSecondaryContainer
        }
    }

    implicitWidth: contentRow.implicitWidth + (textured ? (compact ? 20 : 36) : 20)
    implicitHeight: compact ? 28 : 36
    radius: height / 2
    color: {
        if (!btn.enabled)
            return textured ? T.surfaceContainerHigh : "transparent"
        if (btnMouse.containsMouse)
            return textured ? Qt.rgba(1, 0.65, 0.89, 0.32) : T.surfaceContainerHigh
        return btn.containerColor
    }
    border.color: btn.enabled ? T.outline : T.outlineVariant
    border.width: variant === "outlined" ? 1 : 0
    opacity: btn.enabled ? 1 : 0.38

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: T.gap

        Text {
            visible: btn.glyph !== ""
            text: btn.glyph
            color: btn.labelColor
            font.pixelSize: 16
            font.family: T.font
        }

        Text {
            text: btn.text
            color: btn.labelColor
            font.pixelSize: btn.compact ? T.labelMedium : T.labelLarge
            font.weight: Font.Medium
            font.family: T.font
        }
    }

    MouseArea {
        id: btnMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
