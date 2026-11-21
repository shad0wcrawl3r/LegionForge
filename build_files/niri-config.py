#!/usr/bin/env python3
"""Generate Legix's default niri config from niri's own default config.

niri reads /etc/niri/config.kdl when the user has no ~/.config/niri/config.kdl
(and then doesn't create one), so users who bring their own dotfiles are
unaffected. Starting from the packaged default keeps it in step with niri;
every edit asserts its anchor, so the build fails loudly if niri's default
changes shape instead of silently shipping a half-edited config.

  niri-config.py <niri default-config.kdl> <output>
"""
import re
import sys

src, out = sys.argv[1], sys.argv[2]
s = open(src).read()
N = '"noctalia" "msg"'

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f"niri-config.py: anchor not found in {src}:\n  {old}")
    s = s.replace(old, new, 1)

# Noctalia is the shell (started by niri.service.wants), not waybar.
sub('spawn-at-startup "waybar"\n',
    '// Legix: the Noctalia shell starts with niri (systemd user unit), so no bar here.\n')

# Terminal: Ptyxis. Launcher: Noctalia's, on Mod+Space and Mod+D.
sub('    Mod+T hotkey-overlay-title="Open a Terminal: alacritty" { spawn "alacritty"; }\n',
    '    Mod+T hotkey-overlay-title="Open a Terminal: Ptyxis" { spawn "ptyxis" "--new-window"; }\n'
    '    Mod+Return hotkey-overlay-title=null { spawn "ptyxis" "--new-window"; }\n')
sub('    Mod+D hotkey-overlay-title="Run an Application: fuzzel" { spawn "fuzzel"; }\n',
    f'    Mod+Space hotkey-overlay-title="Apps: Noctalia launcher" {{ spawn {N} "panel-toggle" "launcher"; }}\n'
    f'    Mod+D hotkey-overlay-title=null {{ spawn {N} "panel-toggle" "launcher"; }}\n')
sub('    Super+Alt+L hotkey-overlay-title="Lock the Screen: swaylock" { spawn "swaylock"; }\n',
    f'    Super+Alt+L hotkey-overlay-title="Lock the Screen" {{ spawn {N} "session" "lock"; }}\n')

# Volume, media and brightness through Noctalia, so its on-screen display
# shows (brightnessctl and playerctl aren't installed).
sub('XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }',
    f'XF86AudioRaiseVolume allow-when-locked=true {{ spawn {N} "volume-up"; }}')
sub('XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }',
    f'XF86AudioLowerVolume allow-when-locked=true {{ spawn {N} "volume-down"; }}')
sub('XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }',
    f'XF86AudioMute        allow-when-locked=true {{ spawn {N} "volume-mute"; }}')
sub('XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }',
    f'XF86AudioMicMute     allow-when-locked=true {{ spawn {N} "mic-mute"; }}')
for key, old_cmd, action in (("Play", "play-pause", "toggle"), ("Stop", "stop", "stop"),
                             ("Prev", "previous", "previous"), ("Next", "next", "next")):
    pat = re.compile(rf'(XF86Audio{key}\s+allow-when-locked=true) \{{ spawn-sh "playerctl {old_cmd}"; \}}')
    if not pat.search(s):
        sys.exit(f"niri-config.py: anchor not found in {src}: XF86Audio{key} playerctl {old_cmd}")
    s = pat.sub(lambda m: f'{m.group(1)} {{ spawn {N} "media" "{action}"; }}', s, count=1)
sub('XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }',
    f'XF86MonBrightnessUp allow-when-locked=true {{ spawn {N} "brightness-up"; }}')
sub('XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }',
    f'XF86MonBrightnessDown allow-when-locked=true {{ spawn {N} "brightness-down"; }}')

header = ("// Legix default niri config: niri's own default with Legix's apps wired in\n"
          "// (Noctalia launcher on Mod+Space / Mod+D, Ptyxis on Mod+T / Mod+Return,\n"
          "// Noctalia lock, volume, brightness and media keys). Generated at image\n"
          "// build time. To customise, copy it to ~/.config/niri/config.kdl; your copy\n"
          "// then replaces this file entirely.\n\n")
open(out, "w").write(header + s)
print(f"wrote {out}")
