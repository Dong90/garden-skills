#!/usr/bin/env bash
# run 子命令：state-driven dispatch
#   无 my-video          → 提示跑 init
#   P0 + 无 script.md    → 输出"让 Cursor agent 写"提示
#   P0 + script 在        → 跑 selftest
#   P1 (selftest 通过)   → 跑 pipeline
#   P2 (pipeline 完成)   → 提示跑 /chapter-to-video-record
#
# 用法: chapter-to-video.sh run <target> [--help]
# 每个子任务成功完成时自动写快照到 .book-video/snapshots/

cmd_run() {
  # -- 0. --help 优先（兼容两种调用：run --help / run <target> --help）
  if [[ "${1:-}" == "my-video" && "${2:-}" == "--help" ]] || \
     [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP'
run — state-driven 5 步子任务推进

用法:
  chapter-to-video.sh run <target>          # 跑下一个子任务
  chapter-to-video.sh run <target> --help   # 本帮助
  chapter-to-video.sh run --help            # 本帮助（无 target）

state 驱动的分支:
  无 my-video/                  -> 提示跑 init（要输入文件）
  P0 done + 无 script.md         -> 输出"让 Cursor agent 写 script.md + outline.md" prompt
  P0 done + script/outline 在     -> 跑 selftest（自动跳 P0 -> P1）
  P1 (selftest 过) + presentation -> 跑 pipeline（自动跳 P1 -> P2）
  P2 (pipeline 完)              -> 提示跑 /chapter-to-video-record

成功完成时自动写快照:
  .book-video/snapshots/phase-P<n>-<hash>.tar.gz

回退:
  chapter-to-video.sh rollback <target> --to=P<n> --yes
HELP
    return 0
  fi

  local target="${1:-my-video}"
  shift 2>/dev/null || true
  # 此时 $1 是 --help（如果有）
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    # 上面分支已 return 0，到这里是死代码
    return 0
  fi

  # 相对路径转绝对
  if [[ "$target" != /* ]]; then
    target="$(cd "$target" 2>/dev/null && pwd || echo "$target")"
  fi

  # -- 1. 无 my-video -> 提示 init
  if [[ ! -d "$target" ]]; then
    cat <<INITMSG
▸ run · 无 $target/

需要先跑 init：
  bash scripts/chapter-to-video.sh /path/to/chapter.md --out=$target --theme=kraft-paper

init 会创建 $target/ 并写 article.md / STATE.md / meta.json / presentation/ 脚手架。
INITMSG
    return 0
  fi

  # -- 2. 读 state.json + 检测实际文件
  local state_json="$target/.book-video/state.json"
  if [[ ! -f "$state_json" ]]; then
    echo "✗ $state_json 缺失（$target 不是 init 出来的）"
    return 1
  fi

  local phase script_exists outline_exists chap_root
  phase=$(python3 -c "import json; print(json.load(open('$state_json')).get('phase','P0'))")
  script_exists="no"
  outline_exists="no"
  [[ -f "$target/script.md"  ]] && script_exists="yes"
  [[ -f "$target/outline.md" ]] && outline_exists="yes"
  chap_root="$target/presentation/src/chapters"

  echo "▸ run · $target  (phase=$phase, script=$script_exists, outline=$outline_exists)"
  echo

  # -- 分支 A: P0 done + 无 script.md -> 写稿提示
  if [[ "$phase" == "P0" && "$script_exists" == "no" ]]; then
    cat <<WRITE
5 步子任务 #2 · 写稿

请让 Cursor agent 写 $target/script.md（口播稿）和 $target/outline.md（开发计划）。

agent 任务清单:
  1. 读 $target/BOOK-CHAPTER.md（章节特化规则）
  2. 读 $target/article.md（用户原文）
  3. 写 $target/script.md（按 references/SCRIPT-STYLE.md）
  4. 写 $target/outline.md（按 references/OUTLINE-FORMAT.md）
  5. 完成后用户再调一次 run，会自动跑 selftest

写完后再跑:
  bash scripts/chapter-to-video.sh run $target
WRITE
    return 0
  fi

  # -- 分支 B: 有 script.md + outline.md -> 跑 selftest
  if [[ "$phase" == "P0" && "$script_exists" == "yes" && "$outline_exists" == "yes" ]]; then
    echo "── 5 步子任务 #3 · 验收 ──"
    echo
    if ! bash "$SKILL_DIR/scripts/chapter-to-video.sh" selftest "$target"; then
      echo
      echo "✗ selftest 不过。修稿后再 run。"
      return 1
    fi
    echo
    echo "── 5 步子任务 #3.5 · judge 评分 ──"
    bash "$SKILL_DIR/scripts/chapter-to-video.sh" judge "$target" || true

    # 推进 phase: P0 -> P1 (content done)
    python3 - "$state_json" <<'PYEND2'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['phase'] = 'P1'
d['phase_status'] = 'done'
d['next_action'] = '跑 chapter-to-video.sh run (P2 pipeline, 等用户跑)'
open(p, 'w').write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
PYEND2
    # 自动快照 P1
    # shellcheck disable=SC1091
    source "$SKILL_DIR/scripts/commands/_snapshot.sh"
    local snap
    snap=$(snapshot_create "$target" "P1") && echo "✓ 快照: $(basename "$snap")"
    echo
    echo "下一步: 让 Cursor agent 实现第 1 章（presentation/src/chapters/01-xxx/）"
    echo "  写完后再跑: run $target → 跑 pipeline"
    return 0
  fi

  # -- 分支 C: P1 done -> 跑 pipeline
  if [[ "$phase" == "P1" || "$phase" == "P2" ]]; then
    if [[ ! -d "$chap_root" ]]; then
      echo "✗ $chap_root 不存在。先让 agent 实现第 1 章。"
      echo "  任务: cd $target/presentation && npm run dev 验证骨架，然后 agent 加章节"
      return 1
    fi
    local n_chap
    n_chap=$(ls -1d "$chap_root"/*/ 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$n_chap" -eq 0 ]]; then
      echo "✗ $chap_root 没有章节。先让 agent 实现第 1 章。"
      return 1
    fi

    echo "── 5 步子任务 #4 · 多媒体 ──"
    echo
    if ! bash "$SKILL_DIR/scripts/chapter-to-video.sh" pipeline "$target" --dry-run; then
      return 1
    fi
    echo
    echo "  (上面是 dry-run 预览。要真跑，去掉 --dry-run)"
    echo "  正式跑: chapter-to-video.sh pipeline $target"
    return 0
  fi

  # -- 分支 D: P3 done -> 提示录屏
  if [[ "$phase" == "P3" || "$phase" == "P4" ]]; then
    cat <<RECORD
✓ 5 步子任务 #4 完成

下一步：跑 /chapter-to-video-record 启动录屏。
  - cd $target/presentation && npm run dev
  - 浏览器开 http://localhost:5173/?auto=1
  - QuickTime 录屏
RECORD
    return 0
  fi

  # -- fallback: 未知 phase
  echo "✗ 未知 phase: $phase（state.json 损坏？）"
  return 1
}
