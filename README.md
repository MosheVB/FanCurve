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

## Git / GitHub

This repo is initialized with `main` as the default branch. To create the remote on GitHub and push (needs [GitHub CLI](https://cli.github.com/) and a one-time login):

```bash
gh auth login
./scripts/create-github-remote-and-push.sh
```

For a private repository: `GITHUB_REPO_VISIBILITY=private ./scripts/create-github-remote-and-push.sh`

To use another repo name: `GITHUB_REPO_NAME=my-fan-curve ./scripts/create-github-remote-and-push.sh`

If you prefer the website: create an **empty** repository (no README/license), then:

```bash
git remote add origin git@github.com:YOUR_USER/FanCurve.git
git push -u origin main
```

Credit: upstream script and behavior are from [nvidia_fan_control_linux](https://github.com/RoversX/nvidia_fan_control_linux).
