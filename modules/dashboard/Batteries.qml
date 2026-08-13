pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Fork addition: "Batteries" dashboard tab — peripheral battery levels,
// migrated from the retired waybar battery pill. Data: services/Peripherals.qml.
// Severity mirrors battery.sh: <25% error, <50% warn, charging is never an alarm.
Item {
    id: root

    // Floor on the width: the dashboard sizes itself to the visible pane, and
    // a narrow pane crushes the five tab labels together
    implicitWidth: Math.max(layout.implicitWidth + Tokens.padding.large * 2, 700)
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    function sevColour(pct, charging: bool): color {
        if (charging || pct === null)
            return Colours.palette.m3primary;
        if (pct < 25)
            return Colours.palette.m3error;
        if (pct < 50)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.large

        DeviceRow {
            icon: "mouse"
            name: qsTr("Razer Naga V2 Pro")
            pct: Peripherals.mousePct
            charging: Peripherals.mouseCharging
            absentText: qsTr("Not detected (dongle off or asleep)")
        }

        DeviceRow {
            icon: "smartphone"
            name: qsTr("Galaxy S25+")
            pct: Peripherals.phonePct
            charging: Peripherals.phoneCharging
            absentText: Peripherals.phoneReachable ? qsTr("Connected, no battery data yet") : qsTr("Not connected (off LAN or kdeconnectd down)")
        }

        DeviceRow {
            // GIP protocol: discrete level, no percentage, no charging concept.
            // Level → pseudo-pct lands exactly in the severity bands.
            readonly property var levelMap: ({ "Low": 15, "Normal": 45, "High": 75, "Full": 100 })

            icon: "sports_esports"
            name: qsTr("Xbox controller")
            pct: Peripherals.controllerLevel !== null ? levelMap[Peripherals.controllerLevel] ?? null : null
            valueText: Peripherals.controllerLevel ?? ""
            charging: false
            absentText: Peripherals.controllerNoBattery ? qsTr("No battery (USB powered or empty bay)") : qsTr("Off / not connected")
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
            color: root.sevColour(row.pct, row.charging)
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
                    color: root.sevColour(row.pct, row.charging)
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
                fgColour: root.sevColour(row.pct, row.charging)
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
