#!/bin/sh

systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY MANGO_INSTANCE_SIGNATURE
systemctl --user restart xdg-desktop-portal-wlr.service

calendar-wallpaper prepare || true
noctalia &
(calendar-wallpaper apply --wait-seconds 10 || true) &
solaar --window=hide &

# Start Mouseless only when its per-user Flatpak is installed.
if flatpak info --user net.sonuscape.mouseless >/dev/null 2>&1; then
  flatpak run net.sonuscape.mouseless &
fi
