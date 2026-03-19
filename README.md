# FanCurve — NVIDIA fan control in Docker

This packages [RoversX/nvidia_fan_control_linux](https://github.com/RoversX/nvidia_fan_control_linux) as a container and optional systemd unit so the fan curve runs after boot.

## Prerequisites (host)

- [NVIDIA proprietary driver](https://www.nvidia.com/Download/index.aspx) on Linux
- [Docker Engine](https://docs.docker.com/engine/install/) and [Docker Compose v2](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) so `docker run --gpus all` works

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

Credit: upstream script and behavior are from [nvidia_fan_control_linux](https://github.com/RoversX/nvidia_fan_control_linux).
