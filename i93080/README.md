# i93080 case-fan control (separate from the ms01 container in the repo root)

i93080 (i9-9900K, RTX 3080 Ti) drives its bottom case fans on motherboard header **pwm5** (nct67xx
hwmon) from the GPU temperature. Not Docker: a root systemd service.

- `gpu-fan-control.py` -> installed as `/usr/local/bin/gpu-fan-control`
- `gpu-fan-control.service` -> `/etc/systemd/system/gpu-fan-control.service` (on stop it hands pwm5 back to BIOS auto)
- `install-gpu-fan-control.sh` installs both (needs sudo on i93080)

Imported 2026-10-09 from i93080:~ (the deployed binary matched `~/gpu-fan-control.py`).
Deploying a change needs sudo on i93080, so `promote FanCurve` only prints the command for it.
