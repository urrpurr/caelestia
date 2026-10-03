pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Fork: backend for the utilities "Displays" card — global VRR switch plus a
// per-monitor refresh rate. Everything here is SESSION-ONLY by design.
//
// Mechanisms (checked against Hyprland 0.56.2 source, 2026-10-03):
// - VRR goes through global misc:vrr (0 off / 2 fullscreen-only). Per-monitor
//   vrr does NOT work at runtime: CMonitorRule::compare() ignores m_vrr, so a
//   vrr-only change via hl.monitor, `hyprctl reload` or wlr-output-management
//   is treated as "same rule" and silently skipped. Don't "upgrade" this to
//   per-monitor switches until that is fixed upstream.
// - Refresh rate goes through wlr-randr (wlr-output-management), NOT
//   `hyprctl eval hl.monitor(...)`. hl.monitor REPLACES the whole config rule
//   and hyprctl can't report the configured bitdepth, so a rebuilt rule drops
//   the OLED's bitdepth = 10 (auto-HDR). The protocol overrides only the mode
//   on top of the config rule; Hyprland keeps that override across config
//   reloads until it restarts — hence "session only".
// Requires: wlr-randr (dotfiles packages.toml).
Singleton {
    id: root

    // From `wlr-randr --json`, left-to-right:
    // {name, model, x, width, height, refreshRate, modes: [{width, height, refresh}]}
    property list<var> monitors: []

    // VRR override chosen in the card; null = follow the config. Re-applied
    // after config reloads (e.g. game mode off), which would reset misc:vrr.
    property var vrrOverride: null
    // Live misc:vrr, read with `hyprctl getoption`. NOT Hypr.options: with the
    // Lua config the plugin's `descriptions` parsing finds nothing (format
    // changed to {name, current}), and `current` there doesn't reflect
    // runtime evals anyway.
    property int vrr: 0
    readonly property bool vrrEnabled: vrr !== 0

    // Fork: the owner's names for the physical monitors, matched by model so
    // they survive port/cable changes. Unknown models fall back to the model.
    readonly property var labels: ({
            "VG279QM": "Asus",
            "PG32UCDM": "OLED",
            "U28E590": "Samsung"
        })

    function labelFor(mon: var, index: int): string {
        return `${index + 1} · ${labels[mon.model] ?? mon.model}`;
    }

    // Refresh rates at the monitor's current resolution, highest first, one
    // per whole number (keeps 120 over 119.88, 60 over 59.94). Exact values
    // from wlr-randr: it only accepts a rate that matches a mode to the mHz
    // (the Asus "144" is 144.001007), so hyprctl's 2-decimal list won't do.
    function ratesFor(mon: var): var {
        const best = ({});
        for (const m of mon.modes) {
            if (m.width !== mon.width || m.height !== mon.height)
                continue;
            const key = Math.round(m.refresh);
            if (best[key] === undefined || Math.abs(m.refresh - key) < Math.abs(best[key] - key))
                best[key] = m.refresh;
        }
        return Object.values(best).sort((a, b) => b - a);
    }

    function setVrr(enabled: bool): void {
        vrrOverride = enabled ? 2 : 0;
        Hypr.extras.applyOptions({
            "misc:vrr": vrrOverride
        });
        vrr = vrrOverride; // show it now; vrrCheck confirms the real value
        vrrCheck.restart();
    }

    function setRate(mon: var, rate: real): void {
        setRateProc.exec(["wlr-randr", "--output", mon.name, "--mode", `${mon.width}x${mon.height}@${rate.toFixed(3)}Hz`]);
    }

    function refresh(): void {
        monitorsProc.running = true;
        vrrProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: monitorsProc

        command: ["wlr-randr", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).filter(h => h.enabled).map(h => {
                        const cur = h.modes.find(m => m.current) ?? h.modes[0];
                        return {
                            name: h.name,
                            model: h.model,
                            x: h.position.x,
                            width: cur.width,
                            height: cur.height,
                            refreshRate: cur.refresh,
                            modes: h.modes
                        };
                    }).sort((a, b) => a.x - b.x);
                } catch (e) {
                    console.warn("Displays: bad wlr-randr output", e);
                }
            }
        }
    }

    // applyOptions is async — read back after it has landed
    Timer {
        id: vrrCheck

        interval: 300
        onTriggered: vrrProc.running = true
    }

    Process {
        id: vrrProc

        command: ["hyprctl", "getoption", "misc:vrr", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.vrr = JSON.parse(text).int;
                } catch (e) {
                    console.warn("Displays: bad hyprctl getoption output", e);
                }
            }
        }
    }

    Process {
        id: setRateProc

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    console.warn("Displays: wlr-randr:", text.trim());
            }
        }
        onExited: root.refresh()
    }

    Connections {
        function onConfigReloaded(): void {
            if (root.vrrOverride !== null)
                Hypr.extras.applyOptions({
                    "misc:vrr": root.vrrOverride
                });
            root.refresh();
            vrrCheck.restart();
        }

        target: Hypr
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name.startsWith("monitor"))
                root.refresh();
        }

        target: Hyprland
    }
}
