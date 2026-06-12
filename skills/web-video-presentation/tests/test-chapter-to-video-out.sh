#!/usr/bin/env bash
# T8: 文件落盘（article.md / refs / meta.json / 假 scaffold）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

TMPDIR=$(make_tmpdir)
OUT="$TMPDIR/my-video"

# 假 scaffold（避免 npm install）
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'STUB_EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"
mkdir -p "$TARGET"
echo '{}' > "$TARGET/package.json"
exit 0
STUB_EOF
chmod +x "$SCAFFOLD_STUB"

# ── 文件落盘 ──
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT" 2>&1
rc=$?
set -e

assert_file_exists "article.md 落盘"             "$OUT/article.md"
assert_file_exists "BOOK-CHAPTER.md 落盘"        "$OUT/BOOK-CHAPTER.md"
assert_file_exists "SCRIPT-STYLE.md 落盘"        "$OUT/SCRIPT-STYLE.md"
assert_file_exists "OUTLINE-FORMAT.md 落盘"      "$OUT/OUTLINE-FORMAT.md"
assert_file_exists "CHAPTER-CRAFT.md 落盘"       "$OUT/CHAPTER-CRAFT.md"
assert_file_exists "meta.json 落盘"              "$OUT/meta.json"

# meta.json 内容
if [[ -f "$OUT/meta.json" ]]; then
  assert_contains "meta.json: title"    "\"title\""    "$(cat "$OUT/meta.json")"
  assert_contains "meta.json: theme"    "\"kraft-paper\"" "$(cat "$OUT/meta.json")"
  assert_contains "meta.json: lang"     "\"zh\""       "$(cat "$OUT/meta.json")"
  # 新字段（T15 之后）
  assert_contains "meta.json: image_provider" "\"image_provider\"" "$(cat "$OUT/meta.json")"
  assert_contains "meta.json: images"   "\"images\""   "$(cat "$OUT/meta.json")"
fi

# ── --resume 在目录已存在时不应该重置 ──
mkdir -p "$OUT"
echo "fake" > "$OUT/article.md"
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT" --resume 2>&1
rc=$?
set -e
assert_file_exists "resume: article.md 仍存在" "$OUT/article.md"

# ── 不存在目录时不能加 --resume（会撞"目录已存在"检查的逻辑）──
# 故意跳过：--resume 与不存在的目录有特定语义，不在本测试覆盖

# ── 默认目录（不传 --out）──
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" 2>&1
rc=$?
set -e
# 默认 out 是 my-video/，会撞前面测试残留 → 我们只断言 article.md 在 cwd 下能找到或没冲突
# 简单点：清理 + 重跑
rm -rf my-video
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" 2>&1
rc=$?
set -e
assert_dir_exists "默认 out: my-video/ 创建" "my-video"
rm -rf my-video

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-out"
