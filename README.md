# NixOS configuration

This is a personal NixOS configuration for the `desktop` host. It keeps the
software and behavior from `nixos-flake` while removing the reusable distro
API, flake-parts, import-tree, wrapper framework, profiles, and feature flags.

## Layout

```text
flake.nix                              pinned inputs and host list
hosts/desktop/default.nix              host name, user, and Home Manager wiring
hosts/desktop/hardware-configuration.nix  machine-specific generated settings
hosts/desktop/username.nix             username selected during initial setup
modules/system.nix                     system services and applications
home/default.nix                       user applications and dotfile settings
scripts/setup.sh                       initial machine and private-repo setup
```

To add another machine, create `hosts/<name>/` and add one small
`nixosConfigurations.<name>` entry to `flake.nix`. Shared settings can continue
to import `modules/system.nix`; host-specific differences stay in that host's
directory.

## Installing on a new machine

First, boot the installer in UEFI mode and complete the graphical NixOS
installation normally. Create the user you want to keep, boot the installed
system, and log in as that regular user. This configuration uses systemd-boot
and expects an EFI System Partition mounted by the installer.

Git and the GitHub CLI are part of the final configuration, but they are not
installed yet. Open an ephemeral shell containing both without changing the
temporary system configuration:

```console
nix --extra-experimental-features 'nix-command flakes' \
  shell nixpkgs#git nixpkgs#gh
```

If this repository is private, authenticate before trying to clone it:

```console
gh auth login
gh repo clone OWNER/REPOSITORY ~/Code/nixos
```

For a public repository, a normal clone is enough:

```console
git clone REPOSITORY_URL ~/Code/nixos
```

Enter the checkout and run its setup app:

```console
cd ~/Code/nixos
nix --extra-experimental-features 'nix-command flakes' run .#setup
```

Setup performs the machine-specific work that should not be hard-coded in the
shared flake:

1. It copies `/etc/nixos/hardware-configuration.nix` into the `desktop` host.
2. It configures NixOS and Home Manager for the currently logged-in user.
3. It verifies GitHub CLI authentication and configures Git to use it.
4. It clones or updates the private repositories listed in `scripts/setup.sh`.
5. It creates any optional configuration symlinks listed in the same file,
   without replacing paths that already exist.
6. It makes every script with a `#!` interpreter line in `~/bin` executable.

Run setup as the regular graphical-installer user, not with `sudo`. It is safe
to rerun. Use `--help` to see overrides for the hardware path and username.

The configured private repositories are:

```bash
PRIVATE_REPOSITORIES=(
  "alexandersix/utility-scripts|$HOME/bin"
  "alexandersix/nvim|$HOME/dotfiles/nvim"
  "alexandersix/herdr|$HOME/dotfiles/herdr"
  "alexandersix/mango|$HOME/dotfiles/mango"
)
```

`nvim`, `herdr`, and `mango` use separate directories beneath `~/dotfiles`
because Git repositories cannot share the same checkout root. Setup links
them into the locations their applications expect:

```bash
CONFIG_LINKS=(
  "$HOME/dotfiles/nvim|$HOME/.config/nvim"
  "$HOME/dotfiles/herdr|$HOME/.config/herdr"
  "$HOME/dotfiles/mango|$HOME/.config/mango"
)
```

Home Manager installs the Neovim executable and provides `vi`/`vim` aliases,
but does not manage its configuration. The private `alexandersix/nvim`
checkout is the sole source for `~/.config/nvim`.

The `alexandersix/mango` checkout is likewise the sole source for
`~/.config/mango`; Home Manager installs no files in that directory.

## Saving Noctalia UI changes

Noctalia writes Settings UI changes to its state directory. To promote the
current merged user configuration into this repository, run:

```console
sync-noctalia-config
```

The command validates and atomically updates `home/noctalia/config.toml`.
Home Manager uses that snapshot as the portable Noctalia configuration, then
applies the shared terminal font and locally managed plugin settings as Nix
overrides. Pass `--repo PATH` or set `NIXOS_CONFIG_DIR` if the repository is not
in one of the standard locations checked by the script.

Home Manager adds `~/bin` to the session `PATH`. Setup enforces the executable
bit on every script with a `#!` interpreter line in that directory after
cloning or updating the utility scripts repository.

## Declarative web apps

Chromeless Chromium web apps are declared in `home/webapps.nix`. Each entry
generates an immutable `chromium --app=<URL>` launcher and a desktop entry that
Noctalia discovers automatically. Icons live in `home/webapps/icons/`.

Add or remove an entry and rebuild to update the launcher:

```console
sudo nixos-rebuild switch --flake path:.#desktop
```

Using `path:.` includes newly created icons before they have been added to Git.
After the files are tracked, the usual `--flake .#desktop` form also works.

### Future URL-scheme handlers

The web-app module could later support links such as `mailto:` or `zoommtg:`
without changing how ordinary launchers work. Keep the visible launcher for the
app, and generate a second, hidden desktop entry for each handler. The hidden
entry would declare the appropriate `x-scheme-handler/<scheme>` MIME type,
accept the incoming URI through `%u`, and be registered declaratively through
`xdg.mimeApps`. A handler should be allowed to become either an available
choice or the default application for its scheme.

Handlers must be app-specific rather than passing an arbitrary URI directly to
Chromium. For example, a Gmail handler would safely translate a `mailto:` URI
into Gmail's HTTPS compose URL before opening it in Chromium app mode. Passing
an external scheme back to Chromium can cause it to invoke the same system
handler recursively. Each handler should therefore:

- accept and parse exactly one URI;
- verify its expected scheme;
- translate it with a real URL parser and correct percent encoding;
- restrict the result to an allowlisted HTTPS origin; and
- avoid `eval` or interpolating URI contents into shell commands.

When implementing this, add optional handler declarations to each `webApps`
entry, generate hidden `NoDisplay=true` desktop entries separately from the
visible launchers, and assert that at most one app is the default for each
scheme. Do not claim the general `http:` or `https:` schemes. Implement the
framework alongside its first real consumer, such as Gmail/HEY for `mailto:`
or Zoom for `zoommtg:`, so its URI transformation can be tested concretely.

Codex and Pi share the repository-local `manage-webapps` skill from
`.agents/skills/`. Ask Codex to `Use $manage-webapps to add ...`, or run
`/skill:manage-webapps add ...` in Pi. The skill edits the declaration and icon,
validates the flake, and leaves activation to an explicit request.

Skills do not select their own model. Model and reasoning settings belong to
the harness session or project configuration, so invoking this skill preserves
the active model rather than silently changing every task in the repository.

Review the hardware and username changes made by setup. Because they describe
this host, commit them to the private configuration repository when satisfied.

Review and build without activating:

```console
nix --extra-experimental-features 'nix-command flakes' flake check
sudo nixos-rebuild dry-build --flake .#desktop \
  --option experimental-features 'nix-command flakes'
```

Install or activate when ready:

```console
sudo nixos-rebuild switch --flake .#desktop \
  --option experimental-features 'nix-command flakes'
```

Log out and back in after the first rebuild. Git, `gh`, the desktop session,
user groups, and the Home Manager environment will then all be available from
the declarative configuration. Future rebuilds can use the shorter commands
below because the flake enables the required Nix features system-wide.

Do not change either `stateVersion` just because nixpkgs or Home Manager is
updated. Those values describe the first installation's compatibility defaults.

## Updating

Update all pinned inputs and verify the result:

```console
nix flake update
nix flake check
sudo nixos-rebuild dry-build --flake .#desktop
```

Package choices are grouped by purpose in `home/default.nix`. System
services and applications that require NixOS integration are in
`modules/system.nix`.

See [`docs/porting-audit.md`](docs/porting-audit.md) for the package-by-package
parity check, simplification measurements, and the two intentional
implementation differences from `nixos-flake`.
