#!/usr/bin/env bash
# Copy the firmware to the Pico:  firmware/deploy.sh [port]   (default: auto)
#
# main.py arms a 2 s watchdog, so a plain `mpremote cp` races a reboot.
# Drop a 'nomain' flag first (main.py exits at boot while it exists), copy,
# then remove the flag and reset.
set -euo pipefail
cd "$(dirname "$0")"
mp() { mpremote connect "${1:-auto}" "${@:2}"; }
PORT="${1:-auto}"

mp "$PORT" exec "open('/nomain', 'w').close()" || true   # WDT reboots right after
sleep 3
MICROPYTHON=1.29.0      # the version the firmware is tested against (RGX-2-003 §2)
have=$(mp "$PORT" exec "import os; print(os.uname().release)" 2>/dev/null | tr -d '\r' || true)
[ "$have" = "$MICROPYTHON" ] || echo "warning: the Pico runs MicroPython $have, not $MICROPYTHON" >&2
mp "$PORT" cp config.py control.py sensors.py ui.py vesc.py main.py :
mp "$PORT" exec "import os; os.remove('/nomain')"
mp "$PORT" reset
