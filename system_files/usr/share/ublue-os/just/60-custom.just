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
    echo "On-screen keyboard: tap the keyboard button on Noctalia's bar."
    echo "On the lock screen: touch the screen, or tap the keyboard button by the password box."
    echo "While Steam is running, STEAM + X also opens Steam's keyboard over any app."

# Check your niri config for errors
niri-validate:
    niri validate

# Leave the desktop for Gaming Mode now (Steam's PIN applies, if set)
away:
    /usr/libexec/legionforge-away

# Lock now with Noctalia's lock screen (touch it, or tap the keyboard button
# next to the password box, for the on-screen keyboard)
lock:
    noctalia msg session lock
