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

First, complete the graphical NixOS installation normally. Create the user you
want to keep, boot the installed system, and log in as that regular user.

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
)
```

`nvim` and `herdr` use separate directories beneath `~/dotfiles` because two
Git repositories cannot share the same checkout root. Setup links both into
the locations their applications expect:

```bash
CONFIG_LINKS=(
  "$HOME/dotfiles/nvim|$HOME/.config/nvim"
  "$HOME/dotfiles/herdr|$HOME/.config/herdr"
)
```

Home Manager installs the Neovim executable and provides `vi`/`vim` aliases,
but does not manage its configuration. The private `alexandersix/nvim`
checkout is the sole source for `~/.config/nvim`.

Home Manager adds `~/bin` to the session `PATH`. Setup enforces the executable
bit on every script with a `#!` interpreter line in that directory after
cloning or updating the utility scripts repository.

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
