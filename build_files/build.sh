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
    nautilus
)
dnf5 mark -y user "${KEEP[@]}"
dnf5 remove -y \
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

#### Noctalia: start automatically in niri sessions
# Use the systemd user unit Noctalia ships as a template, so it tracks
# upstream. It is pulled in by niri.service only, never by GNOME or Gaming
# Mode. No settings are shipped: on first start Noctalia runs its setup
# wizard and saves choices to ~/.config/noctalia/settings.toml.
# Opt out per user: systemctl --user mask noctalia.service
install -Dm0644 /usr/share/noctalia/assets/noctalia.service \
    /usr/lib/systemd/user/noctalia.service
mkdir -p /usr/lib/systemd/user/niri.service.wants
ln -sf ../noctalia.service /usr/lib/systemd/user/niri.service.wants/noctalia.service
