# The filenames and hashes here intentionally mirror modules/private-fonts.nix.
# Keeping only this metadata in the public repository does not redistribute the
# licensed font software.
FONT_FILES=(
  "CabinetGrotesk_Complete/Fonts/TTF/CabinetGrotesk-Variable.ttf|sha256-dBS0WUrXGsPSNqn41KtsRcOVgok7IslOJkdpT+nim14="
  "Chillax_Complete/Fonts/TTF/Chillax-Variable.ttf|sha256-NKT4D/0mlzqn1TE2qb3784/9ObtQezTActUCPYONVsg="
  "ClashDisplay_Complete/Fonts/TTF/ClashDisplay-Variable.ttf|sha256-wcAvJ16IY8+k09Ra7UgDJ3qugZfcykc5aaVzwahO3ZI="
  "ClashGrotesk_Complete/Fonts/TTF/ClashGrotesk-Variable.ttf|sha256-WIeh383/KlTNtH7wFlZW5zXmDVDmGCplXxKXjS8N0S0="
  "GeneralSans_Complete/Fonts/TTF/GeneralSans-Variable.ttf|sha256-SyU52e0zZ+j1X33dNpqxPhe7J5/y63/cpscTrxPU34Q="
  "GeneralSans_Complete/Fonts/TTF/GeneralSans-VariableItalic.ttf|sha256-SqDCDbtZOtgrQfCQ+7yO+xv+PfhcqJXAgJL3fUZ/6mA="
  "Ranade_Complete/Fonts/TTF/Ranade-Variable.ttf|sha256-05OVsgQUskoQDCPgaIpC2GsNZsc6mSPIOcnPHnG6Fl8="
  "Ranade_Complete/Fonts/TTF/Ranade-VariableItalic.ttf|sha256-qC8qOSV5eB1lgvz77yV8HoUS3wF2Gx42YYuh2ORBQjo="
  "Satoshi_Complete/Fonts/TTF/Satoshi-Variable.ttf|sha256-Aq0TGSaqRtKCtq9zrSvK7LDsbvO4MKLwjcq+9E8RQP8="
  "Satoshi_Complete/Fonts/TTF/Satoshi-VariableItalic.ttf|sha256-z+j2AKoz3IAHWzGaFq5mPfMMeQG2yzMucOp9+5wItq0="
)

show_help() {
  cat <<'EOF'
Add the licensed Fontshare variable TTFs to the local Nix store.

Usage: nix run .#install-private-fonts -- [FONT_BUNDLE_DIRECTORY]

FONT_BUNDLE_DIRECTORY defaults to ~/fonts. Keep the complete bundles there (or
in another private location); this command installs only their variable TTFs.
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  show_help
  exit 0
fi

font_root=${1:-"$HOME/fonts"}
if [[ ! -d $font_root ]]; then
  echo "error: font bundle directory not found: $font_root" >&2
  exit 1
fi

for entry in "${FONT_FILES[@]}"; do
  IFS='|' read -r relative_path expected_hash <<<"$entry"
  font_file="$font_root/$relative_path"

  if [[ ! -f $font_file ]]; then
    echo "error: required font file not found: $font_file" >&2
    exit 1
  fi

  actual_hash=$(nix hash file --type sha256 "$font_file")
  if [[ $actual_hash != "$expected_hash" ]]; then
    echo "error: unexpected contents for $font_file" >&2
    echo "       expected $expected_hash" >&2
    echo "       found    $actual_hash" >&2
    exit 1
  fi

  nix-store --add-fixed sha256 "$font_file"
done

echo "Added ${#FONT_FILES[@]} variable font files to the local Nix store."
