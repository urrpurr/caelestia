pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fork addition: peripheral battery states for the dashboard "Batteries" tab.
// Ported from the retired waybar battery.sh (dotfiles repo) — same sources:
//   mouse: openrazer sysfs (charge_level 0-255, charge_status 1=charging).
//          A 0% reading during USB handshake is reported as absent, not 0 —
//          a truly 0% mouse would be dead (battery.sh had the same guard).
//   phone: kdeconnect DBus (isReachable, battery charge, isCharging).
// Phone device id: Galaxy S25+ — rediscover with `kdeconnect-cli -l` if it
// ever re-pairs under a new id.
Singleton {
    id: root

    readonly property string phoneId: "d678b5f49b8d43c4b1801fdc71af6b63"

    // null when absent/unreadable
    property var mousePct: null
    property bool mouseCharging: false
    property bool phoneReachable: false
    property var phonePct: null
    property bool phoneCharging: false

    function refresh(): void {
        proc.running = true;
    }

    Process {
        id: proc

        command: ["bash", "-c", `
            read_mouse() {
                mp=""; mc=0
                for f in /sys/bus/hid/drivers/razermouse/*/charge_level; do
                    [ -r "$f" ] || continue
                    p=$(( $(cat "$f") * 100 / 255 ))
                    if [ -z "$mp" ] || [ "$p" -gt "$mp" ]; then
                        mp=$p
                        s="\${f%charge_level}charge_status"
                        { [ -r "$s" ] && [ "$(cat "$s")" = 1 ]; } && mc=1 || mc=0
                    fi
                done
            }
            # 0% right after plug/unplug is the handshake, not a reading —
            # retry like waybar's battery.sh did (instant when the read is good)
            read_mouse
            for _ in 1 2; do
                [ "$mp" = "0" ] || break
                sleep 1
                read_mouse
            done
            [ "$mp" = "0" ] && mp=""
            pp=""; pc=0; pr=0
            dev=/modules/kdeconnect/devices/${root.phoneId}
            if [ "$(busctl --user get-property org.kde.kdeconnect $dev org.kde.kdeconnect.device isReachable 2>/dev/null)" = "b true" ]; then
                pr=1
                c=$(busctl --user get-property org.kde.kdeconnect $dev/battery org.kde.kdeconnect.device.battery charge 2>/dev/null)
                c=\${c#i }
                { [ -n "$c" ] && [ "$c" -ge 0 ] 2>/dev/null; } && pp=$c
                [ "$(busctl --user get-property org.kde.kdeconnect $dev/battery org.kde.kdeconnect.device.battery isCharging 2>/dev/null)" = "b true" ] && pc=1
            fi
            printf '{"mousePct":%s,"mouseCharging":%s,"phoneReachable":%s,"phonePct":%s,"phoneCharging":%s}' "\${mp:-null}" $mc $pr "\${pp:-null}" $pc
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.mousePct = d.mousePct;
                    root.mouseCharging = !!d.mouseCharging;
                    root.phoneReachable = !!d.phoneReachable;
                    root.phonePct = d.phonePct;
                    root.phoneCharging = !!d.phoneCharging;
                } catch (e) {
                    console.warn("Peripherals: bad poll output:", text);
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Event-driven refresh (poll above is only the fallback), same triggers the
    // waybar setup used: kdeconnect signals the instant the phone pushes
    // battery state or (un)reaches; udev fires on the mouse's USB plug/unplug.

    Process {
        id: phoneMonitor

        command: ["dbus-monitor", "--profile",
            "type='signal',interface='org.kde.kdeconnect.device.battery',member='refreshed'",
            "type='signal',interface='org.kde.kdeconnect.device',member='reachableChanged'"]
        running: true

        stdout: SplitParser {
            onRead: root.refresh()
        }
        onExited: monitorRestartTimer.start() // qmllint disable signal-handler-parameters
    }

    Process {
        id: mouseMonitor

        // Razer vendor id 1532. Match PRODUCT=, NOT ID_VENDOR_ID= — usb REMOVE
        // events carry no ID_VENDOR_ID, so unplugs would be invisible (trap
        // documented in the old 99-razer-waybar.rules, re-verified 2026-08-13).
        command: ["bash", "-c", "stdbuf -oL udevadm monitor --udev --property --subsystem-match=usb | stdbuf -oL grep --line-buffered 'PRODUCT=1532/'"]
        running: true

        stdout: SplitParser {
            onRead: root.refresh()
        }
        onExited: monitorRestartTimer.start() // qmllint disable signal-handler-parameters
    }

    Timer {
        id: monitorRestartTimer

        interval: 5000
        onTriggered: {
            phoneMonitor.running = true;
            mouseMonitor.running = true;
        }
    }
}
