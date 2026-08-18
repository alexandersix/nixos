set -euo pipefail

CONFIG_DIR=""
LOCAL_STATE=""
PICKER_PROMPT="Chromium profile"

notify_error() {
  local message="$1"

  echo "$message" >&2
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Chromium profile picker" "$message"
  fi
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    notify_error "$command_name not found in PATH"
    return 1
  fi
}

get_default_browser_exec() {
  local desktop_file desktop_path exec_line browser_exec
  local data_dirs
  local -a application_dirs

  desktop_file=$(xdg-settings get default-web-browser 2>/dev/null || true)
  if [[ -z "$desktop_file" ]]; then
    notify_error "No default browser is configured"
    return 1
  fi

  data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
  application_dirs=("${XDG_DATA_HOME:-$HOME/.local/share}/applications")

  local data_dir
  while IFS= read -r data_dir; do
    [[ -n "$data_dir" ]] && application_dirs+=("$data_dir/applications")
  done < <(printf '%s\n' "$data_dirs" | tr ':' '\n')

  for data_dir in "${application_dirs[@]}"; do
    desktop_path="$data_dir/$desktop_file"
    [[ -f "$desktop_path" ]] || continue

    exec_line=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Exec=//p;}' "$desktop_path" | head -n 1)
    if [[ -n "$exec_line" ]]; then
      browser_exec="${exec_line%%[[:space:]]*}"
      browser_exec="${browser_exec#\"}"
      browser_exec="${browser_exec%\"}"
      printf '%s\n' "$browser_exec"
      return 0
    fi
  done

  notify_error "Default browser desktop file not found or has no Exec: $desktop_file"
  return 1
}

set_browser_profile_paths() {
  local browser_exec="$1"
  local browser_name
  browser_name=$(basename "$browser_exec")

  case "$browser_name" in
    chromium | chromium-browser)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chromium"
      ;;
    google-chrome | google-chrome-stable)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/google-chrome"
      ;;
    brave | brave-browser)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser"
      ;;
    microsoft-edge | microsoft-edge-stable)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/microsoft-edge"
      ;;
    vivaldi | vivaldi-stable)
      CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/vivaldi"
      ;;
    *)
      notify_error "Default browser does not support Chromium profile directories: $browser_name"
      return 1
      ;;
  esac

  LOCAL_STATE="$CONFIG_DIR/Local State"
}

get_profiles() {
  if [[ ! -d "$CONFIG_DIR" ]]; then
    notify_error "Browser config directory not found: $CONFIG_DIR"
    return 1
  fi

  if [[ ! -f "$LOCAL_STATE" ]]; then
    notify_error "Browser Local State not found: $LOCAL_STATE"
    return 1
  fi

  jq -r '.profile.info_cache // {} | to_entries[] | "\(.value.name // .key)\t\(.key)"' "$LOCAL_STATE" |
    while IFS=$'\t' read -r name dir_name; do
      if [[ -d "$CONFIG_DIR/$dir_name" ]]; then
        printf '%s\t%s\n' "$name" "$dir_name"
      fi
    done
}

for dependency in xdg-settings jq noctalia setsid; do
  require_command "$dependency" || exit 1
done

browser_exec=$(get_default_browser_exec) || exit 1
set_browser_profile_paths "$browser_exec" || exit 1

if [[ "$browser_exec" == */* ]]; then
  if [[ ! -x "$browser_exec" ]]; then
    notify_error "Browser executable is not executable: $browser_exec"
    exit 1
  fi
elif ! command -v "$browser_exec" >/dev/null 2>&1; then
  notify_error "Browser executable not found in PATH: $browser_exec"
  exit 1
fi

profiles_output=$(get_profiles) || exit 1
if [[ -z "$profiles_output" ]]; then
  notify_error "No Chromium profiles found in $CONFIG_DIR"
  exit 1
fi

mapfile -t profiles <<< "$profiles_output"

names=()
dirs=()
for profile in "${profiles[@]}"; do
  names+=("${profile%%$'\t'*}")
  dirs+=("${profile#*$'\t'}")
done

displays=()
for i in "${!names[@]}"; do
  duplicate_count=0
  for candidate in "${names[@]}"; do
    if [[ "$candidate" == "${names[$i]}" ]]; then
      ((duplicate_count += 1))
    fi
  done

  if ((duplicate_count > 1)); then
    displays+=("${names[$i]} (${dirs[$i]})")
  else
    displays+=("${names[$i]}")
  fi
done

selection=$(
  printf '%s\n' "${displays[@]}" |
    noctalia dmenu --prompt "$PICKER_PROMPT" 2>/dev/null || true
)

if [[ -z "$selection" ]]; then
  exit 0
fi

profile_dir=""
for i in "${!displays[@]}"; do
  if [[ "${displays[$i]}" == "$selection" ]]; then
    profile_dir="${dirs[$i]}"
    break
  fi
done

if [[ -z "$profile_dir" ]]; then
  notify_error "Profile not found: $selection"
  exit 1
fi

exec setsid --fork "$browser_exec" --new-window --profile-directory="$profile_dir"
