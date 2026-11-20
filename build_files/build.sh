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
dnf5 install -y \
    niri \
    noctalia \
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

# Switch to Desktop from OpenGamepadUI/Steam goes straight to steamos-manager,
# which uses the per-user desktop_session (it overrides platform.toml and may
# still say gnome.desktop). Re-assert niri at every login.
chmod 0755 /usr/libexec/legionforge-desktop-session
systemctl --global enable legionforge-desktop-session.service

# ujust: drop GNOME-only recipes. Every recipe file is a mandatory import, so
# empty 90-bazzite-de.just (restore-gnome-de-settings, restore-gnome-folders)
# rather than deleting it. restore-virtual-keyboard is replaced by the niri
# version in 60-custom.just.
grep -q '^restore-gnome-de-settings:' /usr/share/ublue-os/just/90-bazzite-de.just
echo "# LegionForge: GNOME is not installed; GNOME recipes removed." \
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
# layered over the LegionForge defaults below.
# Opt out per user: systemctl --user mask noctalia.service
install -Dm0644 /usr/share/noctalia/assets/noctalia.service \
    /usr/lib/systemd/user/noctalia.service
mkdir -p /usr/lib/systemd/user/niri.service.wants
ln -sf ../noctalia.service /usr/lib/systemd/user/niri.service.wants/noctalia.service
# Seed LegionForge's Noctalia defaults (full-width bar, icon-only widgets)
# into ~/.config/noctalia before Noctalia starts. See noctalia.service.d/.
chmod 0755 /usr/libexec/legionforge-noctalia-defaults
