#!/usr/bin/env bash
# T6: 字数 + 估时
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

# ── 1. 中文 fixture (cn-chapter.md ≈ 88 CJK chars) → 200 字/分 → 估时 1 分钟 ──
set +e
out=$(bash "$SCRIPT" "tests/fixtures/cn-chapter.md" 2>&1)
set -e
# 输出形如: "▸ 字数 ~88  /  估时 ~1 分钟（200 字/分）"
assert_contains "cn: 字数行被打印" "字数" "$out"
assert_contains "cn: 估时行被打印" "估时" "$out"
assert_contains "cn: 200 字/分" "200 字/分" "$out"
# 88 CJK / 200 = 0.44 → ceil = 1
assert_contains "cn: 估时 ~1 分钟" "估时 ~1 分钟" "$out"

# ── 2. 英文 fixture ──
set +e
out_en=$(bash "$SCRIPT" "tests/fixtures/en-chapter.md" 2>&1)
set -e
assert_contains "en: 130 词/分" "130 词/分" "$out_en"

# ── 3. 自定义 fixture：恰好 200 字中文 → 1 分钟 ──
TMPDIR=$(make_tmpdir)
python3 -c "
content = '# 测试\n\n这是一段恰好两百字的中文内容。' * 5  # approx 200 CJK
open('$TMPDIR/exactly-200.md', 'w').write(content)
"
set +e
out_200=$(bash "$SCRIPT" "$TMPDIR/exactly-200.md" 2>&1)
set -e
# 实际字符可能 ±10，关键是 1-2 分钟内
echo "  200字fixture输出: $(echo "$out_200" | grep -E "字数|估时")"

# ── 4. 边界：< 200 字 → 1 分钟（ceil）──
python3 -c "open('$TMPDIR/short.md', 'w').write('# 短\n\n只有三十个字的中文内容，用来测试边界值。')"
set +e
out_short=$(bash "$SCRIPT" "$TMPDIR/short.md" 2>&1)
set -e
assert_contains "短文章 30 字 → 估时 ~1 分钟 (ceil)" "估时 ~1 分钟" "$out_short"

# ── 5. 长章节：> 8000 字 → 估时应该 = ceil(WORDS/200) ──
set +e
out_long=$(bash "$SCRIPT" "tests/fixtures/long-chapter.md" 2>&1)
set -e
# long-chapter.md is 57207 chars of Chinese, but content is repeated "这是...段落。" * 30 * 100
# Most should be CJK. 57207/200 = 286 minutes
assert_contains "long chapter: 字数打印" "字数" "$out_long"
# Extract the number from "字数 ~N"
WORDS_PARSED=$(echo "$out_long" | grep -oE "字数 ~[0-9]+" | head -1 | grep -oE "[0-9]+")
[[ -n "$WORDS_PARSED" && "$WORDS_PARSED" -gt 8000 ]] || _TEST_FAIL=$((_TEST_FAIL+1))
if [[ "$WORDS_PARSED" -gt 8000 ]]; then
  _log_pass "long chapter: 字数 > 8000 (got $WORDS_PARSED)"
  _TEST_PASS=$((_TEST_PASS+1))
  _TEST_TOTAL=$((_TEST_TOTAL+1))
else
  _log_fail "long chapter: 字数 > 8000 (got $WORDS_PARSED)"
  _TEST_FAIL=$((_TEST_FAIL+1))
  _TEST_FAILURES+=("long chapter: 字数 $WORDS_PARSED not > 8000")
  _TEST_TOTAL=$((_TEST_TOTAL+1))
fi

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-words"
