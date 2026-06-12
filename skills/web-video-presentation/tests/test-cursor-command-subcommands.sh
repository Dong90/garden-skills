#!/usr/bin/env bash
# T24: Cursor command 文件含子命令文档
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

CURSOR_PROJECT="../../.cursor/commands/chapter-to-video.md"
SKILL_COMMAND="commands/chapter-to-video.md"

assert_file_exists "Cursor 项目级 command" "$CURSOR_PROJECT"
assert_file_exists "skill 自包含 command" "$SKILL_COMMAND"

# 两份必须内容一致
if cmp -s "$CURSOR_PROJECT" "$SKILL_COMMAND"; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "两份 command 文件内容一致"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("两份内容不一致")
  _log_fail "两份 command 文件内容不一致"
fi

# 必须含 3 个子命令引用
for sub in "status" "selftest" "pipeline"; do
  for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
    [[ ! -f "$f" ]] && continue
    assert_grep "$f: 含子命令 $sub" "\\b$sub\\b" "$f"
  done
done

# STATE.md
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  assert_grep "$f: 含 STATE.md 引用" "STATE.md" "$f"
done

# 子命令调用示例
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  assert_grep "$f: 含 status 调用" "chapter-to-video\\.sh status" "$f"
  assert_grep "$f: 含 selftest 调用" "chapter-to-video\\.sh selftest" "$f"
  assert_grep "$f: 含 pipeline 调用" "chapter-to-video\\.sh pipeline" "$f"
done

# 老的契约不能丢
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  assert_grep "$f: 仍含 chapter-to-video.sh" "chapter-to-video\\.sh" "$f"
  assert_grep "$f: 仍含 BOOK-CHAPTER" "BOOK-CHAPTER" "$f"
  assert_grep "$f: 仍含 minimax" "minimax" "$f"
done

print_summary "test-cursor-command-subcommands"
