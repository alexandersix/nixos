# `nixos-flake` porting audit

This audit compares this repository with the current working tree of
`~/Code/nixos-flake` on August 5, 2026. That distinction matters because the
source repository has uncommitted additions, renames, and deletions; the
working tree, rather than its last commit, was treated as the desired state.

## Automated parity results

The fully evaluated NixOS configurations were compared rather than relying
only on a text search:

- `environment.systemPackages`: 170 entries in each configuration, with no
  missing or added package names.
- Home Manager `home.packages`: 105 entries in each configuration. The only
  name-level difference is the intentional Neovim implementation change
  described below.
- System integrations: Chromium, 1Password and its GUI, MangoWM, Noctalia,
  Docker, Wireshark, Steam, GameMode, OBS Studio, all nine OBS plugins,
  StreamController, virt-manager, libvirt, 32-bit graphics, and PipeWire JACK
  all resolve enabled in both configurations.
- Home integrations: direnv/nix-direnv, Foot, Fuzzel, Git/LFS, Noctalia,
  Waybar, Zsh, and MangoWM all resolve enabled in both configurations. The
  complete resolved Mango settings and autostart script are identical.

The complete `desktop` NixOS system closure was then built successfully. This
validated packages that evaluation alone cannot, including proprietary
downloads and source builds.

## Application inventory

All explicitly selected user packages were carried over:

- Core CLI: curl, fd, jq, ripgrep, unzip, wget.
- Communication, passwords, and backups: 1Password, Discord, LocalSend,
  rclone, restic, Telegram Desktop, Zoom.
- Creative and media: Ardour, Audacity, Blender, Calf, Darktable, DaVinci
  Resolve Studio, digiKam, EasyEffects, FFmpeg Full, FontForge, GIMP with
  plugins, HandBrake, ImageMagick, Inkscape with extensions, Kdenlive, Krita,
  GMIC for Krita, LosslessCut, LSP plugins, MediaInfo, mpv, Pandoc, qpwgraph,
  REAPER, Scribus, Synfig Studio, Typst, yt-dlp, and Zam plugins.
- Development: act, Alejandra, Beekeeper Studio, Bruno, Codex, DBeaver,
  deadnix, devenv, Docker Buildx, Docker Compose, GitHub CLI, Godot and export
  templates, Herdr, lazydocker, lazygit, lazysql, mitmproxy, mkcert, nh,
  nix-output-monitor, nixd, nurl, pi-coding-agent, statix, whisper.cpp, and xh.
- Web development: Node.js, PHP, Composer, pnpm, and SQLite.
- Gaming: Bolt Launcher, Gamescope, MangoHud, ProtonUp-Qt, Steam, and GameMode.
- Streaming and diagnostics: OBS Studio, advanced-scene-switcher,
  obs-aitum-multistream, obs-move-transition, obs-pipewire-audio-capture,
  obs-source-record, obs-vaapi, obs-vertical-canvas, obs-vkcapture, waveform,
  StreamController, libva-utils, AMD nvtop, obs-cli, pavucontrol, playerctl,
  radeontop, and vulkan-tools.
- Desktop: Chromium, MangoWM, Noctalia, SDDM, Foot, Fuzzel, Waybar, the Bibata
  cursor theme, and the JetBrains Mono Nerd Font.
- System tooling: Docker, Wireshark, QEMU/KVM, libvirt, and virt-manager.

Git settings, Zsh aliases and completion features, Chromium extensions,
Noctalia theme settings, Neovim availability, the Noctalia cache, AMD ROCm
OpenCL support, PipeWire/JACK, OBS virtual camera support, user groups, Nix
garbage collection, and store optimization were also preserved.

## Intentional implementation differences

### Noctalia shell utilities

Fuzzel and Waybar were removed after the port because Noctalia now supplies
the application launcher and bar. Theme selection is also left to Noctalia's
writable UI state rather than pinned in the Home Manager configuration, so UI
theme changes survive NixOS rebuilds.

### Neovim

The source used `nix-wrapper-modules` to publish a standalone
`packages.<system>.neovim` output and install that configured wrapper through
Home Manager. This repository installs the normal Neovim package, retains the
editor environment variables and `vi`/`vim` aliases, and deliberately does not
manage editor configuration in Nix. Initial setup clones `alexandersix/nvim`
and links it to `~/.config/nvim`, making that private repository the sole
configuration source. The old local Lua file and wrapper-provided
`vim-sensible`/`vim-sleuth` plugins were removed to avoid conflicting with the
private checkout. The standalone flake package output was likewise omitted.

### Herdr v0.6.4

The pinned Herdr release declares a stale Rust vendor hash and fails its
fixed-output derivation. This also prevents the source repository from
completing a full system build with the current lockfile. The version and
source revision remain exactly pinned, while `home/default.nix` overrides
only `cargoDeps` with the hash Nix verified for that source. Remove the small
override when a future Herdr release ships a correct hash, after updating the
input and completing another full build.

## Deliberately omitted distro infrastructure

These source components were not ported because they exist to publish and
consume a reusable distribution, not to run the workstation:

- flake-parts and import-tree wiring;
- dendritic module registration and the `developerWorkstation.*` option API;
- layered core/desktop/workstation/developer profiles and feature flags;
- consumer templates, bootstrap installer contract, and reference host;
- public `nixosModules`/`homeModules` outputs and wrapper package outputs; and
- framework-specific composition checks.

The source working tree already deletes Hyprland in favor of MangoWM and
renames the Laravel profile/tool module to the broader developer and web
development configuration. Accordingly, deleted Hyprland configuration was
not resurrected, while all PHP, Composer, Node.js, pnpm, and SQLite tooling was
ported.

## Simplicity comparison

| Measure | `nixos-flake` | This repository | Reduction |
| --- | ---: | ---: | ---: |
| Regular Nix files | 30 | 6 | 80% |
| Lines across Nix files | 1,230 | 529 | 57% |
| Direct flake inputs | 8 | 5 | 38% |

The remaining files follow ownership boundaries rather than abstraction
layers: one flake, one host, one generated hardware file, one small username
value, one system module, and one Home Manager module. Adding a host requires a
new host directory and a single `nixosConfigurations` entry; it does not
require profiles or a public module API.

## Installation-only discrepancy

No real NixOS hardware configuration exists yet. The placeholder root
filesystem keeps evaluation and CI builds valid, but it is not safe to install
as-is. Replace `hosts/desktop/hardware-configuration.nix` with the output of
`nixos-generate-config --show-hardware-config` from the target machine before
installation. This is the only remaining machine-specific step.
