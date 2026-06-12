#!/usr/bin/env bash
# T19: /chapter-to-video Cursor 命令文件契约
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# Cursor 打开 garden-skills 时扫描的位置有两个：
#   1) .cursor/commands/   （项目级 · git tracked · 自动识别）
#   2) ~/.cursor/commands/ （用户级 · 跨项目 · 手动 install）
# 我们两者都放（保持 skill 自包含 + 仓库级生效），测试两边都验。

CURSOR_PROJECT="../../.cursor/commands/chapter-to-video.md"
COMMANDS_DIR="commands"
SKILL_COMMAND="$COMMANDS_DIR/chapter-to-video.md"

# ── 1. 仓库根 .cursor/commands/ 文件存在（Cursor 打开本仓库即识别）──
assert_file_exists "Cursor 项目级 command: $CURSOR_PROJECT" "$CURSOR_PROJECT"

# ── 2. skill 自包含副本（让 skill 可独立分发）──
assert_file_exists "skill 自包含 command: $SKILL_COMMAND" "$SKILL_COMMAND"

# 两份内容应一致（skill 是真相源；项目级是 .cursor/ 链接或副本）
if [[ -f "$CURSOR_PROJECT" && -f "$SKILL_COMMAND" ]]; then
  if cmp -s "$CURSOR_PROJECT" "$SKILL_COMMAND"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "两份 command 文件内容一致"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("项目级 vs skill 自包含内容不一致")
    _log_fail "两份 command 文件内容不一致"
  fi
fi

# ── 3. frontmatter 合法 ──
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  FIRST=$(head -1 "$f")
  assert_eq "$f: 以 --- 开头" "---" "$FIRST"
  assert_grep "$f: 含 name 字段" "^name:" "$f"
  assert_grep "$f: 含 description 字段" "^description:" "$f"
  # name 应匹配文件名（Cursor 约定）
  if grep -qE "^name: chapter-to-video" "$f"; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "$f: name 字段 = chapter-to-video"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("$f: name 字段不匹配")
    _log_fail "$f: name 字段不匹配"
  fi
done

# ── 4. 内容必须含入口引用（Cursor 加载后 agent 能找到）──
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  assert_grep "$f: 引用 chapter-to-video.sh"   "chapter-to-video\\.sh"   "$f"
  assert_grep "$f: 引用 BOOK-CHAPTER.md"      "BOOK-CHAPTER"           "$f"
  assert_grep "$f: 提到 minimax 默认 provider" "minimax"                "$f"
  assert_grep "$f: 提到 kraft-paper 默认主题"  "kraft-paper"            "$f"
  assert_grep "$f: 含 bash 调用示例"           "bash "                  "$f"
  assert_grep "$f: 含 --theme 选项"            "\\-\\-theme"             "$f"
done

# ── 5. 含中文（与 SKILL.md / 其它 doc 一致）──
for f in "$CURSOR_PROJECT" "$SKILL_COMMAND"; do
  [[ ! -f "$f" ]] && continue
  assert_contains "$f: 含中文描述" "书籍" "$(cat "$f")"
done

print_summary "test-cursor-command"
