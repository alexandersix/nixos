set -euo pipefail

PICKER_PROMPT="Mango layout"

layout_names=(
  tile
  scroller
  grid
  monocle
  deck
  center_tile
  right_tile
  vertical_scroller
  vertical_tile
  vertical_grid
  vertical_deck
  dwindle
  fair
  vertical_fair
)

layout_labels=(
  "Tile"
  "Scroller"
  "Grid"
  "Monocle"
  "Deck"
  "Center Tile"
  "Right Tile"
  "Vertical Scroller"
  "Vertical Tile"
  "Vertical Grid"
  "Vertical Deck"
  "Dwindle"
  "Fair"
  "Vertical Fair"
)

notify_error() {
  local message="$1"

  echo "$message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Mango layout picker" "$message"
  fi
}

for dependency in mmsg noctalia; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    notify_error "$dependency not found in PATH"
    exit 1
  fi
done

selection=$(
  printf '%s\n' "${layout_labels[@]}" |
    noctalia dmenu --prompt "$PICKER_PROMPT" 2>/dev/null || true
)

if [[ -z "$selection" ]]; then
  exit 0
fi

layout_name=""
for i in "${!layout_labels[@]}"; do
  if [[ "${layout_labels[$i]}" == "$selection" ]]; then
    layout_name="${layout_names[$i]}"
    break
  fi
done

if [[ -z "$layout_name" ]]; then
  notify_error "Layout not found: $selection"
  exit 1
fi

if ! mmsg dispatch "setlayout,$layout_name"; then
  notify_error "Could not switch to $selection"
  exit 1
fi
