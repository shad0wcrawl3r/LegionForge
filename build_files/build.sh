#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# niri (scrollable tiling Wayland compositor) + Noctalia shell, all from the
# official Fedora repos, so no COPRs to maintain. Dotfiles are user-provided.
#  - xwayland-satellite: X11 app support under niri
#  - xdg-desktop-portal-gnome/gtk: portals niri uses for screencast & file pickers
#  - wtype: types the Noctalia on-screen keyboard's keys (Keyboard plugin)
# Noctalia: our patched build (lock-screen on-screen keyboard) when one was
# produced, otherwise Fedora's package.
mapfile -t NOCTALIA_PKG < <(ls /ctx/noctalia-rpms/noctalia-*.rpm 2>/dev/null || echo noctalia)
dnf5 install -y \
    niri \
    "${NOCTALIA_PKG[@]}" \
    wtype \
    xwayland-satellite \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk

# Make Steam's "Switch to Desktop" open niri (see /usr/lib/os-session-select).
chmod 0755 /usr/lib/os-session-select
# steamos-manager's default desktop for direct steamosctl calls. Fail the
# build if Bazzite changes this file, rather than silently keeping GNOME.
sed -i 's/^desktop = "gnome.desktop"$/desktop = "niri.desktop"/' \
    /usr/share/steamos-manager/platform.toml
grep -qx 'desktop = "niri.desktop"' /usr/share/steamos-manager/platform.toml

#### Remove the GNOME desktop: niri is the only desktop.
# SDDM (not GDM) handles autologin into Gaming Mode and Switch to Desktop.
# Keep what niri still needs. pam_oo7 matters: it is only installed because
# gdm requires it, yet SDDM's PAM stack uses it to unlock the oo7 password
# store at login, so it must not be autoremoved along with gdm.
KEEP=(
    sddm
    oo7-daemon oo7-portal pam_oo7
    xdg-desktop-portal-gnome xdg-desktop-portal-gtk
    nautilus gnome-disk-utility
    NetworkManager-openvpn-gnome NetworkManager-openconnect-gnome
    pinentry-gnome3 adw-gtk3-theme
)
dnf5 mark -y user "${KEEP[@]}"

# Remove exactly the listed packages. dnf would silently remove anything that
# depends on them too, so fail the build if the removed set differs from the
# list (the dependency analysis behind these lists: see the GNOME dependency
# graph linked from CONTRIBUTING.md).
remove_exactly() {
    local before after removed
    before="$(rpm -qa --qf '%{NAME}\n' | sort -u)"
    dnf5 remove -y "$@"
    after="$(rpm -qa --qf '%{NAME}\n' | sort -u)"
    removed="$(comm -23 <(echo "$before") <(echo "$after"))"
    if [[ "$removed" != "$(printf '%s\n' "$@" | sort -u)" ]]; then
        echo "remove_exactly: dnf removed a different set than requested:" >&2
        diff <(printf '%s\n' "$@" | sort -u) <(echo "$removed") >&2 || true
        exit 1
    fi
}

# Stage 1: the GNOME desktop itself.
remove_exactly \
    gdm \
    gnome-shell \
    gnome-session \
    gnome-session-wayland-session \
    gnome-control-center \
    gnome-shell-extension-common \
    gnome-shell-extension-gsconnect \
    gnome-shell-extension-user-theme \
    gnome-browser-connector \
    nautilus-gsconnect \
    gnome-search-yafti \
    gnome-remote-desktop \
    gnome-user-share \
    steamdeck-gnome-presets

# Stage 2: GNOME pieces nothing outside GNOME requires any more (~155 MB).
# Deliberately kept despite having no dependents: NetworkManager-openvpn-gnome,
# NetworkManager-openconnect-gnome and libnma* (VPN auth dialogs),
# pinentry-gnome3 (GUI GPG passphrase prompt) and adw-gtk3-theme (GTK3 theme).
remove_exactly \
    gnome-user-docs \
    gnome-backgrounds desktop-backgrounds-gnome \
    f45-backgrounds-gnome f45-backgrounds-gnome-time-of-day \
    evolution-data-server evolution-data-server-langpacks \
    evolution-ews-core evolution-ews-langpacks \
    gnome-online-accounts \
    mutter mutter-common \
    gnome-settings-daemon \
    gjs \
    gnome-bluetooth gnome-bluetooth-libs \
    gnome-color-manager \
    gnome-menus \
    gnome-app-list \
    gnome-shell-common \
    gnome-control-center-filesystem \
    gnome-epub-thumbnailer \
    nautilus-python \
    papers-nautilus \
    fedora-chromium-config-gnome

rpm -q "${KEEP[@]}"
test ! -e /usr/share/wayland-sessions/gnome.desktop

# GNOME Shell extensions that Bazzite copies in without an RPM (Caffeine,
# Burn My Windows, Add to Steam, Blur My Shell, Desktop Cube, ...). They are
# dead weight without gnome-shell. Fail if any file still belongs to a package,
# so a packaged extension is never deleted behind rpm's back.
if [[ -d /usr/share/gnome-shell/extensions ]]; then
    owned="$(find /usr/share/gnome-shell/extensions -type f -print0 \
        | xargs -0 -r rpm -qf 2>/dev/null | grep -v 'not owned' | sort -u || true)"
    if [[ -n "$owned" ]]; then
        echo "GNOME Shell extensions still owned by packages:" >&2
        echo "$owned" >&2
        exit 1
    fi
    rm -rf /usr/share/gnome-shell/extensions
fi
rmdir /usr/share/gnome-shell 2>/dev/null || true

# Switch to Desktop from OpenGamepadUI/Steam goes straight to steamos-manager,
# which uses the per-user desktop_session (it overrides platform.toml and may
# still say gnome.desktop). Re-assert niri at every login.
chmod 0755 /usr/libexec/legix-desktop-session
systemctl --global enable legix-desktop-session.service

# ujust: drop GNOME-only recipes. Every recipe file is a mandatory import, so
# empty 90-bazzite-de.just (restore-gnome-de-settings, restore-gnome-folders)
# rather than deleting it. restore-virtual-keyboard is replaced by the niri
# version in 60-custom.just.
grep -q '^restore-gnome-de-settings:' /usr/share/ublue-os/just/90-bazzite-de.just
echo "# Legix: GNOME is not installed; GNOME recipes removed." \
    > /usr/share/ublue-os/just/90-bazzite-de.just
/ctx/drop_just_recipe.py /usr/share/ublue-os/just/85-bazzite-image.just restore-virtual-keyboard
JUST_JUSTFILE=/usr/share/ublue-os/justfile just --list > /dev/null

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

#### Don't open Bazzite Portal (the welcome/help window) at every login.
# Bazzite seeds it into new homes via /etc/skel; the app itself stays in the
# launcher.
rm -f /etc/skel/.config/autostart/bazzite-portal.desktop

#### Noctalia: start automatically in niri sessions
# Use the systemd user unit Noctalia ships as a template, so it tracks
# upstream. It is pulled in by niri.service only, never by GNOME or Gaming
# Mode. Its first-run wizard state is not shipped: on first start Noctalia
# runs the wizard and saves choices to ~/.local/state/noctalia/settings.toml,
# layered over the Legix defaults below.
# Opt out per user: systemctl --user mask noctalia.service
install -Dm0644 /usr/share/noctalia/assets/noctalia.service \
    /usr/lib/systemd/user/noctalia.service
mkdir -p /usr/lib/systemd/user/niri.service.wants
ln -sf ../noctalia.service /usr/lib/systemd/user/niri.service.wants/noctalia.service
# Seed Legix's Noctalia defaults (full-width bar, icon-only widgets)
# into ~/.config/noctalia before Noctalia starts. See noctalia.service.d/.
chmod 0755 /usr/libexec/legix-noctalia-defaults

#### Desk security (LFORGE-15/18): Noctalia's lock screen, unlockable with
# its on-screen keyboard (noctalia-osk build), locks on idle and before
# suspend (Noctalia defaults above). legix-away ("Gaming Mode (Steam
# PIN)" in the power menu, `ujust away`) leaves the desktop for Steam's PIN.
chmod 0755 /usr/libexec/legix-away
# Pre-rename name, in case a user's own Noctalia config still calls it.
ln -sf legix-away /usr/libexec/legionforge-away
# Noctalia's lock screen authenticates through this PAM service.
test -e /etc/pam.d/noctalia

#### Image signature verification on the device (LFORGE-7)
# Trust Legix's cosign key for ghcr.io/shad0wcrawl3r/legix, the
# same way Bazzite trusts ghcr.io/ublue-os. Devices then switch once with
# `bootc switch --enforce-container-sigpolicy` and refuse unsigned updates.
# The project was called LegionForge until 2026-11-20. Images are published
# under both names for the move, so trust both, with the same key. The old
# key path is kept for devices whose policy.json was edited locally.
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/legix.pub
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/legionforge.pub
policy=/etc/containers/policy.json
for repo in ghcr.io/shad0wcrawl3r/legix ghcr.io/shad0wcrawl3r/legionforge; do
  jq --arg repo "$repo" \
     --arg key "/etc/pki/containers/legix.pub" \
     '.transports.docker[$repo] = [{"type": "sigstoreSigned", "keyPath": $key, "signedIdentity": {"type": "matchRepository"}}]' \
     "$policy" > "$policy.new"
  mv "$policy.new" "$policy"
  jq -e --arg repo "$repo" '.transports.docker[$repo][0].type == "sigstoreSigned"' "$policy"
done

#### Legix boot animation (Plymouth script theme)
# Replaces Bazzite's default (bgrt: firmware logo + spinner). Theme files come
# from system_files/; the PNG parts are rendered in the plymouth-assets stage.
dnf5 install -y plymouth-plugin-script
install -m0644 /ctx/plymouth/*.png /usr/share/plymouth/themes/legix/
plymouth-set-default-theme legix
grep -qx 'Theme=legix' /etc/plymouth/plymouthd.conf
# Plymouth runs from the initramfs, so rebuild it with the theme inside. The
# atomic/bootc dracut settings in /usr/lib/dracut/dracut.conf.d still apply.
mapfile -t KVERS < <(ls /usr/lib/modules)
test "${#KVERS[@]}" -eq 1
KVER="${KVERS[0]}"
dracut --no-hostonly --kver "$KVER" --reproducible -v --add ostree \
    -f "/usr/lib/modules/$KVER/initramfs.img"
chmod 0600 "/usr/lib/modules/$KVER/initramfs.img"

#### Legix branding (the OS is Legix, based on Bazzite)
# os-release: what fastfetch, the boot menu, hostnamectl and "About" show.
# ID stays "bazzite" (and ID_LIKE fedora): Bazzite's own tools (ujust,
# updates, helpers) check it, so changing it would break them.
osr=/usr/lib/os-release
setkv() { sed -i "/^$1=/d" "$osr"; printf '%s=%s\n' "$1" "$2" >> "$osr"; }
bl_old="$(sed -n 's/^BOOTLOADER_NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$osr")"
setkv NAME '"Legix"'
setkv PRETTY_NAME '"Legix"'
setkv LOGO 'legix-logo'
setkv ANSI_COLOR '"0;38;2;229;67;45"'
setkv DEFAULT_HOSTNAME '"legix"'
setkv HOME_URL '"https://github.com/shad0wcrawl3r/legix"'
setkv DOCUMENTATION_URL '"https://github.com/shad0wcrawl3r/legix#readme"'
setkv SUPPORT_URL '"https://github.com/shad0wcrawl3r/legix/issues"'
setkv BUG_REPORT_URL '"https://github.com/shad0wcrawl3r/legix/issues"'
setkv BOOTLOADER_NAME "\"${bl_old/Bazzite/Legix}\""
setkv VARIANT '"Legix (based on Bazzite Deck)"'
grep -qx 'NAME="Legix"' "$osr"
grep -qx 'ID=bazzite' "$osr"
sed -i 's/^Bazzite/Legix/' /etc/system-release
# image-info.json: only image-ref (what the terminal banner and fastfetch
# show) becomes Legix's. image-name and image-vendor MUST stay Bazzite's
# (bazzite-deck-gnome / ublue-os): bazzite-hardware-setup, -autologin,
# -user-setup, ujust and others match on image-name ("deck", "silverblue",
# "nvidia"...). With "legix" it deleted the Deck autologin, so the Go booted
# to the SDDM login screen instead of Gaming Mode, and skipped handheld setup.
info=/usr/share/ublue-os/image-info.json
jq '."image-ref" = "ostree-image-signed:docker://ghcr.io/shad0wcrawl3r/legix"' \
   "$info" > "$info.new"
mv "$info.new" "$info"
jq -e '."image-name" | test("deck")' "$info"
# Logo icon (os-release LOGO), in every size, rendered in the assets stage.
install -Dm0644 /ctx/branding/legix-mark.svg /usr/share/icons/hicolor/scalable/apps/legix-logo.svg
for png in /ctx/branding-png/icons/*.png; do
  size="$(basename "$png" .png)"
  install -Dm0644 "$png" "/usr/share/icons/hicolor/${size}x${size}/apps/legix-logo.png"
done
install -Dm0644 /ctx/branding-png/icons/256.png /usr/share/pixmaps/legix-logo.png
# Bazzite's own logo files, used by fastfetch and update notifications.
bz=/usr/share/ublue-os/bazzite
install -m0644 /ctx/branding/legix-mark.svg "$bz/logo.svg"
install -m0644 /ctx/branding/legix-logo.txt "$bz/logo.txt"
install -m0644 /ctx/branding-png/icons/256.png "$bz/updatelogo.png"
# fastfetch: Legix colours for the ASCII logo ($1 visor, $2 fins, $3/$4 gem).
jq '.logo.color = {"1": "38;2;229;67;45", "2": "38;2;184;50;31", "3": "38;2;255;106;61", "4": "38;2;255;154;85"}' \
   "$bz/fastfetch.jsonc" > "$bz/fastfetch.jsonc.new" 2>/dev/null \
  && mv "$bz/fastfetch.jsonc.new" "$bz/fastfetch.jsonc" \
  || { rm -f "$bz/fastfetch.jsonc.new"; sed -i -E '/"color": \{/,/\}/ { s/"1": "[^"]*"/"1": "38;2;229;67;45"/; s/"2": "[^"]*"/"2": "38;2;184;50;31"/; s/"3": "[^"]*"/"3": "38;2;255;106;61"/; s/"4": "[^"]*"/"4": "38;2;255;154;85"/ }' "$bz/fastfetch.jsonc"; }
grep -q '38;2;229;67;45' "$bz/fastfetch.jsonc"
# Accent colour for fastfetch's titles (Bazzite reads GNOME's accent colour,
# which Legix doesn't have): Forge Red.
printf '#!/usr/bin/env bash\n# Legix: fastfetch accent colour (Forge Red).\necho "38;2;229;67;45"\n' \
  > /usr/libexec/bazzite-bling-fastfetch
chmod 0755 /usr/libexec/bazzite-bling-fastfetch
# Terminal welcome banner.
for t in /usr/share/ublue-os/motd/template*.md; do
  sed -i '1s/Bazzite/Legix/' "$t"
  sed -i 's#(https://issues.bazzite.gg/)#(https://github.com/shad0wcrawl3r/legix/issues)#' "$t"
  sed -i -E 's#\[(Documentation|Dokumentation)\]\(https://docs.bazzite.gg/\)#[\1 (Bazzite, the base)](https://docs.bazzite.gg/)#' "$t"
  grep -q '^# .*Legix' "$t"
done

