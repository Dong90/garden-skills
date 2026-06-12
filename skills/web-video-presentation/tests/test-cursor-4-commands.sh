#!/usr/bin/env bash
# T25: 4 个 Cursor 命令文件契约（plan / run / status / record）
# 把老的单文件 commands/chapter-to-video.md 拆成 4 个，每个独立可被发现。
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

SKILL_DIR="$(pwd)"
SKILL_COMMANDS="commands"
PROJ_COMMANDS="../../.cursor/commands"

# ── 1. 4 个文件都存在（skill 自包含 + 项目根镜像）──
expected_files=(
  "chapter-to-video-plan.md"
  "chapter-to-video-run.md"
  "chapter-to-video-status.md"
  "chapter-to-video-record.md"
)

for f in "${expected_files[@]}"; do
  assert_file_exists "skill: commands/$f"        "$SKILL_COMMANDS/$f"
  assert_file_exists "project: .cursor/commands/$f" "$PROJ_COMMANDS/$f"
done

# ── 2. 两边内容必须一致（项目根是 skill 的镜像）──
for f in "${expected_files[@]}"; do
  if cmp -s "$SKILL_COMMANDS/$f" "$PROJ_COMMANDS/$f"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "镜像一致: $f"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$f: skill vs .cursor/commands 不一致")
    _log_fail "镜像不一致: $f"
  fi
done

# ── 3. 每个文件 frontmatter 合法（--- 头 + name 字段匹配）──
for f in "${expected_files[@]}"; do
  path="$SKILL_COMMANDS/$f"
  [[ ! -f "$path" ]] && continue
  FIRST=$(head -1 "$path")
  assert_eq "$f: 以 --- 开头" "---" "$FIRST"
  expected_name="${f%.md}"
  if grep -qE "^name: $expected_name$" "$path"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "$f: name 字段 = $expected_name"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$f: name 字段应为 $expected_name")
    _log_fail "$f: name 字段不匹配"
  fi
  assert_grep "$f: 含 description" "^description:" "$path"
done

# ── 4. plan 必须 read-only：引用 state.json / STATE.md，不调用 run ──
f="$SKILL_COMMANDS/chapter-to-video-plan.md"
assert_grep "plan: 引用 state.json" "state\\.json" "$f"
assert_grep "plan: 引用 STATE.md"   "STATE\\.md"   "$f"
if grep -qE "chapter-to-video\\.sh run" "$f"; then
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("plan 不应调用 run")
  _log_fail "plan 不应调 chapter-to-video.sh run（read-only）"
else
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "plan 是 read-only（不调 run）"
fi

# ── 5. run 必须：调 run 子命令 + 解释 5 步映射 ──
f="$SKILL_COMMANDS/chapter-to-video-run.md"
assert_grep "run: 调用 chapter-to-video.sh run" "chapter-to-video\\.sh run" "$f"
assert_grep "run: 5 步子任务" "5 步" "$f"
assert_grep "run: 4 步剧本 ↔ 5 步映射" "4 步" "$f"

# ── 6. status 必须：调 status 子命令 + 含 4 步 + 5 步 + 快照 ──
f="$SKILL_COMMANDS/chapter-to-video-status.md"
assert_grep "status: 调用 chapter-to-video.sh status" "chapter-to-video\\.sh status" "$f"
assert_grep "status: 显示 4 步剧本" "4 步" "$f"
assert_grep "status: 显示 5 步子任务" "5 步" "$f"
assert_grep "status: 显示快照列表" "snapshot" "$f"

# ── 7. record 必须：给录屏指引 ──
f="$SKILL_COMMANDS/chapter-to-video-record.md"
assert_grep "record: 提 npm run dev"  "npm run dev"     "$f"
assert_grep "record: 提 auto=1 参数" "auto=1"          "$f"
assert_grep "record: 提录屏"          "QuickTime"       "$f"

# ── 8. 老的单文件 router：保留并指向 4 个新命令 ──
old="$SKILL_COMMANDS/chapter-to-video.md"
if [[ -f "$old" ]]; then
  if grep -qE "plan|run|status|record" "$old"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "老 chapter-to-video.md 保留为 router，引用 4 个新命令"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("老 chapter-to-video.md 应指向 4 个新命令")
    _log_fail "老 chapter-to-video.md 未引用 4 个新命令"
  fi
fi

print_summary "test-cursor-4-commands"
