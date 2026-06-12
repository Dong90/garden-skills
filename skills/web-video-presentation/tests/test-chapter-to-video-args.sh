#!/usr/bin/env bash
# T3: 参数校验（无输入 / 错误主题 / 错误参数）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

# ── 1. 无输入文件 ──
run_capture bash "$SCRIPT"
assert_exit "no input → exit != 0" "1" bash "$SCRIPT"
assert_contains "no input → error message" "必须指定输入" "$(bash "$SCRIPT" 2>&1 || true)"

# ── 2. 错误的主题 ──
TMPDIR=$(make_tmpdir)
echo "test chapter" > "$TMPDIR/c.md"
assert_exit "bad theme → exit != 0" "1" bash "$SCRIPT" "$TMPDIR/c.md" --theme=does-not-exist
assert_contains "bad theme → error message" "主题不存在" "$(bash "$SCRIPT" "$TMPDIR/c.md" --theme=does-not-exist 2>&1 || true)"

# ── 3. 未知参数 ──
assert_exit "unknown arg → exit != 0" "1" bash "$SCRIPT" "$TMPDIR/c.md" --bogus
assert_contains "unknown arg → error message" "未知参数" "$(bash "$SCRIPT" "$TMPDIR/c.md" --bogus 2>&1 || true)"

# ── 4. 不存在的输入文件 ──
assert_exit "missing file → exit != 0" "1" bash "$SCRIPT" /nonexistent/path.md

# ── 5. 多个输入文件 ──
echo "a" > "$TMPDIR/a.md"
echo "b" > "$TMPDIR/b.md"
assert_exit "two inputs → exit != 0" "1" bash "$SCRIPT" "$TMPDIR/a.md" "$TMPDIR/b.md"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-args"
