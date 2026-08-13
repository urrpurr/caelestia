pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Fork addition: mouse-driven brightness control, popped out from the bar's
// brightness status icon. Controls THIS screen's monitor only (each bar owns
// its screen, same as the workspace groups). Deliberately no wheel handler —
// scroll-changes-brightness is banned on this setup (see bar.scrollActions
// in shell.json and the 2026-08-13 monitor-brightness incident).
Item {
    id: root

    required property ShellScreen screen
    readonly property var monitor: Brightness.getMonitorForScreen(screen)

    implicitWidth: layout.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Brightness")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.screen.name
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }

        FilledSlider {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderHeight

            icon: `brightness_${(Math.round(value * 6) + 1)}`
            value: root.monitor?.brightness ?? 0
            onMoved: root.monitor?.setBrightness(value)
        }
    }
}
