# LegionForge recipes for the niri + Noctalia desktop. GNOME is not installed;
# GNOME-only Bazzite recipes are removed at build time (see build.sh).

# Re-run Noctalia's first-start setup wizard (current settings are backed up)
restore-noctalia-setup:
    #!/usr/bin/bash
    set -euo pipefail
    state="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia"
    backup="$HOME/noctalia-state-backup-$(date +%Y%m%d-%H%M%S)"
    running=false
    systemctl --user is-active -q noctalia.service && running=true
    $running && systemctl --user stop noctalia.service
    if [[ -d "$state" ]]; then
      mv -v "$state" "$backup"
    else
      echo "No Noctalia state found; the wizard will already run on next start."
    fi
    # Only start it again if it was running (i.e. inside a niri session).
    $running && systemctl --user start noctalia.service
    echo "Noctalia's setup wizard runs on its next start (now, if niri is running)."

# On-screen keyboard help for niri
restore-virtual-keyboard:
    #!/usr/bin/bash
    echo "niri has no built-in on-screen keyboard."
    echo "While Steam is running, press STEAM + X to open Steam's keyboard over any app."

# Check your niri config for errors
niri-validate:
    niri validate

# Turn "lock the desktop when niri starts" on or off for this user
toggle-desktop-lock:
    #!/usr/bin/bash
    flag="${XDG_CONFIG_HOME:-$HOME/.config}/legionforge/no-lock-on-desktop"
    if [[ -e "$flag" ]]; then
      rm -f "$flag"; echo "Desktop lock ON: niri locks as soon as it starts."
    else
      mkdir -p "$(dirname "$flag")"; touch "$flag"; echo "Desktop lock OFF: niri opens unlocked."
    fi

# Lock the screen now (to check your password unlocks it)
test-lock:
    noctalia msg session lock
