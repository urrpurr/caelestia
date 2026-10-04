pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Fork addition: "Batteries" dashboard tab — peripheral battery levels,
// migrated from the retired waybar battery pill. Data: services/Peripherals.qml.
// Severity colours: Peripherals.sevColour.
Item {
    id: root

    // Floor on the width: the dashboard sizes itself to the visible pane, and
    // a narrow pane crushes the five tab labels together
    implicitWidth: Math.max(layout.implicitWidth + Tokens.padding.large * 2, 700)
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.large

        DeviceRow {
            icon: "mouse"
            name: "Razer Naga V2 Pro"
            pct: Peripherals.mousePct
            charging: Peripherals.mouseCharging
            absentText: Tr.tr("Not detected (dongle off or asleep)")
        }

        DeviceRow {
            icon: "smartphone"
            name: "Galaxy S25+"
            pct: Peripherals.phonePct
            charging: Peripherals.phoneCharging
            absentText: Peripherals.phoneReachable ? Tr.tr("Connected, no battery data yet") : Tr.tr("Not connected (off LAN or kdeconnectd down)")
        }

        DeviceRow {
            // GIP protocol: discrete level, no percentage, no charging concept
            icon: "sports_esports"
            name: Tr.tr("Xbox controller")
            pct: Peripherals.controllerPct
            valueText: Peripherals.controllerLevel ?? ""
            charging: false
            absentText: Peripherals.controllerNoBattery ? Tr.tr("No battery (USB powered or empty bay)") : Tr.tr("Off / not connected")
        }
    }

    component DeviceRow: RowLayout {
        id: row

        required property string icon
        required property string name
        required property var pct
        required property bool charging
        required property string absentText
        property string valueText: pct !== null ? `${pct}%` : ""

        readonly property bool present: pct !== null

        spacing: Tokens.spacing.large

        MaterialIcon {
            text: row.icon
            color: Peripherals.sevColour(row.pct, row.charging)
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            spacing: Tokens.spacing.small / 2

            RowLayout {
                spacing: Tokens.spacing.small

                StyledText {
                    text: row.name
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }

                StyledText {
                    text: row.present ? row.valueText : ""
                    color: Peripherals.sevColour(row.pct, row.charging)
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                }

                MaterialIcon {
                    visible: row.charging
                    text: "bolt"
                    color: Colours.palette.m3primary
                }
            }

            StyledProgressBar {
                Layout.preferredWidth: 420
                visible: row.present
                value: (row.pct ?? 0) / 100
                fgColour: Peripherals.sevColour(row.pct, row.charging)
                wavy: row.charging
            }

            StyledText {
                visible: !row.present
                text: row.absentText
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
        }
    }
}
