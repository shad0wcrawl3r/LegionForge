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
