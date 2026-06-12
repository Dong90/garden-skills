#!/usr/bin/env bash
# T5: 语言检测（启发式：cn 字符 > 30% → zh；否则 en）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

# ── 1. 中文章节 → zh ──
set +e
out_cn=$(bash "$SCRIPT" "tests/fixtures/cn-chapter.md" 2>&1)
set -e
assert_contains "cn chapter → 检测到主语言: zh" "检测到主语言: zh" "$out_cn"

# ── 2. 英文章节 → en ──
set +e
out_en=$(bash "$SCRIPT" "tests/fixtures/en-chapter.md" 2>&1)
set -e
assert_contains "en chapter → 检测到主语言: en" "检测到主语言: en" "$out_en"

# ── 3. --lang 强制覆盖 ──
set +e
out_force=$(bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --lang=en 2>&1)
set -e
assert_contains "--lang=en 强制覆盖 → 检测到主语言: en" "检测到主语言: en" "$out_force"

# ── 4. 临时 fixture：混排（zh 占 ~70%）→ zh ──
TMPDIR=$(make_tmpdir)
cat > "$TMPDIR/mixed70-zh.md" <<'EOF'
# 混排
这是一段中文文字这是一段中文文字这是一段中文文字这是一段中文文字这是一段中文文字。This is English.
EOF
set +e
out_mixed=$(bash "$SCRIPT" "$TMPDIR/mixed70-zh.md" 2>&1)
set -e
assert_contains "mixed 70% zh → zh" "检测到主语言: zh" "$out_mixed"

# ── 5. 临时 fixture：混排（en 占 ~70%）→ en ──
cat > "$TMPDIR/mixed70-en.md" <<'EOF'
# Mixed content
This is mostly English content used for testing the language detection.
Here is one short Chinese sentence: 你好世界。
EOF
set +e
out_mixed2=$(bash "$SCRIPT" "$TMPDIR/mixed70-en.md" 2>&1)
set -e
assert_contains "mixed 70% en → en" "检测到主语言: en" "$out_mixed2"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-lang"
