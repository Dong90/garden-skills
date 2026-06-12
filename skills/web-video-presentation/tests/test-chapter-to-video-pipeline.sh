#!/usr/bin/env bash
# T22: chapter-to-video.sh pipeline 子命令
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }
[[ -f "scripts/commands/pipeline.sh" ]] || { echo "  ✗ scripts/commands/pipeline.sh missing"; exit 1; }

# ── 1. 文件契约 ──
assert_file_exists "scripts/commands/pipeline.sh 存在" "scripts/commands/pipeline.sh"
assert_grep "pipeline.sh: 定义 cmd_pipeline" "^cmd_pipeline" "scripts/commands/pipeline.sh"

TMPDIR=$(make_tmpdir)

# 准备 fake presentation/
PROJ="$TMPDIR/my-video/presentation"
mkdir -p "$PROJ"
cat > "$PROJ/package.json" <<EOF
{
  "scripts": {
    "extract-narrations": "echo extract-narrations-stub",
    "synthesize-audio":   "echo synthesize-audio-stub",
    "extract-images":     "echo extract-images-stub",
    "synthesize-images":  "echo synthesize-images-stub"
  }
}
EOF

# fake npm
FAKE_BIN="$TMPDIR/fakebin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
echo "✓ $*" 
exit 0
EOF
chmod +x "$FAKE_BIN/npm"

# ── 2. dry-run 模式：列出 4 步 ──
set +e
PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/my-video" --dry-run 2>&1
rc=$?
set -e
assert_eq "pipeline --dry-run: exit 0" "0" "$rc"

set +e
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/my-video" --dry-run 2>&1)
set -e
assert_contains "pipeline --dry-run: 列出 extract-narrations" "extract-narrations" "$out"
assert_contains "pipeline --dry-run: 列出 synthesize-audio" "synthesize-audio" "$out"
assert_contains "pipeline --dry-run: 列出 extract-images" "extract-images" "$out"
assert_contains "pipeline --dry-run: 列出 synthesize-images" "synthesize-images" "$out"

# ── 3. skip 标志 ──
set +e
out_skip_audio=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/my-video" --skip-audio --dry-run 2>&1)
set -e
assert_not_contains "pipeline --skip-audio: 不跑 audio" "extract-narrations" "$out_skip_audio"
assert_not_contains "pipeline --skip-audio: 不跑 synthesize-audio" "synthesize-audio" "$out_skip_audio"
# 但 image 应该跑
assert_contains "pipeline --skip-audio: 仍跑 image" "extract-images" "$out_skip_audio"

set +e
out_skip_image=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/my-video" --skip-images --dry-run 2>&1)
set -e
assert_not_contains "pipeline --skip-images: 不跑 image" "extract-images" "$out_skip_image"
assert_contains "pipeline --skip-images: 仍跑 audio" "extract-narrations" "$out_skip_image"

# ── 4. 目录不存在时报错 ──
set +e
out_no=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/nonexistent" 2>&1)
rc_no=$?
set -e
assert_eq "pipeline: 目标不存在 → exit != 0" "1" "$rc_no"
assert_contains "pipeline: 报错'不存在'" "不存在" "$out_no"

# ── 5. package.json 缺失也报错 ──
NOPKG="$TMPDIR/nopkg/presentation"
mkdir -p "$NOPKG"
# 故意不写 package.json
set +e
out_nopkg=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/nopkg" --dry-run 2>&1)
rc_nopkg=$?
set -e
assert_eq "pipeline: package.json 缺失 → exit != 0" "1" "$rc_nopkg"

# ── 6. 真跑（用 fake npm 成功）──
set +e
out_real=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$TMPDIR/my-video" 2>&1)
rc_real=$?
set -e
assert_eq "pipeline 真跑: exit 0" "0" "$rc_real"
assert_contains "pipeline 真跑: 输出含'4/4'" "4/4" "$out_real" || assert_contains "pipeline 真跑: 完成提示" "完成" "$out_real"

# ── 7. 完成提示包含下一步 ──
assert_contains "pipeline: 提示跑 status" "status" "$out_real"
assert_contains "pipeline: 提示 npm run dev" "npm run dev" "$out_real"
assert_contains "pipeline: 提示 auto=1" "auto=1" "$out_real"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-pipeline"
