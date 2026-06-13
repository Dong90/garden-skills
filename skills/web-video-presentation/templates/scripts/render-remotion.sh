#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# render-remotion.sh —— 调 Remotion 渲染 .mp4。
#
# 用法：
#   bash scripts/render-remotion.sh              # 渲染所有 Composition
#   bash scripts/render-remotion.sh Episode01    # 渲染指定 Composition
#   bash scripts/render-remotion.sh --dry        # 列出 Composition 不渲染
#
# 前置：跑过 `npm run probe` 让 shared/chapters 里的 durationInFrames 有值；
#       没跑过会 warn 但不阻塞（用兜底 90 帧/3s）。
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTION_DIR="$PROJECT_DIR/remotion"
OUT_DIR="$PROJECT_DIR/out"

# ── 检查 ──
if [[ ! -d "$REMOTION_DIR" ]]; then
  echo "✗ 找不到 remotion/ 子项目。在项目根目录跑本脚本。" >&2
  exit 1
fi
if ! command -v ffmpeg >/dev/null; then
  echo "✗ ffmpeg 不在 PATH。Remotion 渲染需要它。" >&2
  exit 1
fi
if ! command -v ffprobe >/dev/null; then
  echo "✗ ffprobe 不在 PATH。" >&2
  exit 1
fi

# ── 探测合成 ──
NARRATION_FILES=$(find "$PROJECT_DIR/shared/chapters" -name "narrations.ts" 2>/dev/null || true)
NEEDS_PROBE=0
for f in $NARRATION_FILES; do
  if grep -q "durationInFrames: 0" "$f" 2>/dev/null; then
    NEEDS_PROBE=1
    break
  fi
done
if [[ "$NEEDS_PROBE" -eq 1 ]]; then
  echo "⚠ 检测到未注入的 durationInFrames（值=0）。建议先跑：npm run probe"
  echo "  当前用兜底值（90 帧/3s）继续渲染。"
fi

# ── 依赖 ──
if [[ ! -d "$REMOTION_DIR/node_modules/@remotion/cli" ]]; then
  echo "▸ 装 Remotion 依赖..."
  (cd "$REMOTION_DIR" && npm install) || {
    echo "✗ npm install 失败" >&2
    exit 1
  }
fi

# ── 公共音频资源同步到 remotion/public/（Remotion 走 staticFile）──
# rsync --delete 删 stale；rsync 不可用时退化到 find + cp（但失去 delete 能力，需手动管理）
sync_audio() {
  local src="$1"
  [[ -d "$src" ]] || return 0
  # 源目录存在但无 mp3 → 不报错但提示
  if ! find "$src" -maxdepth 2 -name "*.mp3" -print -quit 2>/dev/null | grep -q .; then
    echo "  ⚠ 源目录为空（无 mp3）: $src"
    return 0
  fi
  if command -v rsync >/dev/null 2>&1; then
    if ! rsync -a --delete "$src/" "$REMOTION_DIR/public/audio/" 2>&1 | sed 's/^/    rsync: /'; then
      echo "  ✗ rsync 同步失败：$src" >&2
      return 1
    fi
  else
    # cp fallback 不删 stale 文件——提醒用户
    find "$REMOTION_DIR/public/audio" -name "*.mp3" -delete 2>/dev/null || true
    if ! cp -R "$src"/. "$REMOTION_DIR/public/audio/" 2>&1 | sed 's/^/    cp: /'; then
      echo "  ✗ cp 同步失败：$src" >&2
      return 1
    fi
    echo "  ⚠ rsync 未装，用 cp fallback——stale 文件已手动清理"
  fi
}

mkdir -p "$REMOTION_DIR/public/audio"
sync_audio "$PROJECT_DIR/shared/assets/audio"
sync_audio "$PROJECT_DIR/vite/public/audio"

mkdir -p "$OUT_DIR"

cd "$REMOTION_DIR"

if [[ "${1:-}" == "--dry" ]]; then
  echo "▸ 注册的 Composition："
  npx remotion compositions
  exit 0
fi

render_one() {
  local comp="$1"
  echo "▸ 渲染 $comp ..."
  npx remotion render "$comp" "$OUT_DIR/$comp.mp4" \
    --concurrency=4 \
    --codec=h264 \
    --crf=18 \
    --overwrite
}

if [[ $# -eq 0 ]]; then
  echo "▸ 渲染所有 Composition..."
  COMPOSITIONS=$(npx remotion compositions 2>/dev/null | tail -n +2 | awk '{print $1}')
  if [[ -z "$COMPOSITIONS" ]]; then
    echo "✗ 找不到任何 Composition" >&2
    exit 1
  fi
  for comp in $COMPOSITIONS; do
    render_one "$comp"
  done
else
  for comp in "$@"; do
    render_one "$comp"
  done
fi

echo
echo "✓ 完成。输出目录：$OUT_DIR"
ls -lh "$OUT_DIR"
