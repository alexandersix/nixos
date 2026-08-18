#!/usr/bin/env bash

if (( $# == 0 )); then
  exec imv -i imv-sized
fi

dimensions=$(magick identify -ping -format '%w %h\n' -- "$1" 2>/dev/null | head -n 1) || true
read -r image_width image_height <<< "$dimensions"

monitor=$(mmsg get all-monitors 2>/dev/null | jq -r '
  .monitors[]
  | select(.active)
  | [.width, .height, .scale]
  | @tsv
' 2>/dev/null | head -n 1) || true
IFS=$'\t' read -r monitor_width monitor_height monitor_scale <<< "$monitor"

if [[ ! "$image_width" =~ ^[0-9]+$ ||
      ! "$image_height" =~ ^[0-9]+$ ||
      ! "$monitor_width" =~ ^[0-9]+$ ||
      ! "$monitor_height" =~ ^[0-9]+$ ||
      ! "$monitor_scale" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  exec imv -i imv-sized -s shrink -- "$@"
fi

read -r window_width window_height < <(
  jq -nr \
    --argjson width "$image_width" \
    --argjson height "$image_height" \
    --argjson scale "$monitor_scale" \
    '[$width / $scale | round, $height / $scale | round] | @tsv'
)
buffer_scale=$(jq -nr --argjson scale "$monitor_scale" '$scale | ceil')

usable_width=$((monitor_width - IMV_RESERVED_WIDTH))
usable_height=$((monitor_height - IMV_RESERVED_HEIGHT))

if (( window_width > usable_width || window_height > usable_height )); then
  read -r window_width window_height < <(
    jq -nr \
      --argjson width "$window_width" \
      --argjson height "$window_height" \
      --argjson max_width "$((usable_width * 80 / 100))" \
      --argjson max_height "$((usable_height * 80 / 100))" \
      '
        [$max_width / $width, $max_height / $height]
        | min as $scale
        | [$width * $scale | floor, $height * $scale | floor]
        | @tsv
      '
  )

  scaling=shrink
else
  scaling=none
fi

# imv creates its initial Wayland buffer before learning the output scale. Keep
# both dimensions divisible by that scale so fractional-scale outputs do not
# reject odd-sized buffers during the initial commit.
window_width=$(((window_width + buffer_scale - 1) / buffer_scale * buffer_scale))
window_height=$(((window_height + buffer_scale - 1) / buffer_scale * buffer_scale))

exec imv -i imv-sized -W "$window_width" -H "$window_height" -s "$scaling" -- "$@"
