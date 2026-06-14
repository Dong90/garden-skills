#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# render-minimax.sh —— 调 mmx-cli 生成视频（第三种出片模式）
#
# 用法：
#   bash scripts/render-minimax.sh --episode=Episode01 --density=bilibili
#   bash scripts/render-minimax.sh --max=1                            # 只出 1 段
#   bash scripts/render-minimax.sh --max=2 --dry                      # 看 prompt 不调 API
#
# 每段 10s，最多 3 段（成本控制）。输出到 out/minimax/。
#
# prompt 来源：自动从 shared/chapters/<id>/images.ts 的 subject 字段拼成
# （3 段取 images[0..2] 的 subject，不够则取现有的并补 generic 描述）
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DENSITY="bilibili"
EPISODE="Episode01"
CHAPTER_ID=""  # 显式传章节 id（不传则从 EPISODE 推）
MAX=3
DRY_RUN=0
PROMPT_FILE=""

for arg in "$@"; do
  case "$arg" in
    --density=*)    DENSITY="${arg#--density=}" ;;
    --episode=*)    EPISODE="${arg#--episode=}" ;;
    --chapter-id=*) CHAPTER_ID="${arg#--chapter-id=}" ;;
    --max=*)        MAX="${arg#--max=}" ;;
    --dry)          DRY_RUN=1 ;;
    --prompt-file=*) PROMPT_FILE="${arg#--prompt-file=}" ;;
    --*)            echo "✗ 未知参数: $arg" >&2; exit 1 ;;
  esac
done

# ── 校验段数上限（最先做，参数错早返回） ──
if (( MAX < 1 || MAX > 3 )); then
  echo "✗ --max 必须在 1-3 之间（minimax 成本控制）" >&2
  exit 1
fi

# ── 解析 chapter id ──
REGISTRY="$PROJECT_DIR/vite/src/registry/chapters.ts"
if [[ ! -f "$REGISTRY" ]]; then
  REGISTRY="$PROJECT_DIR/src/registry/chapters.ts"
fi
if [[ ! -f "$REGISTRY" ]]; then
  echo "✗ 找不到 registry/chapters.ts（在 vite/src/ 或 src/src/ 下）" >&2
  exit 1
fi

if [[ -z "$CHAPTER_ID" ]]; then
  # 兜底：没传 chapter-id 时，从 EPISODE 推（如 Episode01 → 01-xxx），
  # 在 registry 里找以 "01-" 开头的 id。
  EPISODE_NUM="${EPISODE#Episode}"
  CHAPTER_ID=$(grep -E "id: \"${EPISODE_NUM}-" "$REGISTRY" | head -1 | sed -E 's/.*id: "([^"]+)".*/\1/')
  if [[ -z "$CHAPTER_ID" ]]; then
    echo "✗ registry 里找不到 id 以 ${EPISODE_NUM}- 开头的章节" >&2
    echo "  提示：用 --chapter-id=<id> 显式指定（如 --chapter-id=99-demo）" >&2
    exit 1
  fi
fi

CHAPTER_DIR="$PROJECT_DIR/shared/chapters/$CHAPTER_ID"
IMAGES_FILE="$CHAPTER_DIR/images.ts"

if [[ ! -f "$IMAGES_FILE" ]]; then
  echo "✗ 找不到 $IMAGES_FILE" >&2
  echo "  提示：minimax 模式从 images.ts 的 subject 字段拼 prompt，images.ts 必须存在" >&2
  exit 1
fi

# ── 从 images.ts 抽 spec，返回 subject|composition|style|palette（用 | 分隔避免和内容冲突）──
# 调 Node（项目已有 tsx 依赖）解析 TypeScript 字面量
# 兼容带/不带引号的 step + 跳过 export interface 块
extract_specs() {
  node -e '
    const fs = require("fs");
    let src = fs.readFileSync(process.argv[1], "utf-8");
    src = src.replace(/export\s+interface\s+\w+\s*\{[\s\S]*?^\}/gm, "");
    const get = (item, key) => {
      const m = item.match(new RegExp(`["\x27]?${key}["\x27]?\\s*:\\s*["\x27]?([^"\x27|\\n}]+)["\x27]?`));
      return m ? m[1].trim() : "";
    };
    const itemRe = /\{[\s\S]*?step\s*:\s*\d+\s*[,\n][\s\S]*?\}/g;
    let m, n = 0, max = parseInt(process.argv[2] || "3", 10);
    while ((m = itemRe.exec(src)) !== null && n < max) {
      const subject = get(m[0], "subject");
      const composition = get(m[0], "composition");
      const style = get(m[0], "style");
      const palette = get(m[0], "palette");
      if (subject) { console.log([subject, composition, style, palette].join("|")); n++; }
    }
  ' "$IMAGES_FILE" "$MAX"
}

# ── 通用 prompt 模板系统 ────────────────────────────────────────
#
# 模板来源优先级：
#   1. shared/chapters/<id>/prompt-template.txt  ← chapter 自定义
#   2. DEFAULT_PROMPT_TEMPLATE（下方）          ← 内置兜底
#
# 占位符：
#   {camera}     摄影机运动（默认 medium）
#   {lighting}   光影（默认 soft natural）
#   {style}      视觉风格纹理（默认 cinematic）
#   {sound}      声音氛围（默认 quiet ambient）
#   {pace}       节奏（自动从 DENSITY 推：bilibili=slow / wechat=medium / douyin=fast）
#   {subject}    从 images.ts 抽的主体描述
#   {composition}  从 images.ts 抽的构图描述（可空）

DEFAULT_PROMPT_TEMPLATE='cinematic 10s video, {camera} shot, {lighting} lighting, {style} visual texture, {sound} sound, {subject} {composition}. Pace: {pace}.'

# 密度 → 节奏映射（跟 8-15 字/句的口播速度一致；macOS bash 3.2 不支持 declare -A）
PACE_BILIBILI="slow"
PACE_WECHAT="medium"
PACE_DOUYIN="fast"
PACE_VAR="PACE_$(echo "$DENSITY" | tr a-z A-Z)"
PACE="${!PACE_VAR:-medium}"

# 选模板：chapter 自定义优先
CHAPTER_TEMPLATE="$CHAPTER_DIR/prompt-template.txt"
if [[ -f "$CHAPTER_TEMPLATE" ]]; then
  PROMPT_TEMPLATE=$(cat "$CHAPTER_TEMPLATE")
else
  PROMPT_TEMPLATE="$DEFAULT_PROMPT_TEMPLATE"
fi

# 占位符替换（用 sed 简单替换；占位符值若含特殊字符会被 sed 解读，所以先做变量再传）
apply_template() {
  local subject="$1"
  local composition="$2"
  local camera="${CAMERA:-medium}"
  local lighting="${LIGHTING:-soft natural}"
  local style="${STYLE_TEXTURE:-cinematic}"
  local sound="${SOUND:-quiet ambient}"
  local result="$PROMPT_TEMPLATE"
  result="${result//\{camera\}/$camera}"
  result="${result//\{lighting\}/$lighting}"
  result="${result//\{style\}/$style}"
  result="${result//\{sound\}/$sound}"
  result="${result//\{subject\}/$subject}"
  result="${result//\{composition\}/$composition}"
  result="${result//\{pace\}/$PACE}"
  echo "$result"
}

# mapfile 在 macOS 默认 bash 3.2 没有；用 while-read 兼容
# ── 从 images.ts 抽 specs（每行 subject|composition|style|palette）──
SPECS=()
while IFS= read -r line; do
  SPECS+=("$line")
done < <(extract_specs)

# 抽出 N 个（不够用 generic 补），每行转成完整 prompt
PROMPTS=()
if (( ${#SPECS[@]} > 0 )); then
  for spec in "${SPECS[@]}"; do
    IFS='|' read -r subject composition style palette <<< "$spec"
    # 优先用 images.ts 里的 style/palette（覆盖模板默认）
    if [[ -n "$style" ]]; then STYLE_TEXTURE="$style"; fi
    if [[ -n "$palette" ]]; then LIGHTING="$palette"; fi
    PROMPTS+=("$(apply_template "$subject" "$composition")")
  done
fi

# 如果 images.ts 里的 subject 不足 MAX 个，用 generic 描述补
while (( ${#PROMPTS[@]} < MAX )); do
  PROMPTS+=("$(apply_template 'a continuing visual scene' 'extending the story')")
done

# ── 校验 mmx-cli ──
if [[ "$DRY_RUN" != "1" ]] && ! command -v mmx >/dev/null 2>&1; then
  echo "✗ mmx-cli 不在 PATH" >&2
  echo "  安装: pip install minimax-cli（详见 minimax.sh provider 文档）" >&2
  exit 1
fi

# ── 输出目录 ──
OUT_DIR="$PROJECT_DIR/out/minimax"
mkdir -p "$OUT_DIR"

# ── 主循环：每段 1 次 mmx 调用 ──
echo "▸ episode=$EPISODE density=$DENSITY max=$MAX segment=10s"
echo "  chapter folder: $CHAPTER_ID"
echo

for ((i=0; i<MAX; i++)); do
  seg=$((i + 1))
  prompt="${PROMPTS[$i]}"
  out="$OUT_DIR/${EPISODE}-${DENSITY}-${seg}.mp4"
  echo "▸ 段 $seg/$MAX"
  echo "  prompt: $prompt"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "  (--dry 模式，跳过 mmx 调用)"
    echo
    continue
  fi

  start=$(date +%s)
  if mmx generate \
      --prompt="$prompt" \
      --duration=10s \
      --output="$out" 2>&1 | sed 's/^/    mmx: /'; then
    elapsed=$(( $(date +%s) - start ))
    if [[ -f "$out" ]]; then
      size=$(ls -lh "$out" | awk '{print $5}')
      printf "    ✓ %s · %s · %ss\n" "$(basename $out)" "$size" "$elapsed"
    else
      printf "    ⚠ mmx 返回成功但没找到输出文件\n"
    fi
  else
    echo "    ✗ mmx 失败" >&2
  fi
  echo
done

echo "✓ 完成 → $OUT_DIR"
ls -lh "$OUT_DIR" 2>/dev/null || true