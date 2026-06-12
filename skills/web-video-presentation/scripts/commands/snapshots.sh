#!/usr/bin/env bash
# snapshots 子命令：列出所有快照
cmd_snapshots() {
  local target="${1:-my-video}"
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  
  local SKILL_DIR
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$SKILL_DIR/scripts/commands/_snapshot.sh"
  
  echo "▸ 快照列表 · $target"
  local list
  list=$(snapshot_list "$target")
  if [[ -z "$list" || "$list" == "(无快照)" ]]; then
    echo "  (无)"
    return 0
  fi
  while IFS= read -r snap; do
    local size phase hash
    size=$(du -h "$snap" | cut -f1)
    phase=$(basename "$snap" | sed -E 's/^phase-(P[0-9]+)-.*/\1/')
    hash=$(basename "$snap" | sed -E 's/^phase-P[0-9]+-([0-9a-f]+)\.tar\.gz/\1/')
    printf "  • %-4s %s.tar.gz  (%s)\n" "$phase" "phase-${phase}-${hash}" "$size"
  done <<< "$list"
  echo
  echo "回退到某 phase：rollback $target --to=P<n> --yes"
}
