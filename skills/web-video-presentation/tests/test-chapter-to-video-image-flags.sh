#!/usr/bin/env bash
# T15: chapter-to-video.sh --image-provider / --no-images / meta.json 字段
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }

# ── 1. --help 应包含 --image-provider / --no-images ──
RUN_OUT=$(bash "$SCRIPT" --help 2>&1)
assert_contains "--help mentions --image-provider" "--image-provider" "$RUN_OUT"
assert_contains "--help mentions --no-images"      "--no-images"     "$RUN_OUT"

# ── 2. meta.json 包含 image_provider 字段（默认 minimax）──
TMPDIR=$(make_tmpdir)
IMG_PROVIDER_DEFAULT="minimax"
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'STUB_EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"
mkdir -p "$TARGET"
echo '{}' > "$TARGET/package.json"
exit 0
STUB_EOF
chmod +x "$SCAFFOLD_STUB"

set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$TMPDIR/out1" 2>&1
set -e
assert_file_exists "默认: meta.json 落盘" "$TMPDIR/out1/meta.json"
assert_contains "默认: image_provider=minimax" "\"image_provider\": \"minimax\"" "$(cat "$TMPDIR/out1/meta.json")"
assert_contains "默认: images=true"             "\"images\": true"             "$(cat "$TMPDIR/out1/meta.json")"

# ── 3. --image-provider=openai 覆盖默认 ──
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$TMPDIR/out2" --image-provider=openai 2>&1
set -e
assert_contains "--image-provider=openai: 写入 meta" "\"image_provider\": \"openai\"" "$(cat "$TMPDIR/out2/meta.json")"

# ── 4. --no-images: images=false，提示里不出现图片步骤 ──
set +e
out3=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$TMPDIR/out3" --no-images 2>&1)
set -e
assert_contains "--no-images: images=false" "\"images\": false" "$(cat "$TMPDIR/out3/meta.json")"
assert_not_contains "--no-images: 提示里不出现'图片'" "图片" "$out3"

# ── 5. 默认模式提示里出现图片（与音频并列）──
out_default=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$TMPDIR/out4" 2>&1)
assert_contains "默认模式: 提示含'图片'" "图片" "$out_default"
assert_contains "默认模式: 提示含'synthesize-images'" "synthesize-images" "$out_default"
assert_contains "默认模式: 提示含 provider 名 $IMG_PROVIDER_DEFAULT" "minimax" "$out_default"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-image-flags"
