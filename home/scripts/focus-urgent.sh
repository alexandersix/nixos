set -euo pipefail

mapfile -t urgent_ids < <(
  mmsg get all-clients | jq -r '.clients[] | select(.is_urgent == true) | .id'
)

if ((${#urgent_ids[@]} == 0)); then
  exit 0
fi

state_file="${XDG_RUNTIME_DIR:-/tmp}/mango-focus-urgent-${UID}.last"
last_id=""

if [[ -r "$state_file" ]]; then
  read -r last_id < "$state_file" || true
fi

target_id="${urgent_ids[0]}"

for i in "${!urgent_ids[@]}"; do
  if [[ "${urgent_ids[i]}" == "$last_id" ]]; then
    target_id="${urgent_ids[(i + 1) % ${#urgent_ids[@]}]}"
    break
  fi
done

mmsg dispatch focusid client,"$target_id" >/dev/null
printf '%s\n' "$target_id" > "$state_file"
