#!/usr/bin/env bash
# rollback 子命令：从某 phase 的快照恢复
#   rollback <target> --to=P0 --yes
#   rollback <target> --list   (等价于 snapshots)
cmd_rollback() {
  local target="${1:-my-video}"
  shift 2>/dev/null || true
  local to_phase="" yes=0
  for arg in "$@"; do
    case "$arg" in
      --to=*) to_phase="${arg#--to=}" ;;
      --to)   shift; to_phase="$1" ;;
      --yes)  yes=1 ;;
      --list) cmd_snapshots "$target"; return 0 ;;
    esac
  done
  [[ -n "$to_phase" ]] || { echo "用法: rollback <target> --to=P0|P1|P2|P3 [--yes]"; return 1; }
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  
  local SKILL_DIR
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$SKILL_DIR/scripts/commands/_snapshot.sh"
  
  local snapdir
  snapdir=$(snapshot_dir "$target")
  local snap
  snap=$(ls -1t "$snapdir"/phase-${to_phase}-*.tar.gz 2>/dev/null | head -1)
  if [[ -z "$snap" || ! -f "$snap" ]]; then
    echo "✗ 找不到 $to_phase 的快照（先跑完 $to_phase 再回退）"
    echo "  现存快照："
    snapshot_list "$target" | sed 's/^/    /'
    return 1
  fi
  
  echo "⚠ 即将从快照恢复 $target"
  echo "  快照: $snap"
  echo "  ⚠ 当前 $target 的内容会被覆盖（presentation/src/, public/audio/, public/images/ 等）"
  
  if [[ $yes -eq 0 ]]; then
    if [[ -t 0 ]]; then
      read -rp "  确认? 输入 yes 继续: " ans
      [[ "$ans" == "yes" ]] || { echo "  取消"; return 0; }
    else
      echo "  (非交互模式, 加 --yes 跳过确认)"
      return 1
    fi
  fi
  
  if ! snapshot_restore "$target" "$to_phase"; then
    echo "✗ 回退失败"
    return 1
  fi
  
  # 更新 state.json: phase = to_phase, phase_status = rolled_back, next_action 提示下一步
  python3 - "$target/.book-video/state.json" "$to_phase" <<'PY'
import json, sys, datetime
p, phase = sys.argv[1], sys.argv[2]
d = json.load(open(p))
d['phase'] = phase
d['phase_status'] = 'rolled_back'
n = int(phase.lstrip('P')) + 1
d['next_action'] = f"从 {phase} 继续：跑 chapter-to-video.sh run {p} (回退后从 P{n} 继续)"
d['rolled_back_at'] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
open(p, 'w').write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
PY
  # 同步 STATE.md
  if [[ -f "$target/STATE.md" ]]; then
    python3 - "$target/STATE.md" "$to_phase" <<'PY'
import sys, re, datetime
p, phase = sys.argv[1], sys.argv[2]
s = open(p, encoding="utf-8").read()
# 替换 "## 当前阶段" 段
m = re.search(r"(## 当前阶段\n)([\s\S]*?)\n\n", s)
if m:
    new_block = f"{m.group(1)}- [x] Phase 0 · init（chapter-to-video.sh init）\n- [ ] Phase 1 · 内容（script.md + outline.md）\n- [ ] Phase 2 · 网页（章节实现）\n- [ ] Phase 3 · 音频 + 图片\n- [ ] Phase 4 · 录屏\n\n> ⚠ 已回退到 {phase}（{datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}）\n\n"
    s = s[:m.start()] + new_block + s[m.end():]
open(p, 'w', encoding="utf-8").write(s)
PY
  fi
  
  echo "✓ 回退完成 · 当前 phase = $to_phase"
  echo "  下一步：chapter-to-video.sh run $target"
}
