#!/bin/bash
# Install the GPU-temperature fan controller. Run with sudo.
#   sudo ~/install-gpu-fan-control.sh "5"      # channels to drive
set -euo pipefail
CH="${1:?usage: install-gpu-fan-control.sh \"<pwm channels>\"}"
install -m 755 /home/mvanberg/gpu-fan-control.py /usr/local/bin/gpu-fan-control
echo nct6775 > /etc/modules-load.d/nct6775.conf
modprobe nct6775
cat > /etc/systemd/system/gpu-fan-control.service <<UNIT
[Unit]
Description=Drive case fan headers ($CH) from NVIDIA GPU temperature
After=systemd-modules-load.service gpu-power-limit.service

[Service]
Environment=FAN_PWM=$CH
ExecStart=/usr/local/bin/gpu-fan-control
# Even after a SIGKILL, hand the channels back to BIOS auto mode.
ExecStopPost=/bin/sh -c 'for h in /sys/class/hwmon/hwmon*; do grep -q nct67 \$h/name || continue; for c in $CH; do echo 5 > \$h/pwm\${c}_enable; done; done'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now gpu-fan-control
sleep 3
systemctl --no-pager status gpu-fan-control | head -12
