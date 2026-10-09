# FanCurve — NVIDIA fan control in Docker

This packages [RoversX/nvidia_fan_control_linux](https://github.com/RoversX/nvidia_fan_control_linux) as a container and optional systemd unit so the fan curve runs after boot.

## Prerequisites (host)

- [NVIDIA proprietary driver](https://www.nvidia.com/Download/index.aspx) on Linux
- [Docker Engine](https://docs.docker.com/engine/install/) and [Docker Compose v2](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) so `docker run --gpus all` works

## Troubleshooting

If the container exits in a restart loop with `NVMLError_NoPermission` on `nvmlDeviceSetFanSpeed_v2`, the Compose file enables **`privileged: true`** so NVML can change fan speed. That matches what many setups need for manual fan control inside Docker.

## Configure the curve

Edit `nvidia_fan_control.py` in this directory (`temperature_points`, `fan_speed_points`, `gpus`, etc.), then rebuild:

```bash
docker compose build --no-cache && docker compose up -d
```

## Run manually (no systemd)

```bash
docker compose up -d
docker compose logs -f
```

Stop:

```bash
docker compose down
```

## Run on boot (systemd)

From this repository root:

```bash
chmod +x install-service.sh
./install-service.sh
```

That installs `/etc/systemd/system/nvidia-fan-control.service`, enables it, and starts it. The unit’s `WorkingDirectory` is set to wherever you cloned this repo, so keep the project in that path or re-run the installer after moving it.

Check:

```bash
sudo systemctl status nvidia-fan-control.service
journalctl -u nvidia-fan-control.service -f
```

## Deploy

`dev` is where work happens; `main` is what is deployed. On ms01:

```bash
deploy FanCurve            # fast-forward main to dev, then run deploy/deploy.sh
deploy FanCurve --dry-run  # show what would go out
```

`deploy` lives in `~/nomad-cluster/bin`. What the deploy step does is described at the top of
`deploy/deploy.sh`.
