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

Current state: `restic` and `rclone` are installed. An intentionally inert
Restic job now targets a future removable external SSD at
`/mnt/workstation-backup`, covers the user's home directory with conservative
reproducible-data exclusions, and applies initial retention rules. The job is
manual-only until the drive has been purchased. It is also conditioned on both
that path being a real mount point and a separately provisioned password file,
so it cannot silently place backups on the primary filesystem. The drive, mount
declaration, password, schedule, health check, notification path, and restore
test do not exist yet.

Home Manager's `backupFileExtension = "backup"` only preserves files that Home
Manager replaces during activation. It is not a personal-data or system
backup.

- [x] Define preliminary backup include/exclude lists.
  - Creative projects and source footage
  - Documents and other irreplaceable personal data
  - Source repositories that have no complete remote copy
  - Mutable application state and configuration that is not recreated by this
    repository, including browser/email profiles and creative-application
    presets, templates, libraries, and databases
  - Authentication and recovery material needed to reach private remote data,
    unless it has an independently tested recovery path
  - OBS, REAPER/Ardour, Resolve, Blender, font, LUT, preset, and template state
  - Selected system state outside the user's home directory only when it is
    both valuable and not declarative, such as important VM images or Docker
    volumes
  - Exclude `/nix`, system packages, reproducible caches/build output, trash,
    Steam game files, media proxies, and render scratch data by default
- [ ] Review the preliminary exclusions after the first size estimate so that
  no non-reproducible game saves, project assets, or application data are
  discarded with a large cache directory.
- [x] Choose a local or directly attached backup destination: a removable
  external SSD to be purchased.
- [ ] Choose an off-site destination.
- [ ] Keep backup storage distinct from video scratch/cache storage.
- [x] Declare a manual-only Restic job with `services.restic.backups` so its
  scope, repository, exclusions, and initial retention policy are prepared.
- [ ] Add a schedule only after the external SSD has been purchased, mounted,
  initialized, and tested.
- [x] Make an absent external SSD a normal skipped run rather than a failed job,
  and ensure the backup service cannot silently create its repository on the
  primary filesystem when the expected mount is absent.
- [ ] Decide whether plugging in and mounting the SSD should trigger a backup in
  addition to a persistent daily schedule.
- [ ] Give the backup filesystem a stable label or UUID and document its mount
  and unlock procedure. Restic repository encryption is required; whole-device
  LUKS encryption is optional depending on the desired plug-in workflow.
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

Current state observed on August 18, 2026: `/home` and `/nix` are Btrfs
subvolumes on the primary NVMe, while `/` mounts the filesystem top level
rather than a dedicated root subvolume. No snapshot tool is declared. Monthly
automatic scrub and explicit weekly `fstrim` are now declared; the mounted
filesystem also reports asynchronous discard support. Activation and initial
run results have not yet been verified.

#### Establish a maintenance baseline

- [ ] Record a baseline from `btrfs filesystem usage`, `btrfs device stats`,
  `btrfs scrub status`, and `btrfs subvolume list` before changing the layout.
- [x] Enable `services.btrfs.autoScrub` with a monthly schedule.
- [ ] After activation, ensure the primary filesystem is scrubbed once, not once
  per mounted subvolume, and inspect the initial result.
- [x] Make the trim policy explicit with weekly `services.fstrim` rather than
  relying on a changing module default.
- [ ] After activation, confirm `fstrim.timer` runs and that discard reaches each
  SSD-backed filesystem.
- [ ] Define a free-space warning threshold. Btrfs needs working space for
  metadata and copy-on-write operations, so total free bytes alone are not a
  sufficient health signal; monitor allocated data and metadata usage as well.
- [ ] Treat a routine full-filesystem balance as unnecessary. If allocation
  becomes unbalanced, use a filtered balance only after checking filesystem
  usage and backups.

Scrub verifies checksums and asks redundant storage to repair a damaged copy.
On this single-device filesystem it can detect corruption, but it usually
cannot reconstruct corrupted data by itself. Any non-zero uncorrectable-error
result must therefore be a visible backup-and-recovery event.

#### Design snapshots around the data, not the mount points

- [ ] Inventory which paths are irreplaceable, convenient to roll back, or
  reproducible. At minimum, classify user documents/projects, application
  state, `/nix`, downloads, caches, virtual-machine images, containers,
  recordings, proxies, render output, and temporary data.
- [ ] Decide whether snapshots are intended primarily for recovering individual
  user files, reverting pre-upgrade system state, or both. This determines
  whether Snapper, btrbk, or a smaller custom arrangement is the best fit.
- [ ] Decide whether to migrate `/` into a dedicated root subvolume. The current
  top-level root layout is not a clean foundation for atomic root snapshots and
  rollback, and Btrfs snapshots do not recursively include nested subvolumes.
- [ ] Keep `/nix` out of routine user-data snapshots unless a tested system
  rollback design specifically needs it. NixOS generations already cover much
  of the system configuration, while snapshotting the store can retain a large
  amount of reproducible data.
- [ ] Create separate subvolumes or exclusions for high-churn data when the
  chosen tool requires them. Pay particular attention to browser and build
  caches, Docker/libvirt storage, VM images, media proxies, recordings, and
  render scratch space; copy-on-write snapshots of active database or VM files
  also do not guarantee application-consistent recovery.
- [ ] Choose hourly/daily/weekly retention and a hard space guard appropriate
  to the available capacity. Include automatic cleanup and a documented manual
  emergency-pruning procedure.
- [ ] Add pre-activation snapshots only if they integrate cleanly with the
  chosen root layout and bootloader recovery path. A snapshot that cannot be
  selected or restored from recovery media is not yet a rollback mechanism.

#### Prove recovery and ongoing operation

- [ ] Restore an accidentally changed file from a read-only snapshot without
  replacing the current subvolume.
- [ ] If system rollback is in scope, test it from bootable recovery media and
  verify the relationship between the filesystem snapshot, the selected NixOS
  generation, `/boot`, and any database/application state.
- [ ] Confirm snapshot creation and pruning still work when the workstation was
  asleep at the scheduled time and after a reboot.
- [ ] Confirm scrub failures and snapshot/timer failures use the same durable,
  noticeable alerting path as backup failures.

Snapshots protect against accidental changes and some upgrade failures. They
do not protect against disk failure, theft, or filesystem-wide corruption and
must not replace backups.

### Disk-health monitoring

Current state observed on August 18, 2026: the host contains two 2 TB WD_BLACK
SN7100 NVMe devices. The primary device holds the unencrypted Btrfs system and
unencrypted swap. The second device contains another Linux installation used
for physical-hardware distro trials and is intentionally unavailable to this
NixOS installation. SMART/NVMe monitoring and `nvme-cli` are now declared, but
activation, device discovery, and notifications have not yet been verified.

#### Assign storage roles before mounting the second device

- [x] Record the current role of the second NVMe: it hosts a separate Linux
  installation for on-hardware distro testing and must not be repartitioned,
  reformatted, mounted for routine storage, or enrolled in Btrfs redundancy.
- [ ] Revisit that role only if the distro-testing workflow is retired.

If that role changes later, do not treat the second internal NVMe as off-site
backup storage: it shares the workstation's theft, power, user-error, and
physical-damage risks. Any future move to mirrored storage should likewise be a
planned migration with degraded-boot and device-replacement procedures, not an
in-place experiment on the current filesystems.

#### Monitor both the device and filesystem layers

- [x] Enable `services.smartd` with graphical-session notifications.
- [ ] After activation, verify that smartd discovers both NVMe devices,
  including the device hosting the separate Linux installation. Explicit stable
  device paths are preferable if autodetection proves unreliable.
- [x] Add `nvme-cli` for manual inspection.
- [ ] Capture an initial health record for each drive: critical warnings,
  available spare, percentage used, temperature, unsafe shutdowns,
  media/data-integrity errors, and error-log entries.
- [ ] Decide whether each model supports useful device self-tests before
  scheduling them. Stagger any supported extended tests and scrubs so they do
  not all compete with interactive or render workloads.
- [ ] Alert on SMART/NVMe critical warnings, rising media errors, depleted
  spare, excessive temperature, scrub errors, Btrfs device-stat errors, timer
  failures, and capacity thresholds. Track changes over time rather than only
  checking whether the overall health status says `PASSED`.
- [ ] Use an alert path that is both immediate and durable. A desktop
  notification is useful while logged in, but should be paired with persistent
  journal visibility, email, or the same external notification mechanism used
  for backup failures.
- [ ] Exercise the notification path with a harmless test event, then document
  the commands for inspecting each drive and the first response to an alert:
  stop write-heavy work, preserve logs, verify backups, and assess replacement.
- [ ] Review health and lifetime counters periodically even when no alert has
  fired, and retain enough history to identify a worsening trend.

Target outcome: degradation is detected early and each storage device has a
clear, non-conflicting role. Scrubs, SMART monitoring, alerts, snapshots, and
backups have each been tested for the distinct failure mode they are intended
to cover.

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

Current state: CUPS, `cups-browsed`, Avahi/mDNS discovery, and
`system-config-printer` are enabled for driverless Wi-Fi printing to a Brother
HL-L2460DW. The configuration builds successfully without a vendor driver.
Scanning and USB printing remain disabled because this printer does not need
them.

- [x] Enable CUPS and driverless printing.
- [x] Enable Avahi/mDNS discovery for network printers.
- [ ] Enable SANE and install a scanning application such as Document Scanner.
- [ ] Test printing from both GTK and Qt applications.
- [ ] If scanning is added later, test it from the chosen scanning application.

### Bluetooth

Current state: the host exposes an unblocked Bluetooth controller using the
kernel `btusb` driver. BlueZ is explicitly enabled and powers the controller on
at boot. Noctalia provides the Bluetooth widget, device management, and pairing
agent; PipeWire and WirePlumber provide Bluetooth audio integration. Blueman is
not enabled because it would duplicate Noctalia's pairing interface, but
`bluetoothctl` remains available as a diagnostic fallback.

- [x] Enable `hardware.bluetooth` explicitly rather than relying on Noctalia's
  recommended-services default.
- [x] Use Noctalia as the primary pairing and device-management interface.
- [ ] Pair an audio device and test high-quality stereo playback, the headset
  microphone profile, application input/output selection, and switching back
  to the stereo profile.
- [ ] Test trusted-device reconnection after a reboot, suspend/resume, and
  cycling Bluetooth power.
- [ ] Pair any controllers or input devices that will actually be used and test
  buttons, analog inputs, vibration, battery reporting, and reconnect behavior.
- [ ] Add Blueman or device-specific BlueZ/WirePlumber settings only if testing
  exposes functionality that Noctalia and the defaults do not provide.

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
