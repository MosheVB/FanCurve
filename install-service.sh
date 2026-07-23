#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_SRC="${SCRIPT_DIR}/systemd/nvidia-fan-control.service.in"
UNIT_DST="/etc/systemd/system/nvidia-fan-control.service"

if [[ ! -f "$UNIT_SRC" ]]; then
  echo "Missing template: $UNIT_SRC" >&2
  exit 1
fi

tmp="$(mktemp)"
sed "s|@@PROJECT_DIR@@|${SCRIPT_DIR}|g" "$UNIT_SRC" >"$tmp"
sudo install -m 0644 "$tmp" "$UNIT_DST"
rm -f "$tmp"

sudo systemctl daemon-reload
sudo systemctl enable nvidia-fan-control.service
sudo systemctl restart nvidia-fan-control.service

echo "Installed ${UNIT_DST} (WorkingDirectory=${SCRIPT_DIR})"
echo "Status:"
sudo systemctl --no-pager status nvidia-fan-control.service || true
