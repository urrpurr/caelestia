import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        Brightness;
        // Fork: eager-load so the battery watchers (kdeconnect dbus + razer
        // udev) run from shell start, not from first dashboard open
        Peripherals;
        Weather.reload();

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }
}
