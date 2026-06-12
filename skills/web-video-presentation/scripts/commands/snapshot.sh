#!/usr/bin/env bash
# snapshot 子命令：手动创建一个 phase 快照
#   snapshot <target> --phase=P0
cmd_snapshot() {
  local target="${1:-my-video}"
  shift 2>/dev/null || true
  local phase=""
  for arg in "$@"; do
    case "$arg" in
      --phase=*) phase="${arg#--phase=}" ;;
      --phase)   shift; phase="$1" ;;
    esac
  done
  [[ -n "$phase" ]] || { echo "用法: snapshot <target> --phase=P0|P1|P2|P3"; return 1; }
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  
  local SKILL_DIR
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$SKILL_DIR/scripts/commands/_snapshot.sh"
  
  local snap
  snap=$(snapshot_create "$target" "$phase") || return 1
  local size
  size=$(du -h "$snap" | cut -f1)
  echo "✓ 已创建快照: phase-${phase}-$(basename "$snap" | sed -E "s/^phase-${phase}-//; s/\\.tar\\.gz$//") ($size)"
  echo "  路径: $snap"
}
