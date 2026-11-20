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

# Leave the desktop for Gaming Mode now (Steam's PIN locks it, if set)
away:
    /usr/libexec/legionforge-away

# Turn "go to Gaming Mode when waking in the desktop" on or off for this user
toggle-away-on-wake:
    #!/usr/bin/bash
    flag="${XDG_CONFIG_HOME:-$HOME/.config}/legionforge/no-away-on-wake"
    if [[ -e "$flag" ]]; then
      rm -f "$flag"; echo "ON: waking in the desktop goes to Gaming Mode (Steam PIN)."
    else
      mkdir -p "$(dirname "$flag")"; touch "$flag"; echo "OFF: the desktop wakes unlocked."
    fi
    echo "Takes effect at the next desktop session."

# Lock with Noctalia's own lock screen now, to try its on-screen keyboard
# (touch the lock screen, or tap the keyboard button next to the password box)
test-noctalia-lock:
    noctalia msg session lock
