set -euo pipefail

show_help() {
  cat <<'EOF'
Export Noctalia's merged user configuration into the NixOS repository.

Usage: sync-noctalia-config [--repo PATH]

Options:
  --repo PATH  NixOS repository root. Defaults to $NIXOS_CONFIG_DIR, then
               checks ~/nixos, ~/Code/nixos, and ~/.config/nixos.
  -h, --help   Show this help.
EOF
}

repo_root=""

while (($# > 0)); do
  case "$1" in
    --repo)
      [[ $# -ge 2 ]] || {
        echo "error: --repo requires a path" >&2
        exit 2
      }
      repo_root=$2
      shift 2
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

if ! command -v noctalia >/dev/null 2>&1; then
  echo "error: noctalia is not available in PATH" >&2
  exit 1
fi

if [[ -z "$repo_root" && -n "${NIXOS_CONFIG_DIR:-}" ]]; then
  repo_root=$NIXOS_CONFIG_DIR
fi

if [[ -z "$repo_root" ]]; then
  for candidate in "$HOME/nixos" "$HOME/Code/nixos" "$HOME/.config/nixos"; do
    if [[ -f "$candidate/flake.nix" && -f "$candidate/home/default.nix" ]]; then
      repo_root=$candidate
      break
    fi
  done
fi

if [[ -z "$repo_root" || ! -f "$repo_root/flake.nix" || ! -f "$repo_root/home/default.nix" ]]; then
  echo "error: NixOS repository not found; pass it with --repo or NIXOS_CONFIG_DIR" >&2
  exit 1
fi

repo_root=$(realpath "$repo_root")
target_dir="$repo_root/home/noctalia"
target_file="$target_dir/config.toml"

mkdir -p "$target_dir"
tmp_file=$(mktemp "$target_dir/.config.toml.tmp.XXXXXX")
trap 'rm -f "$tmp_file"' EXIT

noctalia config export merged > "$tmp_file"
noctalia config validate "$tmp_file"
chmod 0644 "$tmp_file"

if [[ -f "$target_file" ]] && cmp -s "$tmp_file" "$target_file"; then
  echo "Noctalia configuration is already current: $target_file"
  exit 0
fi

mv "$tmp_file" "$target_file"
trap - EXIT

echo "Updated Noctalia configuration: $target_file"
if command -v git >/dev/null 2>&1 && git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$repo_root" status --short -- "home/noctalia/config.toml"
fi
echo "Review and commit the snapshot when it looks right."
