#!/usr/bin/env bash
# T24: 4 命令文件含子命令文档（拆分后扫 4 个文件）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

SKILL_COMMANDS="commands"
PROJ_COMMANDS="../../.cursor/commands"
FILES=(
  "chapter-to-video-plan.md"
  "chapter-to-video-run.md"
  "chapter-to-video-status.md"
  "chapter-to-video-record.md"
  "chapter-to-video.md"
)
ALL_SKILL=$(cat "$SKILL_COMMANDS"/chapter-to-video*.md 2>/dev/null)
ALL_PROJ=$(cat  "$PROJ_COMMANDS"/chapter-to-video*.md  2>/dev/null)

# ── 1. 文件存在 + 镜像一致 ──
for f in "${FILES[@]}"; do
  assert_file_exists "skill: commands/$f"        "$SKILL_COMMANDS/$f"
  assert_file_exists "project: .cursor/commands/$f" "$PROJ_COMMANDS/$f"
  if cmp -s "$SKILL_COMMANDS/$f" "$PROJ_COMMANDS/$f"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "镜像一致: $f"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$f 不一致")
    _log_fail "镜像不一致: $f"
  fi
done

# ── 2. 5 文件并集必须含的子命令 / 关键引用 ──
# 任何子命令、STATE.md、status/selftest/pipeline 调用、minimax/BOOK-CHAPTER 入口
# 至少在 4 文件里出现一次（拆分后分散在多个文件里）。
required_patterns=(
  "status"            "selftest"         "pipeline"
  "STATE\\.md"        "chapter-to-video\\.sh status"
  "chapter-to-video\\.sh selftest"   "chapter-to-video\\.sh pipeline"
  "chapter-to-video\\.sh run"        "chapter-to-video\\.sh snapshot"
  "chapter-to-video\\.sh rollback"   "chapter-to-video\\.sh snapshots"
  "minimax"           "BOOK-CHAPTER"     "chapter-to-video\\.sh"
  "state\\.json"      "4 步"            "5 步"
)
for pat in "${required_patterns[@]}"; do
  for side in skill proj; do
    if [[ "$side" = skill ]]; then haystack="$ALL_SKILL"; else haystack="$ALL_PROJ"; fi
    if echo "$haystack" | grep -qE "$pat"; then
      _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
      _log_pass "$side(concat): 含 /$pat/"
    else
      _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
      _TEST_FAILURES+=("$side(concat): 缺 /$pat/（5 文件并集里应能找到）")
      _log_fail "$side(concat): 缺 /$pat/"
    fi
  done
done

print_summary "test-cursor-command-subcommands"
