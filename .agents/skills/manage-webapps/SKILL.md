---
name: manage-webapps
description: Manage declarative Chromium web apps in this NixOS repository. Use when adding, installing, removing, uninstalling, renaming, or changing a chromeless website launcher, web app, PWA-style app, URL, or web-app icon.
---

# Manage Web Apps

Treat `home/webapps.nix` as the only source of truth. Each entry produces an
immutable Chromium `--app` launcher and an XDG desktop entry for Noctalia.

## Inspect

1. Read `home/webapps.nix` and `git status --short` before editing.
2. Preserve unrelated changes, especially changes outside the web-app module.
3. Do not write launchers directly into `~/.local/share/applications`.

## Add or update an app

1. Choose a stable, lowercase, kebab-case ID. Do not change an existing ID just
   because the display name changes.
2. Require an `https://` URL unless the user explicitly needs another safe web
   scheme. Reject executable or script schemes.
3. Add or update exactly one entry in the `webApps` attribute set with `name`,
   `url`, and a repository-relative `icon` path.
4. Add a compact SVG under `home/webapps/icons/<id>.svg`. Prefer the site's
   official icon or the corresponding Simple Icons SVG. Remove scripts,
   embedded remote resources, event handlers, and unnecessary metadata from
   downloaded SVGs.
5. Keep brand colors when they remain legible on both light and dark launcher
   backgrounds. Add a simple contrasting background when a monochrome mark
   would otherwise disappear.

## Remove an app

1. Remove the entry from `webApps`.
2. Remove its icon only when no remaining entry references it.
3. Do not remove Chromium, Noctalia, Mango, or unrelated desktop entries.

## Validate

1. Run `alejandra --check home/webapps.nix home/default.nix`.
2. Run `nix flake check path:.` so newly created, untracked icons are included.
3. Inspect the diff and confirm no unrelated file was staged, reverted, or
   overwritten.
4. Do not activate the system unless the user asks. When activation is in
   scope, use `sudo nixos-rebuild switch --flake path:.#desktop`.

Report the app ID, URL, icon source, checks run, and whether activation occurred.
