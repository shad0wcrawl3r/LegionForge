#!/usr/bin/env bash
# Smoke-test the built LegionForge image before it is pushed.
#
# Usage: smoke-test.sh <built-image> <device-base-image>
#   <built-image>        local image to test, e.g. localhost/legionforge:latest
#   <device-base-image>  the image the Legion Go switches/upgrades FROM. Every
#                        SELinux type the built image labels files with must
#                        already exist in this image's compiled policy, or
#                        `bootc switch` fails on the device with
#                        "fsetxattr(security.selinux): Invalid argument".
set -euo pipefail

IMAGE="$1"
DEVICE_BASE="$2"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

in_image() { podman run --rm --pull=never --network=none --entrypoint /bin/bash "$IMAGE" -c "$1"; }

check() {
  if in_image "$2" >/dev/null 2>&1; then
    echo "ok   - $1"
  else
    echo "::error title=Smoke test::$1"
    fail=1
  fi
}

echo "== Packages and session wiring"
check "packages installed (niri noctalia xwayland-satellite portals)" \
  "rpm -q niri noctalia xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk"
check "niri wayland session exists" \
  "test -f /usr/share/wayland-sessions/niri.desktop"
check "os-session-select override is executable and parses" \
  "test -x /usr/lib/os-session-select && bash -n /usr/lib/os-session-select"
check "os-session-select defaults to niri" \
  "grep -q '^desktop_session=\"niri.desktop\"' /usr/lib/os-session-select"
check "steamos-manager default desktop is niri" \
  "grep -qx 'desktop = \"niri.desktop\"' /usr/share/steamos-manager/platform.toml"
check "noctalia user unit installed" \
  "test -f /usr/lib/systemd/user/noctalia.service"
check "noctalia is pulled in by niri.service" \
  "test \"\$(readlink -f /usr/lib/systemd/user/niri.service.wants/noctalia.service)\" = /usr/lib/systemd/user/noctalia.service"
check "no Noctalia settings shipped (first-run wizard must appear)" \
  "! find /etc/skel /usr/share/noctalia -name settings.toml 2>/dev/null | grep -q ."

check "steamos-manager desktop pinned to niri at login (OpenGamepadUI path)" \
  "test -x /usr/libexec/legionforge-desktop-session && bash -n /usr/libexec/legionforge-desktop-session && test -L /etc/systemd/user/default.target.wants/legionforge-desktop-session.service"

check "Noctalia defaults ship, are valid, and are seeded before Noctalia starts" \
  "noctalia config validate /usr/share/legionforge/noctalia/00-legionforge-defaults.toml 2>&1 | grep -q 'Config is valid' && ! noctalia config validate /usr/share/legionforge/noctalia/00-legionforge-defaults.toml 2>&1 | grep -q 'unknown setting' && test -x /usr/libexec/legionforge-noctalia-defaults && grep -q legionforge-noctalia-defaults /usr/lib/systemd/user/noctalia.service.d/10-legionforge-defaults.conf"
check "Noctalia wizard state not shipped (wizard must appear on first start)" \
  "! find /etc/skel /usr/share -path '*noctalia*' \\( -name .setup-complete -o -name settings.toml \\) 2>/dev/null | grep -q ."
check "Bazzite Portal does not autostart for new users" \
  "test ! -e /etc/skel/.config/autostart/bazzite-portal.desktop"

echo "== GNOME removed, niri essentials kept"
check "GNOME desktop removed (gdm gnome-shell gnome-session gnome-control-center)" \
  "for p in gdm gnome-shell gnome-session gnome-control-center; do ! rpm -q \$p; done && test ! -e /usr/share/wayland-sessions/gnome.desktop"
check "kept: sddm, oo7 password store + PAM unlock, portals, nautilus, VPN dialogs, pinentry, GTK3 theme" \
  "rpm -q sddm oo7-daemon oo7-portal pam_oo7 xdg-desktop-portal-gnome xdg-desktop-portal-gtk nautilus gnome-disk-utility NetworkManager-openvpn-gnome NetworkManager-openconnect-gnome pinentry-gnome3 adw-gtk3-theme"
check "unused GNOME pieces removed (mutter, gnome-settings-daemon, evolution-data-server, docs)" \
  "for p in mutter gnome-settings-daemon evolution-data-server gnome-user-docs gnome-backgrounds gjs; do ! rpm -q \$p; done"
check "ujust parses and has the LegionForge recipes" \
  "JUST_JUSTFILE=/usr/share/ublue-os/justfile just --list | grep -q restore-noctalia-setup"
check "no GNOME-only ujust recipes left" \
  "! JUST_JUSTFILE=/usr/share/ublue-os/justfile just --list | grep -qE 'restore-gnome-(de-settings|folders)' && ! JUST_JUSTFILE=/usr/share/ublue-os/justfile just --show restore-virtual-keyboard | grep -q gnome-extensions"

echo "== SELinux types vs device policy (${DEVICE_BASE})"
in_image "cat /etc/selinux/targeted/contexts/files/file_contexts" > "$WORK/file_contexts"
if ! podman image exists "$DEVICE_BASE"; then
  podman pull -q "$DEVICE_BASE" >/dev/null
fi
podman run --rm --pull=never --network=none --entrypoint /bin/bash "$DEVICE_BASE" \
  -c 'cat "$(ls /etc/selinux/targeted/policy/policy.* | sort -V | tail -1)"' > "$WORK/device_policy"

python3 - "$WORK/file_contexts" "$WORK/device_policy" <<'PY' || fail=1
import re, struct, sys
fc, pol = open(sys.argv[1]).read(), open(sys.argv[2], "rb").read()
types = sorted(set(re.findall(r":object_r:([A-Za-z0-9_]+):", fc)))

def defined(name):
    # In a compiled policydb each type symbol is stored as
    # <u32 name length><u32 value><u32 properties><u32 bounds><name>,
    # so check the length field 16 bytes before each occurrence
    # (12 for older policy versions without bounds).
    n = name.encode()
    ln = struct.pack("<I", len(n))
    i = pol.find(n)
    while i != -1:
        if pol[i - 16:i - 12] == ln or pol[i - 12:i - 8] == ln:
            return True
        i = pol.find(n, i + 1)
    return False

# Self-test, so a policy format change can't make this check silently
# pass (or fail) everything.
if not defined("bin_t") or defined("legionforge_selftest_nonexistent_t"):
    print("::error title=SELinux check self-test failed::cannot parse the device policy; update smoke-test.sh")
    sys.exit(1)
if len(types) < 100:
    print(f"::error title=SELinux check self-test failed::only {len(types)} types parsed from file_contexts")
    sys.exit(1)

missing = [t for t in types if not defined(t)]
print(f"checked {len(types)} file context types, {len(missing)} unknown to the device policy")
for t in missing:
    print(f"::error title=SELinux type unknown to device policy::{t} (bootc switch would fail with fsetxattr EINVAL)")
sys.exit(1 if missing else 0)
PY

if (( fail )); then
  echo "Smoke test FAILED"
  exit 1
fi
echo "Smoke test passed"
