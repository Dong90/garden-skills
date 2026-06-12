#!/usr/bin/env bash
# T7: 拆集决策
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

# 制作不同长度的 fixture
TMPDIR=$(make_tmpdir)

# 1500 字（< 3000）→ 估时 ~8 分钟
python3 -c "
content = '# 短\n\n'
content += ('这是一段用来测试短章节字数的中文内容。' * 5 + '\n') * 8
open('$TMPDIR/short-1500.md', 'w').write(content)
"

# 4000 字（3000-5000）→ 估时 ~20 分钟
python3 -c "
content = '# 中等\n\n'
content += ('这是一段用来测试中等等章节字数的中文内容，用来凑字数。' * 5 + '\n') * 40
open('$TMPDIR/mid-4000.md', 'w').write(content)
"

# 6500 字（5000-8000）→ 估时 ~33 分钟
python3 -c "
content = '# 偏长\n\n'
content += ('这是一段用来测试偏长章节字数的中文内容，用来凑字数。' * 5 + '\n') * 33
open('$TMPDIR/long-6500.md', 'w').write(content)
"

# > 8000 字（用 long fixture 即可）
# long-chapter.md 在 fixtures/，已经 54003 字

# ── 1. 短章节 → 1 集，无警告 ──
set +e
out_short=$(bash "$SCRIPT" "$TMPDIR/short-1500.md" 2>&1)
set -e
assert_contains "1500 字: 集数: 1" "集数: 1" "$out_short"
assert_not_contains "1500 字: 不警告" "⚠" "$out_short"

# ── 2. 中等等 → 1 集，但警告 ──
set +e
out_mid=$(bash "$SCRIPT" "$TMPDIR/mid-4000.md" 2>&1)
set -e
assert_contains "4000 字: 集数: 1" "集数: 1" "$out_mid"
assert_contains "4000 字: 警告" "⚠" "$out_mid"

# ── 3. 偏长 → 1 集，但强烈建议 ──
set +e
out_long=$(bash "$SCRIPT" "$TMPDIR/long-6500.md" 2>&1)
set -e
assert_contains "6500 字: 集数: 1" "集数: 1" "$out_long"
assert_contains "6500 字: 警告" "⚠" "$out_long"

# ── 4. 超长 → 1 集，但强烈建议 ──
set +e
out_xlong=$(bash "$SCRIPT" "tests/fixtures/long-chapter.md" 2>&1)
set -e
assert_contains "54000 字: 集数: 1（默认）" "集数: 1" "$out_xlong"
assert_contains "54000 字: 强烈建议" "强烈建议" "$out_xlong"

# ── 5. --episodes=2 强制覆盖 ──
set +e
out_force=$(bash "$SCRIPT" "tests/fixtures/long-chapter.md" --episodes=2 2>&1)
set -e
assert_contains "--episodes=2: 集数: 2" "集数: 2" "$out_force"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-episodes"
