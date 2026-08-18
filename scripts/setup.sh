# This script is exposed as `nix run .#setup`. Keep the arrays below as the
# simple, declarative lists of repositories, links, and executable directories
# that should be prepared on a new machine.

PRIVATE_REPOSITORIES=(
  "alexandersix/nvim|$HOME/dotfiles/nvim"
)

CONFIG_LINKS=(
  "$HOME/dotfiles/nvim|$HOME/.config/nvim"
)

EXECUTABLE_DIRECTORIES=(
  "$HOME/bin"
)

show_help() {
  cat <<'EOF'
Prepare a freshly installed NixOS machine for this flake.

Usage: nix run .#setup -- [options]

Options:
  --hardware PATH  Hardware configuration to copy
                   (default: /etc/nixos/hardware-configuration.nix)
  --username NAME  NixOS/Home Manager user (default: the current user)
  --skip-github    Do not authenticate or clone private repositories
  -h, --help       Show this help

Run this as the regular user created by the graphical NixOS installer, not as
root. The script is safe to rerun: matching hardware and username files are
left alone, existing repositories are fast-forwarded, and existing config
paths are never overwritten.
EOF
}

hardware_source=/etc/nixos/hardware-configuration.nix
username="$(id -un)"
skip_github=false

while (($# > 0)); do
  case "$1" in
    --hardware)
      [[ $# -ge 2 ]] || {
        echo "error: --hardware requires a path" >&2
        exit 2
      }
      hardware_source=$2
      shift 2
      ;;
    --username)
      [[ $# -ge 2 ]] || {
        echo "error: --username requires a name" >&2
        exit 2
      }
      username=$2
      shift 2
      ;;
    --skip-github)
      skip_github=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      show_help >&2
      exit 2
      ;;
  esac
done

if [[ $(id -u) -eq 0 ]]; then
  echo "error: run setup as the regular user created by the installer, not as root" >&2
  exit 1
fi

if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "error: '$username' is not a supported Linux username" >&2
  exit 1
fi

if ! id "$username" >/dev/null 2>&1; then
  echo "error: user '$username' does not exist on this installed system" >&2
  exit 1
fi

repo_root=$PWD
if [[ ! -f $repo_root/flake.nix || ! -d $repo_root/hosts/desktop ]]; then
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi

if [[ -z $repo_root || ! -f $repo_root/flake.nix || ! -d $repo_root/hosts/desktop ]]; then
  echo "error: run this command from the root of the NixOS configuration repository" >&2
  exit 1
fi

hardware_destination=$repo_root/hosts/desktop/hardware-configuration.nix
username_destination=$repo_root/hosts/desktop/username.nix

if [[ ! -f $hardware_source ]]; then
  echo "error: hardware configuration not found at $hardware_source" >&2
  echo "       pass its location with --hardware PATH" >&2
  exit 1
fi

if cmp -s "$hardware_source" "$hardware_destination"; then
  echo "Hardware configuration is already current."
else
  install -m 0644 "$hardware_source" "$hardware_destination"
  echo "Copied hardware configuration from $hardware_source."
fi

desired_username=$(printf '"%s"\n' "$username")
current_username=$(<"$username_destination")
if [[ $current_username == "$desired_username" ]]; then
  echo "Configured username is already '$username'."
else
  printf '%s' "$desired_username" >"$username_destination"
  echo "Configured NixOS and Home Manager for user '$username'."
fi

if [[ $skip_github == false ]]; then
  if ! gh auth status >/dev/null 2>&1; then
    echo
    echo "GitHub authentication is required for private configuration repositories."
    gh auth login
  fi

  gh auth setup-git

  for entry in "${PRIVATE_REPOSITORIES[@]}"; do
    IFS='|' read -r repository destination <<<"$entry"
    if [[ -z $repository || -z $destination ]]; then
      echo "error: invalid PRIVATE_REPOSITORIES entry: $entry" >&2
      exit 1
    fi

    if [[ -d $destination/.git ]]; then
      echo "Updating $repository in $destination..."
      git -C "$destination" pull --ff-only
    elif [[ -e $destination ]]; then
      echo "Skipping $repository: $destination already exists and is not a Git repository." >&2
    else
      mkdir -p "$(dirname "$destination")"
      gh repo clone "$repository" "$destination"
    fi
  done

  for entry in "${CONFIG_LINKS[@]}"; do
    IFS='|' read -r source destination <<<"$entry"
    if [[ -z $source || -z $destination ]]; then
      echo "error: invalid CONFIG_LINKS entry: $entry" >&2
      exit 1
    fi

    if [[ -L $destination && $(readlink "$destination") == "$source" ]]; then
      echo "Configuration link already exists: $destination"
    elif [[ -e $destination || -L $destination ]]; then
      echo "Skipping link: $destination already exists." >&2
    elif [[ ! -e $source ]]; then
      echo "Skipping link: source $source does not exist." >&2
    else
      mkdir -p "$(dirname "$destination")"
      ln -s "$source" "$destination"
      echo "Linked $destination -> $source"
    fi
  done
fi

for directory in "${EXECUTABLE_DIRECTORIES[@]}"; do
  if [[ -d $directory ]]; then
    executable_count=0
    while IFS= read -r -d '' file; do
      if [[ $(head -c 2 "$file") == '#!' ]]; then
        chmod u+x "$file"
        executable_count=$((executable_count + 1))
      fi
    done < <(find "$directory" -type f -print0)
    echo "Made $executable_count scripts executable in $directory."
  else
    echo "Skipping executable directory: $directory does not exist." >&2
  fi
done

cat <<EOF

Initial setup is complete. Review the generated changes, then run:

  nix --extra-experimental-features 'nix-command flakes' flake check
  sudo nixos-rebuild switch --flake "$repo_root#desktop" \\
    --option experimental-features 'nix-command flakes'

After the rebuild, log out and back in so the new desktop session, groups, and
Home Manager environment are all active.
EOF
