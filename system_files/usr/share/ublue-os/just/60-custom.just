# Legix recipes for the niri + Noctalia desktop. GNOME is not installed;
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
    /usr/libexec/legix-away

# Lock the desktop now (touch the lock screen for the on-screen keyboard)
lock:
    noctalia msg session lock

# Add back extras Legix leaves out of the image (for other hardware or dev work)
legix-extras:
    #!/usr/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    declare -A EXTRAS=(
      ["NVIDIA GPU firmware"]="nvidia-gpu-firmware"
      ["Intel GPU and Wi-Fi firmware, Intel OpenCL and microcode"]="intel-gpu-firmware intel-vsc-firmware iwlwifi-dvm-firmware iwlwifi-mld-firmware iwlwifi-mvm-firmware intel-opencl microcode_ctl"
      ["Compiler toolchain (gcc, g++, perl)"]="gcc gcc-c++ perl"
      ["ROCm compute (AMD OpenCL)"]="rocm-opencl rocm-smi rocm-clinfo"
      ["All languages (every glibc locale)"]="glibc-all-langpacks"
    )
    echo "Legix leaves these out to stay small. Pick any to download and add (space selects, enter confirms)."
    echo "Not available here: kernel headers for this kernel, ScopeBuddy, and Steam's offline bootstrap (Steam downloads itself)."
    mapfile -t picked < <(printf '%s\n' "${!EXTRAS[@]}" | sort | ugum choose --no-limit)
    (( ${#picked[@]} )) || { echo "Nothing selected."; exit 0; }
    pkgs=()
    for g in "${picked[@]}"; do pkgs+=(${EXTRAS[$g]}); done
    echo "Adding: ${pkgs[*]}"
    sudo rpm-ostree install --idempotent "${pkgs[@]}"
    echo "Done. Restart to use them. Undo any time with: sudo rpm-ostree uninstall <package>"

