# LegionForge recipes for the niri + Noctalia desktop. GNOME is not installed;
# GNOME-only Bazzite recipes are removed at build time (see build.sh).

# Re-run Noctalia's first-start setup wizard (current settings are backed up)
restore-noctalia-setup:
    #!/usr/bin/bash
    set -euo pipefail
    cfg="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/settings.toml"
    if [[ -f "$cfg" ]]; then
      mv -v "$cfg" "$cfg.bak.$(date +%Y%m%d-%H%M%S)"
    else
      echo "No Noctalia settings found; the wizard will already run on next start."
    fi
    # Only restarts it if it is running (i.e. inside a niri session).
    systemctl --user try-restart noctalia.service || true
    echo "Noctalia's setup wizard runs on its next start (now, if niri is running)."

# On-screen keyboard help for niri
restore-virtual-keyboard:
    #!/usr/bin/bash
    echo "niri has no built-in on-screen keyboard."
    echo "While Steam is running, press STEAM + X to open Steam's keyboard over any app."

# Check your niri config for errors
niri-validate:
    niri validate
