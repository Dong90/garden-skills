#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# render-remotion.sh —— 调 Remotion 渲染 .mp4。
#
# 用法：
#   bash scripts/render-remotion.sh --density=bilibili   # 默认 B 站档
#   bash scripts/render-remotion.sh --density=wechat
#   bash scripts/render-remotion.sh --density=douyin
#   bash scripts/render-remotion.sh --dry                # 列出 Composition 不渲染
#   bash scripts/render-remotion.sh --episode=Episode02  # 只渲染指定集
#
# 前置：跑过 `npm run probe` 让 shared/chapters 里的 durationInFrames 有值；
#       没跑过会 warn 但不阻塞（用兜底 90 帧/3s）。
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REMOTION_DIR="$PROJECT_DIR/remotion"
OUT_DIR="$PROJECT_DIR/out"

# ── 解析参数 ──
DENSITY="bilibili"
LAYOUT="stacked"
EPISODE_FILTER=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --density=*)    DENSITY="${arg#--density=}" ;;
    --layout=*)     LAYOUT="${arg#--layout=}" ;;
    --episode=*)    EPISODE_FILTER="${arg#--episode=}" ;;
    --dry)          DRY_RUN=1 ;;
    --*)            echo "✗ 未知参数: $arg" >&2; exit 1 ;;
  esac
done

case "$DENSITY" in
  bilibili|wechat|douyin) ;;
  *) echo "✗ --density 必须是 bilibili / wechat / douyin 之一（收到: $DENSITY）" >&2; exit 1 ;;
esac

case "$LAYOUT" in
  stacked|split) ;;
  *) echo "✗ --layout 必须是 stacked / split 之一（收到: $LAYOUT）" >&2; exit 1 ;;
esac

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
sync_audio() {
  local src="$1"
  [[ -d "$src" ]] || return 0
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

if [[ "$DRY_RUN" == "1" ]]; then
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

# 按 density + layout + episode 过滤
COMPOSITIONS=$(npx remotion compositions 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -- "-${DENSITY}-${LAYOUT}$" || true)
if [[ -n "$EPISODE_FILTER" ]]; then
  COMPOSITIONS=$(echo "$COMPOSITIONS" | grep "^${EPISODE_FILTER}" || true)
fi

if [[ -z "$COMPOSITIONS" ]]; then
  echo "✗ 找不到任何匹配的 Composition（density=${DENSITY}, layout=${LAYOUT}${EPISODE_FILTER:+, episode=${EPISODE_FILTER}}）" >&2
  exit 1
fi

echo "▸ density=${DENSITY}, layout=${LAYOUT}，渲染：$(echo $COMPOSITIONS | tr '\n' ' ')"
for comp in $COMPOSITIONS; do
  render_one "$comp"
done

echo
echo "✓ 完成。输出目录：$OUT_DIR"
ls -lh "$OUT_DIR"