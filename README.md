# LegionForge

LegionForge is a custom [Bazzite](https://bazzite.gg) image for handheld gaming PCs. It is built
for the original **Lenovo Legion Go** (Z1 Extreme). Gaming Mode is the same as stock Bazzite.
Desktop Mode is **[niri](https://github.com/YaLTeR/niri)**, a scrolling tiling Wayland
compositor, with the **[Noctalia](https://noctalia.dev)** shell.

- **Base:** `ghcr.io/ublue-os/bazzite-deck-gnome:stable`, rebuilt every day, so you get Bazzite
  and Fedora updates through LegionForge.
- **Desktop:** niri and Noctalia, from the official Fedora repositories (no COPRs). The GNOME
  desktop is removed.
- **Signed:** every image is signed with cosign. The public key is
  [`cosign.pub`](cosign.pub).

## What's different from stock Bazzite

| | Stock Bazzite (Deck, GNOME) | LegionForge |
|---|---|---|
| Gaming Mode | Steam via OpenGamepadUI | Same |
| Switch to Desktop | GNOME | niri with the Noctalia shell |
| Desktop when idle, or when it wakes from sleep | Stays open | Goes to Gaming Mode, so Steam's lock-screen PIN applies |
| On-screen keyboard in the desktop | GNOME's | Noctalia [Keyboard](https://github.com/noctalia-dev/community-plugins) plugin, from the keyboard button on the bar |
| Bazzite Portal at login | Opens | Doesn't open (it's still in the app launcher) |
| GNOME desktop, extensions, GNOME Settings | Installed | Removed (about 200 MB) |

You bring your own niri and Noctalia dotfiles. The image only sets a few Noctalia defaults:
a full-width bar, icon-only widgets, the keyboard button, and the Gaming Mode lock. Your own
files in `~/.config/noctalia/`, and anything you change in Noctalia's Settings, override
them.

## Install

You need a device that already runs **Bazzite Deck with GNOME** (`bazzite-deck-gnome`).
Switching to LegionForge keeps your games, Steam library, Flatpaks, saves and settings,
because it only replaces the operating system, not your home folder.

> [!IMPORTANT]
> Start from the **GNOME** handheld edition of Bazzite. Switching straight from the KDE
> edition (`bazzite-deck`) fails with `fsetxattr(security.selinux): Invalid argument`,
> because the two editions have different SELinux policies. If you run the KDE edition,
> first switch to `ghcr.io/ublue-os/bazzite-deck-gnome:stable`, reboot, then follow the
> steps below.

### 1. Install Bazzite

Skip this if Bazzite is already installed. Download Bazzite from [bazzite.gg](https://bazzite.gg)
and choose your handheld and the **GNOME** desktop. Install it and finish the first-run setup.

### 2. Check which edition you run

In Desktop Mode, open a terminal (Ptyxis) and run:

```sh
bootc status
```

The `Booted image` line must say `bazzite-deck-gnome`.

### 3. Keep a way back

Pin your current system so it stays in the boot menu as a fallback:

```sh
sudo ostree admin pin 0
```

### 4. Switch to LegionForge

```sh
sudo bootc switch ghcr.io/shad0wcrawl3r/legionforge:latest
systemctl reboot
```

The first switch downloads the whole image (about 5 GB). Later updates only download what
changed.

### 5. Set up locking

LegionForge locks the desktop by sending you to Gaming Mode, so set Steam's PIN: in Gaming
Mode, open **Settings → Security** and turn on the lock-screen PIN for startup, for waking
from sleep and for switching to Desktop Mode. Without a PIN, anyone can use the device.

## Using it

- **Gaming Mode** works like stock Bazzite.
- **Switch to Desktop** (in the Steam menu) opens niri. The first time, Noctalia's setup
  wizard runs.
- **Lock (Gaming Mode)**, in Noctalia's power menu, returns to Gaming Mode, where Steam's PIN
  applies. The desktop does the same after 5 minutes idle and when the device wakes from
  sleep. Leaving the desktop closes its apps.
- **On-screen keyboard:** tap the keyboard button on the bar, then **On-screen keyboard**.
  It can't appear on a lock screen, which is why Steam's PIN is the lock.

### Commands

| Command | What it does |
|---|---|
| `ujust away` | Go to Gaming Mode now |
| `ujust toggle-away-on-wake` | Turn "go to Gaming Mode when waking in the desktop" on or off |
| `ujust restore-noctalia-setup` | Back up your Noctalia settings and run its setup wizard again |
| `ujust niri-validate` | Check your niri config for errors |

## Updates

Updates install automatically in the background, like on stock Bazzite. To update now:

```sh
sudo bootc upgrade
systemctl reboot
```

## Going back to stock Bazzite

- **Once:** choose the previous entry in the boot menu.
- **Undo the last switch or update:** `sudo bootc rollback`, then reboot.
- **Permanently:** `sudo bootc switch ghcr.io/ublue-os/bazzite-deck-gnome:stable`, then reboot.

Your home folder isn't touched in any of these.

## Known limitations

- Built and tested on the original Legion Go only. Other handhelds that run Bazzite Deck
  GNOME should work but are untested.
- The device doesn't check image signatures yet (the switch command uses an unverified
  transport). CI signs every image; enforcing the signature on the device is planned.
- niri's default config expects `alacritty` and `fuzzel`, which aren't installed. Bring
  your own niri config, or use Noctalia's launcher.

## Contributing

`main` is protected. See [CONTRIBUTING.md](CONTRIBUTING.md) for the branch, pull request
and commit conventions, and for the smoke test every build runs.

## Credits

Built on [Universal Blue](https://universal-blue.org)'s
[image-template](https://github.com/ublue-os/image-template) and
[Bazzite](https://github.com/ublue-os/bazzite). Licensed under Apache 2.0.
