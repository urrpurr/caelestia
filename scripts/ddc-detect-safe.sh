#!/usr/bin/env bash
# Scan-safe replacement for `ddcutil detect --brief` in services/Brightness.qml.
# Home box (haukur): 3 DP monitors, nvidia-open. Harmless anywhere else.
#
# WHY THIS EXISTS — do NOT "simplify" it back to a bare `ddcutil detect`:
#   Brightness.qml runs the detect at startup and again on EVERY
#   onMonitorsChanged. `ddcutil detect` (like --model/--sn) enumerates every
#   /dev/i2c-* bus, and i2c traffic on a connector whose output is powered down
#   asserts hotplug and RELIGHTS that panel. That closes a feedback loop:
#     blank the side monitors -> Quickshell.screens changes -> detect scans the
#     dark buses -> panels wake / connectors churn -> screens change again ->
#     detect again ... and quickshell's per-monitor bindings go null on the way
#     through (bar renders as a blurred smear on one screen, that screen stops
#     accepting clicks; `qs -c caelestia kill` + `caelestia shell -d` clears it).
#   Measured 2026-08-18: `ddcutil detect`/`--model` opens 11 buses, ~47 accesses
#   each on the side monitors' buses; a bus-scoped call opens exactly one.
#   Background: dotfiles repo docs/display-power-testing.md, findings F7/F8 and
#   standing rules 4b / 4b-i.
#
# POLICY: never scan while any connected output is dark. Serve the last good
# result from cache instead — a stale bus map costs nothing (DDC brightness on
# a dark panel is impossible anyway), relighting the desk costs a lot.
# The brightness WRITE path in Brightness.qml is already safe: it uses
# `ddcutil -b <bus> setvcp 10`, which touches one bus.
set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/caelestia"
CACHE="$CACHE_DIR/ddc-detect"

# Let the output change settle before sampling, and collapse bursts: during a
# blank/unblank the compositor's commit and the kernel's dpms state land a beat
# apart, and sampling too early would read "On" for a panel already going dark.
sleep 1

for conn in /sys/class/drm/card*-*/; do
    [[ -e "$conn/dpms" && -e "$conn/status" ]] || continue
    [[ "$(cat "$conn/status" 2>/dev/null)" == connected ]] || continue
    # Covers both dpms-off and compositor-disabled outputs: both read Off, and
    # both are panels we must not poke.
    if [[ "$(cat "$conn/dpms" 2>/dev/null)" != On ]]; then
        cat "$CACHE" 2>/dev/null   # may be empty on a cold cache; that is fine
        exit 0
    fi
done

mkdir -p "$CACHE_DIR"
if out=$(ddcutil detect --brief 2>/dev/null); then
    printf '%s\n' "$out" > "$CACHE"
    printf '%s\n' "$out"
else
    cat "$CACHE" 2>/dev/null
fi
