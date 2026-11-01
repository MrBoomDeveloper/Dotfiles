import QtQuick

// ── BoomShell design tokens (dark, pink Material You) ──
// Mirrors BoomShell/Theme.js so the desktop widgets, their modals and the
// settings screen share the exact same visual language as the shell.
QtObject {
    // ── Shape scale ──
    readonly property int radiusPanel: 20
    readonly property int radiusCard: 14
    readonly property int radiusChip: 8
    readonly property int radiusSmall: 8
    readonly property int radiusFull: 999

    // ── Spacing scale (4dp grid) ──
    readonly property int margin: 12
    readonly property int gap: 6
    readonly property int gapSmall: 4
    readonly property int gapLarge: 12

    // ── Typography ──
    readonly property string fontFamily: "Google Sans Flex"
    readonly property int displayMedium: 44
    readonly property int titleLarge: 20
    readonly property int titleMedium: 14
    readonly property int bodyLarge: 14
    readonly property int bodyMedium: 12
    readonly property int bodySmall: 11
    readonly property int labelLarge: 13
    readonly property int labelMedium: 11
    readonly property int labelSmall: 10

    // ── Color roles ──
    readonly property color surface: "#CC000000"
    readonly property color surfaceContainer: "#0AFFFFFF"
    readonly property color surfaceContainerHigh: "#14FFFFFF"
    readonly property color surfaceContainerHighest: "#1FFFFFFF"
    readonly property color outline: "#33FFFFFF"
    readonly property color outlineVariant: "#1AFFFFFF"
    readonly property color surfaceText: "#FFF2EDF1"
    readonly property color surfaceVariantText: "#FFCFC2CA"
    readonly property color disabled: "#61F2EDF1"
    readonly property color primary: "#FFFFA9E5"
    readonly property color primaryText: "#FF1A0013"
    readonly property color primaryContainer: "#FFFFC0F7"
    readonly property color primaryContainerText: "#FF33002A"
    readonly property color secondaryContainer: "#29FFA9E5"
    readonly property color secondaryContainerStrong: "#3DFFA9E5"
    readonly property color secondaryContainerText: "#FFFFD0FA"
    readonly property color error: "#FFFFB4AB"
    readonly property color errorFilled: "#FFB3261E"

    // ── State layers ──
    readonly property real stateHover: 0.08
    readonly property real stateEdit: 0.06
    readonly property color stateLayerHover: "#14FFFFFF"
}
