pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property SystemTrayItem modelData
    // Fork: index aligns with popouts/Content.qml's traymenu<i> popouts —
    // both repeaters use the same hiddenIcons-filtered SystemTray list
    required property int index
    property var popouts
    property Item barRoot

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    implicitWidth: Tokens.font.body.small.pointSize * 2
    implicitHeight: Tokens.font.body.small.pointSize * 2

    // Fork: right-click opens the item's MENU popout (hover popouts are
    // disabled on this setup — same right-click convention as the status
    // pill). secondaryActivate moved to middle-click, its SNI-conventional
    // home.
    onClicked: event => {
        if (event.button === Qt.LeftButton) {
            modelData.activate();
        } else if (event.button === Qt.MiddleButton) {
            modelData.secondaryActivate();
        } else if (popouts && barRoot) {
            popouts.currentName = `traymenu${index}`;
            popouts.currentCenter = Qt.binding(() => root.mapToItem(root.barRoot, 0, root.implicitHeight / 2).y);
            popouts.hasCurrent = true;
        }
    }

    ColouredIcon {
        id: icon

        anchors.fill: parent
        source: Icons.getTrayIcon(root.modelData.id, root.modelData.icon)
        colour: Colours.palette.m3secondary
        layer.enabled: Config.bar.tray.recolour
    }
}
