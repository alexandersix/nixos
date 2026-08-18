# Workstation completeness plan

Last reviewed: August 18, 2026

This document tracks the remaining work needed to turn this configuration into
a complete general-purpose workstation for content creation, software
development, gaming, communication, and everyday desktop use.

The system is already application-complete. Its strongest remaining
opportunities are operational: backups, recovery, storage resilience, hardware
maintenance, and a few optional desktop integrations. Items in this document
are recommendations, not evidence that every feature should be enabled.

## Current strengths

The configuration already provides strong coverage in the following areas:

- A complete Wayland desktop built around MangoWM, Noctalia, Noctalia Greeter,
  XDG portals, application launching, notifications, clipboard management,
  screenshots, screen recording, and media controls.
- General desktop applications including Chromium, Thunderbird, LibreOffice,
  Obsidian, Nautilus, archive handling, image viewing, PDF viewing, and explicit
  MIME associations.
- Communication through Discord, Telegram, Zoom, LocalSend, and email.
- Password management through 1Password and its browser integration.
- An extensive creative suite covering video, streaming, 3D, photography,
  raster and vector graphics, animation, publishing, audio production, font
  design, transcoding, and media inspection.
- A broad development environment covering Nix, containers, virtual machines,
  Git and GitHub, Neovim, AI coding tools, databases, API testing, web
  development, Go, Python, PHP, JavaScript, and Godot.
- Gaming through Steam, GameMode, Gamescope, MangoHud, ProtonUp-Qt, and Bolt.
- PipeWire support for ALSA, PulseAudio, and JACK, with RTKit and native audio
  plugins.
- NetworkManager, the NixOS firewall, AMD graphics/OpenCL support, Logitech
  device support, Docker, libvirt, Wireshark, automatic Nix garbage collection,
  and store optimisation.

## Phase 1: protect data and make recovery possible

### Automated backups

Current state: `restic` and `rclone` are installed, but the configuration does
not declare a backup repository, schedule, retention policy, health check,
notification path, or restore test.

Home Manager's `backupFileExtension = "backup"` only preserves files that Home
Manager replaces during activation. It is not a personal-data or system
backup.

- [ ] Decide which data belongs in backups.
  - Creative projects and source footage
  - Documents and other irreplaceable personal data
  - Source repositories that have no complete remote copy
  - Dotfiles and private application configuration
  - OBS, REAPER/Ardour, Resolve, Blender, font, LUT, preset, and template state
  - Relevant secrets or an independently recoverable copy of them
- [ ] Choose at least one local or directly attached backup destination.
- [ ] Choose an off-site destination.
- [ ] Keep backup storage distinct from video scratch/cache storage.
- [ ] Declare scheduled Restic jobs, preferably with
  `services.restic.backups`.
- [ ] Define retention rules for hourly, daily, weekly, monthly, and yearly
  snapshots as appropriate.
- [ ] Ensure backup credentials are not committed to this repository.
- [ ] Add failure reporting that will actually be noticed.
- [ ] Schedule periodic `restic check` runs.
- [ ] Document and perform a test restore of several representative files.
- [ ] Perform a full recovery exercise after the initial backup design is
  stable.

Target outcome: important data follows a 3-2-1-style strategy, failed backup
jobs are visible, and restoration has been proven rather than assumed.

### Primary-disk encryption

Current state observed on August 18, 2026: the active `nvme0n1p2` partition
containing `/`, `/home`, and `/nix` is plain Btrfs. The second NVMe has a LUKS2
partition but was not mounted. The checked-in hardware configuration likewise
mounts the primary Btrfs filesystem directly and contains no LUKS declaration.

- [ ] Decide whether theft or physical access is part of the threat model.
- [ ] If it is, plan a migration or reinstall with LUKS2 on the primary disk.
- [ ] Decide whether TPM-assisted unlocking is desirable or whether a
  passphrase should always be required.
- [ ] Store recovery keys somewhere offline and test them.
- [ ] Confirm that any future swap design does not leak hibernated or sensitive
  memory outside encryption.

This should be treated as a planned migration, not an incidental configuration
edit. Backups and a tested restore process should exist before attempting it.

### Recovery documentation

- [ ] Keep known-good NixOS generations available in the boot menu.
- [ ] Consider setting a systemd-boot configuration limit so the EFI partition
  cannot grow without bound.
- [ ] Maintain bootable NixOS installation media.
- [ ] Document how to unlock disks, mount the filesystems, clone this
  repository, restore secrets, rebuild the host, and restore personal data.
- [ ] Keep recovery material somewhere accessible when the workstation itself
  is unavailable.

## Phase 2: storage resilience and hardware health

### Btrfs maintenance and snapshots

Current state: `/home` and `/nix` are Btrfs subvolumes. No Btrfs snapshot tool,
automatic scrub, or explicit SSD-trimming service is declared.

- [ ] Enable periodic Btrfs scrub.
- [ ] Enable periodic `fstrim` for SSD space reclamation.
- [ ] Decide between Snapper, btrbk, or another snapshot manager.
- [ ] Create an intentional subvolume and snapshot design for system and user
  data.
- [ ] Add pre-upgrade snapshots if they improve recovery from bad activations.
- [ ] Define snapshot retention so snapshots cannot consume the filesystem.
- [ ] Verify that snapshots do not include high-churn or reproducible data
  unnecessarily, especially `/nix`, caches, proxies, and render output.
- [ ] Test rolling back a file and, if supported by the chosen design, a system
  state.

Snapshots protect against accidental changes and some upgrade failures. They
do not protect against disk failure, theft, or filesystem-wide corruption and
must not replace backups.

### Disk-health monitoring

- [ ] Enable SMART/NVMe health monitoring, such as `services.smartd`.
- [ ] Add `nvme-cli` for NVMe diagnostics.
- [ ] Arrange visible notifications for failing health attributes, media
  errors, and scrub failures.
- [ ] Record the intended role of the second NVMe: projects, cache/scratch,
  local backup, or something else.

Target outcome: degradation is detected early and each storage device has a
clear, non-conflicting role.

## Phase 3: updates and hardware lifecycle

### NixOS update policy

Current state: the README documents a sound manual workflow using
`nix flake update`, `nix flake check`, and a dry build. No scheduled update
check or automatic system upgrade is configured.

For a creative workstation, a scheduled notification plus deliberate manual
activation may be safer than unattended activation.

- [ ] Decide between manual updates, scheduled update notifications, and
  automatic upgrades.
- [ ] If retaining manual activation, add a recurring reminder or stale-lock
  check.
- [ ] Continue evaluating and dry-building before activation.
- [ ] Check OBS, Resolve, REAPER/Ardour, GPU acceleration, audio, Flatpak apps,
  and the desktop session after significant upgrades.
- [ ] Document a quick rollback procedure.

### Firmware and device maintenance

- [ ] Enable `services.fwupd` if the motherboard and peripherals support it.
- [ ] Establish a periodic firmware-update check.
- [ ] Confirm AMD CPU microcode is active on the running system.
- [ ] Confirm GPU hardware encoding and decoding after major kernel, Mesa, or
  application upgrades.

### Flatpak lifecycle

Current state observed on August 18, 2026: Mouseless is the only user Flatpak.
It is installed imperatively and launched conditionally from Mango's autostart
script.

- [ ] Decide whether Flatpak installation should remain intentionally
  imperative or become declarative.
- [ ] Define an update policy for Flatpak applications and runtimes.
- [ ] Periodically remove unused runtimes.
- [ ] Review Flatpak permissions after installation and major updates.

## Phase 4: ordinary desktop capabilities

These should be implemented only when they match real hardware or usage.

### Printing and scanning

- [ ] If needed, enable CUPS and driverless printing.
- [ ] Enable Avahi/mDNS discovery for network printers and scanners.
- [ ] Enable SANE and install a scanning application such as Document Scanner.
- [ ] Test printing and scanning from both GTK and Qt applications.

### Bluetooth

Current state: Noctalia displays a Bluetooth widget, but this repository does
not explicitly enable the NixOS Bluetooth stack or a pairing manager.

- [ ] If the host has Bluetooth, enable `hardware.bluetooth`.
- [ ] Choose a pairing interface, such as Blueman or the Noctalia-provided
  interface if it supplies all required functionality.
- [ ] Test headset profiles, controllers, reconnect behavior, and microphone
  selection.

### Network integrations

- [ ] Add an OpenVPN NetworkManager plugin if OpenVPN profiles are needed.
- [ ] Add Tailscale or another mesh VPN only if remote access is needed.
- [ ] Enable SSH server access only for a concrete use case, with firewall and
  authentication settings scoped accordingly.
- [ ] Add Samba/NFS clients, shares, or network discovery only if used.
- [ ] Decide whether LocalSend is sufficient for nearby file transfer.

### Browser redundancy

Current state: Chromium is the only conventional browser.

- [ ] Consider installing Firefox as an alternate rendering engine and
  recovery browser.
- [ ] Decide whether browser profiles, bookmarks, and essential extension
  settings require backup or declarative management.

## Phase 5: content-creation workflow refinements

### Fonts and typography

Current state: the configured fonts are primarily Inter and terminal-focused
Nerd Font families.

- [ ] Add broad document and Unicode coverage, potentially including Noto,
  Noto CJK, Noto Color Emoji, and Liberation fonts.
- [ ] Decide which licensed creative fonts require separate installation and
  backup.
- [ ] Verify font discovery in LibreOffice, Scribus, Inkscape, GIMP, Blender,
  Resolve, and video editors.

### Color management

- [ ] Decide whether the photo/video workflow requires calibrated displays.
- [ ] If so, add `colord`, ICC profiles, and suitable calibration tooling.
- [ ] Document which applications and export paths are color managed.
- [ ] Verify Wayland/compositor behavior before relying on system-wide color
  transforms.

### OCR and document ingestion

- [ ] Consider Tesseract and OCRmyPDF for searchable scanned documents.
- [ ] If scanning is enabled, test a complete scan-to-PDF-to-OCR workflow.

### Large-media storage design

- [ ] Define locations for source footage, active projects, proxies, render
  output, recordings, application caches, and completed archives.
- [ ] Exclude reproducible caches and proxies from expensive backups where
  appropriate.
- [ ] Ensure irreplaceable source material is backed up before editing begins.
- [ ] Monitor free space and establish thresholds that leave Btrfs sufficient
  working room.

## Phase 6: optional security and accessibility

These are policy decisions rather than universal workstation requirements.

- [ ] Evaluate Secure Boot through Lanzaboote.
- [ ] Evaluate AppArmor against compatibility with creative and development
  applications.
- [ ] Consider using the 1Password SSH agent.
- [ ] Consider signed Git commits or tags.
- [ ] Decide whether hibernation is required and configure encrypted resume if
  so.
- [ ] Review screen-reader, magnification, on-screen keyboard, input-remapping,
  and other accessibility needs.
- [ ] Verify that the custom compositor and shell provide any required
  accessibility protocol support.

## Development policy

There is no need to install every language runtime and build tool globally.
The current use of direnv, nix-direnv, and devenv supports project-specific,
pinned environments. Rust, Java, .NET, Ruby, CMake, database servers, and other
toolchains should be added globally only when they are genuinely useful across
projects; otherwise they belong in project flakes or development shells.

## Recommended implementation order

1. Automate backups and prove restoration.
2. Enable Btrfs maintenance, snapshots, and disk-health monitoring.
3. Decide whether primary-disk encryption justifies a migration.
4. Establish update, firmware, and Flatpak lifecycle policies.
5. Add the printing, scanning, Bluetooth, and networking features actually
   needed.
6. Improve font coverage, color management, OCR, and large-media storage.
7. Revisit optional hardening and accessibility requirements.

## Completion criteria

This plan can be considered substantially complete when:

- backups run unattended, failures are reported, and a restore has succeeded;
- disk health, Btrfs scrub, trimming, and snapshot retention are automated;
- the encryption choice is explicit and recovery keys are safely stored;
- system, firmware, and Flatpak updates follow a documented cadence;
- all owned peripherals work without ad hoc post-rebuild setup;
- creative projects have documented storage, cache, archive, and backup paths;
- a failed update or lost primary disk has a written, tested recovery path; and
- optional features have either been implemented or deliberately marked as
  unnecessary.
