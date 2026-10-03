pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Fork: quick display controls — global VRR switch + per-monitor refresh
// rate. Session only; see services/Displays.qml for why VRR is global and
// why refresh goes through wlr-randr.
StyledRect {
    id: root

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLargeIncreased

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: icon.implicitHeight + Tokens.padding.large

                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    text: "desktop_windows"
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Displays")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Session only — resets when Hyprland restarts")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("VRR in fullscreen")
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }

            StyledSwitch {
                checked: Displays.vrrEnabled
                onToggled: Displays.setVrr(checked)
            }
        }

        Repeater {
            model: Displays.monitors

            RowLayout {
                id: row

                required property var modelData
                required property int index

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Displays.labelFor(row.modelData, row.index)
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                SplitButton {
                    type: SplitButton.Tonal
                    menuOnTop: true
                    fallbackText: `${Math.round(row.modelData.refreshRate)} Hz`

                    menuItems: rates.instances
                    active: menuItems.find(m => (m as RateItem).current) ?? null

                    Variants {
                        id: rates

                        model: Displays.ratesFor(row.modelData)

                        RateItem {
                            mon: row.modelData
                        }
                    }
                }
            }
        }
    }

    component RateItem: MenuItem {
        required property var modelData
        required property var mon
        readonly property bool current: Math.round(modelData) === Math.round(mon.refreshRate)

        icon: current ? "check" : ""
        text: `${Math.round(modelData)} Hz`
        onClicked: {
            if (!current)
                Displays.setRate(mon, modelData);
        }
    }
}
