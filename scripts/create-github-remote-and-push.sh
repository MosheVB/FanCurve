#!/usr/bin/env bash
# Requires: https://cli.github.com/ — install `gh` and run `gh auth login` once.
# Creates github.com/<you>/FanCurve (or override NAME) and pushes the current branch.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="${GITHUB_REPO_NAME:-FanCurve}"
VISIBILITY="${GITHUB_REPO_VISIBILITY:-public}" # or --private

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI: https://cli.github.com/  (e.g. apt install gh)" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Run: gh auth login" >&2
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' already exists:" >&2
  git remote -v >&2
  exit 1
fi

case "$VISIBILITY" in
  public)  VIS_FLAG=(--public) ;;
  private) VIS_FLAG=(--private) ;;
  *) echo "GITHUB_REPO_VISIBILITY must be public or private" >&2; exit 1 ;;
esac

gh repo create "$NAME" "${VIS_FLAG[@]}" --source="$ROOT" --remote=origin --push
echo "Done. origin -> $(git remote get-url origin)"
