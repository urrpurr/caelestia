pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }

    // Monitors sorted by physical x position, so index 0 is the leftmost screen
    readonly property var monitorsByPos: [...Hypr.monitors.values].sort((a, b) => (a.lastIpcObject?.x ?? 0) - (b.lastIpcObject?.x ?? 0))

    property real blur: onSpecial ? 1 : 0

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: layout.implicitHeight + Tokens.padding.small

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

        ColumnLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Tokens.spacing.extraSmall)

            Repeater {
                model: root.monitorsByPos.length

                Item {
                    id: group

                    required property int index
                    readonly property var mon: root.monitorsByPos[index]
                    readonly property var wsList: Hypr.workspaces.values.filter(w => w.monitor?.name === group.mon?.name && !w.name.startsWith("special")).sort((a, b) => a.id - b.id)
                    readonly property int activeIdx: wsList.findIndex(w => w.id === (mon?.activeWorkspace?.id ?? -1))
                    readonly property bool isThisScreen: root.screen.name === mon?.name
                    readonly property bool monFocused: Hypr.focusedMonitor?.name === mon?.name
                    readonly property Item activeItem: pills.count > 0 && activeIdx >= 0 ? pills.itemAt(activeIdx) : null
                    readonly property Item colItem: col

                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: col.implicitWidth
                    implicitHeight: col.implicitHeight

                    // Capsule behind the workspace this screen is currently showing.
                    // Bright accent on the focused screen, muted on the others.
                    StyledRect {
                        visible: group.activeItem !== null
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: col.y + (group.activeItem?.y ?? 0)
                        implicitWidth: Tokens.sizes.bar.innerWidth - Tokens.padding.small
                        implicitHeight: group.activeItem?.size ?? 0
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

                    ColumnLayout {
                        id: col

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 0

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: group.index > 0 ? Tokens.padding.small : 0

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

                        Repeater {
                            id: pills

                            model: group.wsList.length

                            Workspace {
                                monFocused: group.monFocused
                                activeWsId: group.mon?.activeWorkspace?.id ?? -1
                                occupied: root.occupied
                                groupOffset: (group.wsList[index]?.id ?? index + 1) - index - 1
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const g = layout.childAt(event.x, event.y);
                if (!g)
                    return;
                const col = g.colItem ?? g;
                const ws = (col.childAt(event.x - g.x - col.x, event.y - g.y - col.y) as Workspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
                else
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
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

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: SpecialWorkspaces {
            screen: root.screen
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

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
