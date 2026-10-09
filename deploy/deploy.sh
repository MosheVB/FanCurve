#!/usr/bin/env bash
# deploy/deploy.sh for FanCurve, run by `deploy FanCurve` on ms01 (cwd = clean worktree of main).
#
# The container nvidia-fan-control runs from the live checkout ~/Workspace/FanCurve (branch main): the root
# boot unit /etc/systemd/system/nvidia-fan-control.service has WorkingDirectory there. Never run compose from
# the deploy clone - same container_name, it would clash. So this script:
#   1. refuses if the live checkout has uncommitted changes to tracked files
#   2. fast-forwards it to the commit being deployed (refuses if not a fast-forward)
#   3. if container files changed (or --rebuild): docker compose build && docker compose up -d, in the live dir
#   4. verifies the container is running and its logs show no NVMLError_NoPermission after ~10 s
#   5. prints (does not run) the sudo steps for changes that need root: i93080/ (case fans on i93080) and
#      the ms01 boot unit (systemd/, install-service.sh)
#
#   deploy.sh [--rebuild]
#
# A bad curve can overheat the GPU: test curve changes before promoting. Last resort: `docker compose down`
# in the live dir hands the fan back to the driver's automatic control.
set -euo pipefail
LIVE=${DEPLOY_LIVE:-$HOME/Workspace/FanCurve} # DEPLOY_LIVE: for testing against a scratch checkout only
NAME=nvidia-fan-control
force=0
for a in "$@"; do
  case $a in
  --rebuild) force=1 ;;
  *) echo "deploy: unknown argument $a" >&2; exit 2 ;;
  esac
done
die() { echo "deploy: $*" >&2; exit 1; }

target=$(git rev-parse HEAD)
echo "== FanCurve: deploying ${DEPLOY_SHA:-${target:0:7}} (main was ${DEPLOY_PREV_SHA:-?}) to $LIVE"

[[ -d $LIVE/.git ]] || die "$LIVE is not a git checkout"
dirty=$(git -C "$LIVE" status --porcelain --untracked-files=no)
if [[ -n $dirty ]]; then
  echo "$dirty" | sed 's/^/   /' >&2
  die "$LIVE has uncommitted changes to tracked files (above) - commit them to dev or revert them, then re-run deploy"
fi

git -C "$LIVE" fetch -q origin
old=$(git -C "$LIVE" rev-parse HEAD)
if [[ $old != "$target" ]]; then
  git -C "$LIVE" merge-base --is-ancestor "$old" "$target" ||
    die "$LIVE HEAD ${old:0:7} is not an ancestor of ${target:0:7} - not a fast-forward, fix by hand"
  git -C "$LIVE" merge -q --ff-only "$target"
  echo "   live: ${old:0:7} -> ${target:0:7}"
else
  echo "   live already at ${target:0:7}"
fi
changed=$(git -C "$LIVE" diff --name-only "$old" "$target")
[[ -n $changed ]] && echo "$changed" | sed 's/^/   changed: /'

notes=()
if grep -qE '^i93080/' <<<"$changed"; then
  notes+=("i93080/ changed: install it on i93080 (needs sudo there), from ms01:
     scp $LIVE/i93080/gpu-fan-control.py $LIVE/i93080/install-gpu-fan-control.sh i93080:~/
     ssh -t i93080 'sudo ~/install-gpu-fan-control.sh \"5\"'")
fi
if grep -qE '^(systemd/|install-service\.sh)' <<<"$changed"; then
  notes+=("boot unit changed: re-install it on ms01 (sudo): cd $LIVE && ./install-service.sh")
fi
print_notes() { for n in "${notes[@]}"; do echo "== NOTE (not done): $n"; done; }

container=$(grep -E '^(Dockerfile|docker-compose\.yml|\.dockerignore|requirements\.txt|nvidia_fan_control\.py)$' <<<"$changed" || true)
if [[ -z $container && $force == 0 ]]; then
  echo "== no container changes - nothing to rebuild"
  [[ $(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null) == true ]] || die "$NAME is not running (it was not touched by this deploy)"
  print_notes
  echo "== ok: $NAME running, untouched"
  exit 0
fi

cd "$LIVE"
echo "== docker compose build ($LIVE)"
docker compose build
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "== docker compose up -d"
docker compose up -d
sleep 12
[[ $(docker inspect -f '{{.State.Running}} {{.State.Restarting}}' "$NAME") == "true false" ]] ||
  die "$NAME is not running steadily: $(docker inspect -f '{{.State.Status}} restarts={{.RestartCount}}' "$NAME")"
logs=$(docker logs --since "$started" "$NAME" 2>&1 || true)
grep -q 'NoPermission' <<<"$logs" && { tail -n 20 <<<"$logs" >&2; die "$NAME logs show NVMLError_NoPermission"; }
[[ -n $logs ]] && tail -n 3 <<<"$logs" | sed 's/^/   /'
command -v nvidia-smi >/dev/null && echo "   $(nvidia-smi --query-gpu=fan.speed,temperature.gpu --format=csv,noheader)"
print_notes
echo "== ok: $NAME@${target:0:7} running"
