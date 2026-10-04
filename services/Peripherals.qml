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
    // Xbox controller (xone/GIP): discrete level only — the protocol carries
    // no percentage and no charging concept (owner-documented driver contract:
    // capacity_level Low/Normal/High/Full, or Unknown = empty bay/USB-powered;
    // sysfs node exists only while the controller session is active).
    property var controllerLevel: null
    property bool controllerNoBattery: false
    // Level → pseudo-pct lands exactly in the severity bands
    readonly property var controllerPct: controllerLevel !== null ? ({ "Low": 15, "Normal": 45, "High": 75, "Full": 100 })[controllerLevel] ?? null : null

    // Lowest present battery, charging or not — drives the dashboard tab icon so
    // a low device shows without opening the tab. Charging devices are NOT
    // excluded (that hid a phone at 21% on charge behind "full"): they show a
    // charging glyph instead, and only the colour skips them (never an alarm).
    readonly property var lowest: {
        const devs = [];
        if (mousePct !== null)
            devs.push({ pct: mousePct, charging: mouseCharging });
        if (phonePct !== null)
            devs.push({ pct: phonePct, charging: phoneCharging });
        if (controllerPct !== null)
            devs.push({ pct: controllerPct, charging: false });
        return devs.length ? devs.reduce((a, b) => b.pct < a.pct ? b : a) : null;
    }
    readonly property string lowestIcon: {
        if (lowest === null || lowest.pct >= 95)
            return lowest?.charging ? "battery_charging_full" : "battery_full";
        if (lowest.charging) {
            const steps = [[25, 20], [40, 30], [55, 50], [70, 60], [85, 80], [95, 90]];
            return `battery_charging_${steps.find(([max]) => lowest.pct < max)[1]}`;
        }
        return `battery_${Math.min(6, Math.floor(lowest.pct / 100 * 7))}_bar`;
    }

    // Severity mirrors battery.sh: <25% error, <50% warn, charging is never an alarm
    function sevColour(pct, charging: bool): color {
        if (charging || pct === null)
            return Colours.palette.m3primary;
        if (pct < 25)
            return Colours.palette.m3error;
        if (pct < 50)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

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
            xl="null"; xnb=0
            for g in /sys/class/power_supply/gip*/capacity_level; do
                [ -r "$g" ] || continue
                lvl=$(cat "$g")
                if [ "$lvl" = "Unknown" ]; then xnb=1; else xl="\\"$lvl\\""; fi
                break
            done
            printf '{"mousePct":%s,"mouseCharging":%s,"phoneReachable":%s,"phonePct":%s,"phoneCharging":%s,"controllerLevel":%s,"controllerNoBattery":%s}' "\${mp:-null}" $mc $pr "\${pp:-null}" $pc "$xl" $xnb
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
                    root.controllerLevel = d.controllerLevel;
                    root.controllerNoBattery = !!d.controllerNoBattery;
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

    Process {
        id: controllerMonitor

        // Xbox controller on/off = its power_supply node appearing/vanishing
        // (wireless via always-plugged dongle — no usb event, unlike the mouse)
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
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
            controllerMonitor.running = true;
        }
    }
}
