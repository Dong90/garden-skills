#!/usr/bin/env bash
# T19: Cursor 命令文件契约（4 文件版）
# 单文件 → 4 文件拆分后，老的关键词扫描在 4 个文件上做并集验证。
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

# 4 个目标文件（project-root 与 skill 自包含）
SKILL_COMMANDS="commands"
PROJ_COMMANDS="../../.cursor/commands"
FILES=(
  "chapter-to-video-plan.md"
  "chapter-to-video-run.md"
  "chapter-to-video-status.md"
  "chapter-to-video-record.md"
  "chapter-to-video.md"   # router
)

concat_all_skill() { cat "$SKILL_COMMANDS"/chapter-to-video*.md 2>/dev/null; }
concat_all_proj()  { cat "$PROJ_COMMANDS"/chapter-to-video*.md  2>/dev/null; }

ALL_SKILL=$(concat_all_skill)
ALL_PROJ=$(concat_all_proj)

# ── 1. 4 文件 + router 都存在（两边）──
for f in "${FILES[@]}"; do
  assert_file_exists "skill: commands/$f"        "$SKILL_COMMANDS/$f"
  assert_file_exists "project: .cursor/commands/$f" "$PROJ_COMMANDS/$f"
done

# ── 2. 两边 5 文件内容应一致（项目根是 skill 镜像）──
for f in "${FILES[@]}"; do
  if cmp -s "$SKILL_COMMANDS/$f" "$PROJ_COMMANDS/$f"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "镜像一致: $f"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$f: skill vs .cursor/commands 不一致")
    _log_fail "镜像不一致: $f"
  fi
done

# ── 3. 5 文件并集必须含的关键词（key 入口可发现）──
# 以前单文件含的关键词，现在在 5 文件并集里至少出现一次。
for keyword_re in \
  "chapter-to-video\\.sh" \
  "BOOK-CHAPTER"          \
  "minimax"               \
  "kraft-paper"           \
  "bash "                 \
  "\\-\\-theme"           \
  "STATE\\.md"
do
  for side in skill proj; do
    if [[ "$side" = skill ]]; then haystack="$ALL_SKILL"; path="skill(concat)"; else haystack="$ALL_PROJ"; path="proj(concat)"; fi
    if echo "$haystack" | grep -qE "$keyword_re"; then
      _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
      _log_pass "$path: 含 $keyword_re"
    else
      _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
      _TEST_FAILURES+=("$path: 缺 $keyword_re（5 文件并集里应能找到）")
      _log_fail "$path: 缺 $keyword_re"
    fi
  done
done

# ── 4. 含中文（与 SKILL.md / 其它 doc 一致）──
for side in skill proj; do
  if [[ "$side" = skill ]]; then haystack="$ALL_SKILL"; else haystack="$ALL_PROJ"; fi
  if echo "$haystack" | grep -q "书籍"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "$side(concat): 含中文"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$side(concat): 缺中文")
    _log_fail "$side(concat): 缺中文"
  fi
done

print_summary "test-cursor-command"
