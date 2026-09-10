#!/usr/bin/env bash

# Treat cancelling the region picker as a normal no-op.
if ! region="$(slurp)" || [[ -z "$region" ]]; then
  exit 0
fi

mkdir -p "$HOME/Downloads"

# PPM avoids spending time compressing an intermediate image. Satty produces
# PNG output when copying or saving the finished annotation.
grim -g "$region" -t ppm - | satty \
  --filename - \
  --resize=smart \
  --output-filename "$HOME/Downloads/Screenshot-%Y-%m-%d_%H-%M-%S.png" \
  --copy-command wl-copy \
  --actions-on-enter=save-to-clipboard \
  --early-exit \
  --early-exit-save-as
