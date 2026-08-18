pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts

    implicitWidth: layout.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ButtonGroup {
        id: sinks
    }

    // Closes and reopens the ALSA device. Recovers a wireless headset that
    // auto-powered-off while an app held an uncorked stream: the USB
    // transmitter keeps consuming audio at 48kHz and never renegotiates when
    // the headset wakes, so playback is silent with no kernel error. Same
    // effect as swapping output device away and back.
    Process {
        id: reconnectSink

        command: ["sh", "-c", "pactl suspend-sink @DEFAULT_SINK@ 1; sleep 0.3; pactl suspend-sink @DEFAULT_SINK@ 0"]
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Output device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sinks

            StyledRadioButton {
                id: control

                required property PwNode modelData

                ButtonGroup.group: sinks
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setAudioSink(modelData)
                text: modelData.description
            }
        }

        IconTextButton {
            // Only the Stealth 600P needs this; hidden (and dropped from the
            // layout) on any other sink or machine.
            visible: Audio.sink?.name?.includes("Turtle_Beach") ?? false

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("Reconnect output")
            icon: "restart_alt"

            onClicked: reconnectSink.running = true
        }

        // Fork: input-device section moved to MicPopout.qml (mic icon's popout)

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: value => Audio.setVolume(value)
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}
