pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool onSpecial: monitor?.lastIpcObject.specialWorkspace?.name !== ""

    // Custom: every screen's workspaces, grouped per screen (upstream's shown/showUnoccupied/perMonitor
    // windowing doesn't apply). Monitors sorted by physical x position, so index 0 is the leftmost screen.
    readonly property var monitorsByPos: [...Hypr.monitors.values].sort((a, b) => (a.lastIpcObject?.x ?? 0) - (b.lastIpcObject?.x ?? 0))

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: groups.implicitHeight + Tokens.padding.extraSmall * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        // One group per screen: monitor header, then that screen's workspaces.
        // Filled accent capsule = focused screen's active workspace; outline ring = other screens' active one.
        ColumnLayout {
            id: groups

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.extraSmall

            spacing: 0

            Repeater {
                model: root.monitorsByPos.length

                Item {
                    id: group

                    required property int index
                    readonly property HyprlandMonitor mon: root.monitorsByPos[index] ?? null
                    readonly property var wsIds: Hypr.workspaces.values.filter(w => w.monitor === group.mon && !w.name.startsWith("special")).map(w => w.id).sort((a, b) => a - b)
                    readonly property int activeWsId: mon?.activeWorkspace?.id ?? -1
                    readonly property bool isThisScreen: root.monitor === mon
                    readonly property bool monFocused: Hypr.focusedMonitor === mon
                    readonly property Workspace activeItem: {
                        list.itemsDirty;
                        return list.itemAtIndex(wsIds.indexOf(activeWsId)) as Workspace;
                    }

                    Layout.fillWidth: true
                    Layout.topMargin: index > 0 ? Tokens.padding.small : 0
                    implicitHeight: header.implicitHeight + list.layoutHeight

                    StyledRect {
                        visible: group.activeItem !== null
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: list.y + (group.activeItem?.LazyListView.layoutY ?? 0)
                        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                        implicitHeight: group.activeItem?.LazyListView.preferredHeight ?? 0
                        radius: Tokens.rounding.full
                        color: group.monFocused ? Colours.palette.m3primary : "transparent"
                        border.width: group.monFocused ? 0 : 1
                        border.color: Colours.palette.m3outline

                        Behavior on y {
                            Anim {}
                        }

                        Behavior on implicitHeight {
                            Anim {}
                        }
                    }

                    RowLayout {
                        id: header

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        MaterialIcon {
                            text: "monitor"
                            color: group.isThisScreen ? Colours.palette.m3primary : Colours.palette.m3outline
                        }

                        StyledText {
                            text: group.index.toString()
                            color: group.isThisScreen ? Colours.palette.m3primary : Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }

                    LazyListView {
                        id: list

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: header.bottom
                        implicitHeight: contentHeight

                        spacing: 0
                        removeDuration: Tokens.anim.durations.expressiveDefaultEffects

                        model: ScriptModel {
                            values: group.wsIds
                        }

                        delegate: Workspace {
                            activeWsId: group.activeWsId
                            ws: modelData
                            monitor: group.mon
                            monFocused: group.monFocused
                            showNumber: true

                            displayType: Config.bar.workspaces.displayType
                            showWindows: Config.bar.workspaces.showWindows
                            iconRules: GlobalConfig.bar.workspaces.workspaceIcons
                            activeLabel: Config.bar.workspaces.activeLabel
                            occupiedLabel: Config.bar.workspaces.occupiedLabel
                            label: Config.bar.workspaces.label
                        }
                    }

                    MouseArea {
                        anchors.fill: list
                        onClicked: event => {
                            const ws = (list.itemAt(event.x, event.y) as Workspace)?.ws;
                            if (!ws)
                                return;
                            if (Hypr.activeWsId !== ws)
                                Hypr.focusWorkspace(ws);
                            else
                                Hypr.toggleSpecial("special");
                        }
                    }
                }
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        anchors.fill: parent

        asynchronous: true
        active: opacity > 0
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: Item {
            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.full
                color: Qt.alpha(Colours.palette.m3scrim, Colours.light ? 0 : 0.2)
            }

            SpecialWorkspaces {
                anchors.fill: parent
                anchors.margins: Tokens.padding.extraSmall
                monitor: root.monitor

                scale: 0.5
                Component.onCompleted: scale = Qt.binding(() => root.onSpecial ? 1 : 0.5)

                Behavior on scale {
                    Anim {}
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
