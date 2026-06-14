#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# scaffold.sh —— 一键脚手架，创建一个 video-presentation 项目。
#
# 用法：
#   bash scripts/scaffold.sh <target-dir> [--theme=<id>]
#   bash scripts/scaffold.sh --list-themes
#
# 例子：
#   bash <path-to-web-video-presentation>/scripts/scaffold.sh ./presentation
#   bash <path-to-web-video-presentation>/scripts/scaffold.sh ./talk --theme=paper-press
#   bash <path-to-web-video-presentation>/scripts/scaffold.sh --list-themes
#
# 跑完后，看 SKILL.md "Phase 2.4 实现单章" + references/CHAPTER-CRAFT.md
# 了解每章怎么写。卡壳时翻 references/EXAMPLES/ 找完整章节 anchor。
#
# 之后切换主题，覆盖一个文件即可：
#   cp <path-to-web-video-presentation>/themes/<id>/tokens.css \
#      <project>/src/styles/tokens.css
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATES="$SKILL_DIR/templates"
THEMES_DIR="$SKILL_DIR/themes"
DEFAULT_THEME="midnight-press"

list_themes() {
  echo "可用主题（来自 ${THEMES_DIR}）:"
  echo
  for dir in "$THEMES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local meta="$dir/theme.json"
    [[ -f "$meta" ]] || continue
    # 没有 jq，简单 grep + sed 提字段
    local id name desc
    id=$(grep -E '"id"' "$meta" | head -n1 | sed -E 's/.*"id":[[:space:]]*"([^"]+)".*/\1/')
    name=$(grep -E '"nameZh"' "$meta" | head -n1 | sed -E 's/.*"nameZh":[[:space:]]*"([^"]+)".*/\1/')
    desc=$(grep -E '"descriptionZh"' "$meta" | head -n1 | sed -E 's/.*"descriptionZh":[[:space:]]*"([^"]+)".*/\1/')
    printf "  • %-18s %s\n      %s\n\n" "$id" "$name" "$desc"
  done
  echo "用 --theme=<id> 选定一个。默认：${DEFAULT_THEME}。"
}

# ── 解析参数 ──
TARGET=""
THEME="$DEFAULT_THEME"
CHAPTER_FLAG=0
for arg in "$@"; do
  case "$arg" in
    --list-themes)
      list_themes
      exit 0
      ;;
    --theme=*)
      THEME="${arg#--theme=}"
      ;;
    --chapter)               # 书籍章节项目：附带 BOOK-CHAPTER.md
      CHAPTER_FLAG=1
      ;;
    --*)
      echo "✗ 未知参数: $arg" >&2
      exit 1
      ;;
    *)
      if [[ -z "$TARGET" ]]; then TARGET="$arg"; fi
      ;;
  esac
done

TARGET="${TARGET:-presentation}"
THEME_DIR="$THEMES_DIR/$THEME"
THEME_TOKENS="$THEME_DIR/tokens.css"

if [[ ! -d "$THEME_DIR" || ! -f "$THEME_TOKENS" ]]; then
  echo "✗ 找不到主题 '${THEME}'。可用主题：" >&2
  echo >&2
  for dir in "$THEMES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    echo "    • $(basename "$dir")" >&2
  done
  exit 1
fi

if [[ -d "$TARGET" && -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]]; then
  echo "✗ 目标目录 '${TARGET}' 已存在且非空，已中止。" >&2
  exit 1
fi

if ! command -v npm >/dev/null; then
  echo "✗ 需要 npm，但在 PATH 里没找到。" >&2
  exit 1
fi

# ──────────────────────────────────────────────────────────────
# 双模式脚手架：vite/ + remotion/ + shared/ 三子目录布局
# ──────────────────────────────────────────────────────────────
echo "▸ 在 $TARGET 创建双模式项目（Vite 互动 + Remotion 出片 + shared 共享）"
echo "▸ 使用主题：$THEME"

mkdir -p "$TARGET"
cd "$TARGET"

# ── shared/ 共享层（章节代码 + 主题 token + 通用组件）──
mkdir -p shared/components shared/styles shared/chapters/01-example shared/assets

cp -R "$TEMPLATES/shared/components/."   shared/components/
cp -R "$TEMPLATES/shared/styles/."       shared/styles/
cp "$THEME_TOKENS"                       shared/styles/tokens.css
cp -R "$TEMPLATES/shared/chapters/01-example/." shared/chapters/01-example/

# ── vite/ 子项目（互动模式）──
mkdir -p vite/src/{hooks,components,registry,styles} vite/public
cp -R "$TEMPLATES/vite/." vite/
chmod +x vite/node_modules/.bin/* 2>/dev/null || true

# ── remotion/ 子项目（出片模式）──
mkdir -p remotion/src/{compositions,registry} remotion/public
cp -R "$TEMPLATES/remotion/." remotion/

# ── scripts/ 共享脚本（extract-narrations / synthesize / probe / render）──
mkdir -p scripts/tts-providers scripts/image-providers scripts/__tests__/fixtures
cp "$TEMPLATES/scripts/extract-narrations.ts"   scripts/extract-narrations.ts
cp "$TEMPLATES/scripts/extract-images.ts"       scripts/extract-images.ts
cp "$TEMPLATES/scripts/probe-audio-durations.ts" scripts/probe-audio-durations.ts
cp "$TEMPLATES/scripts/synthesize-audio.sh"     scripts/synthesize-audio.sh
cp "$TEMPLATES/scripts/synthesize-images.sh"    scripts/synthesize-images.sh
cp "$TEMPLATES/scripts/render-remotion.sh"      scripts/render-remotion.sh
# v1.4+ 新增：三档密度 + LLM 拆句 + minimax 真生
cp "$TEMPLATES/scripts/render-minimax.sh"       scripts/render-minimax.sh
cp "$TEMPLATES/scripts/split-narrations.ts"     scripts/split-narrations.ts
cp "$TEMPLATES/scripts/check-alignment.ts"      scripts/check-alignment.ts
cp "$TEMPLATES/scripts/check-alignment.README.md" scripts/check-alignment.README.md
# check-alignment 拆出的辅助模块
cp "$TEMPLATES/scripts/parser.ts"               scripts/parser.ts
cp "$TEMPLATES/scripts/parser-utils.ts"         scripts/parser-utils.ts
cp "$TEMPLATES/scripts/paths.ts"                scripts/paths.ts
chmod +x scripts/synthesize-audio.sh scripts/synthesize-images.sh scripts/render-remotion.sh scripts/render-minimax.sh

cp "$TEMPLATES/scripts/tts-providers/README.md"   scripts/tts-providers/README.md
cp "$TEMPLATES/scripts/tts-providers/minimax.sh"  scripts/tts-providers/minimax.sh
cp "$TEMPLATES/scripts/tts-providers/openai.sh"   scripts/tts-providers/openai.sh
cp "$TEMPLATES/scripts/image-providers/README.md" scripts/image-providers/README.md
cp "$TEMPLATES/scripts/image-providers/minimax.sh" scripts/image-providers/minimax.sh

# ── 顶层 package.json（壳，scripts 入口）──
cat > package.json <<'PKGJSON'
{
  "name": "video-presentation",
  "private": true,
  "type": "module",
  "version": "0.1.0",
  "scripts": {
    "dev": "cd vite && npm run dev",
    "build": "cd vite && npm run build",
    "preview": "cd vite && npm run preview",
    "render": "bash scripts/render-remotion.sh",
    "render:ep01": "cd remotion && npx remotion render Episode01 out/ep01.mp4",
    "render:minimax": "bash scripts/render-minimax.sh",
    "split-narrations": "tsx scripts/split-narrations.ts",
    "check-alignment": "tsx scripts/check-alignment.ts",
    "check-alignment:strict": "tsx scripts/check-alignment.ts --strict",
    "check-alignment:dry": "tsx scripts/check-alignment.ts --dry-run",
    "test": "vitest run",
    "test:check-alignment": "vitest run scripts/__tests__/check-alignment.test.ts",
    "extract": "tsx scripts/extract-narrations.ts",
    "extract:images": "tsx scripts/extract-images.ts",
    "probe": "tsx scripts/probe-audio-durations.ts",
    "synthesize": "bash scripts/synthesize-audio.sh",
    "synthesize-images": "bash scripts/synthesize-images.sh",
    "install:all": "(cd vite && npm install) && (cd remotion && npm install) && npm install -D tsx vitest",
    "typecheck": "cd vite && npm run typecheck"
  },
  "devDependencies": {
    "tsx": "^4.19.0",
    "vitest": "^2.1.0"
  }
}
PKGJSON

# ── 留个标记，记录这个项目从哪个主题起步 ──
printf '%s\n' "$THEME" > .theme

# ── 书籍章节项目：附带 BOOK-CHAPTER.md ──
if [[ "$CHAPTER_FLAG" -eq 1 ]]; then
  if [[ -f "$SKILL_DIR/references/BOOK-CHAPTER.md" ]]; then
    cp "$SKILL_DIR/references/BOOK-CHAPTER.md" BOOK-CHAPTER.md
    echo "▸ 已附带 BOOK-CHAPTER.md（书籍章节特化规则）"
  else
    echo "⚠ --chapter 但 references/BOOK-CHAPTER.md 不存在" >&2
  fi
fi

# ── 跑 typecheck 确认接线 OK（仅 vite 子项目——依赖没装时不跑）──
if [[ -d vite/node_modules ]]; then
  echo "▸ 跑 vite typecheck ..."
  if (cd vite && npx tsc --noEmit); then
    echo "✓ vite typecheck 通过"
  else
    echo "✗ vite typecheck 失败 —— 请看上面的错误" >&2
    exit 1
  fi
fi

cat <<EOF

✓ 完成。下一步：

  1. cd $TARGET
  2. npm run install:all    # 装 vite/ + remotion/ + tsx 依赖
  3. npm run dev            # 互动模式：http://localhost:5173

当前主题：${THEME}（见 .theme）

项目结构（双模式）：
  shared/     章节代码 + 主题 token + 通用组件（Vite/Remotion 共用）
  vite/       互动预览 —— 浏览器点击 / 方向键 / 自动播放
  remotion/   离线出片 —— npx remotion render → .mp4
  scripts/    共享脚本（extract / probe / synthesize / render）

工作流：
  1. 在 shared/chapters/<NN>-<id>/ 写章节（一份代码，两个渲染器都用）
  2. vite/src/registry/chapters.ts 注册新章节
  3. npm run dev 调样式 + 互动验收
  4. npm run synthesize 合成音频 → vite/public/audio/<id>/<N>.mp3
  5. npm run probe 自动算 durationInFrames 回写到 shared/chapters
  6. npm run render 出 .mp4（out/<episode>.mp4）

互动模式（保留原 Skill 全部能力）：
  • 点舞台任意位置推进全局 step 计数器
  • 鼠标移到底部边缘可显出进度条；右上角可显播放模式切换
  • 手动模式：http://localhost:5173
  • 半自动：URL 加 ?audio=1 — 音频跟 step 切，你手动推进
  • 全自动录屏：URL 加 ?auto=1 — 按一次 SPACE 启动，整片自动播
  • 录屏后用 QuickTime / OBS 录制浏览器窗口

出片模式（新增，绕过录屏）：
  • npm run render         # 渲染所有 Episode
  • npm run render:ep01    # 渲染指定集
  • 输出 out/<episode>.mp4，1920×1080 h264，30fps
  • macOS M 系列用 VideoToolbox 硬编，~5-15 分钟视频约 5-15 分钟渲染
  • v1.4+ 三档密度：--density=bilibili|wechat|douyin
  • v1.4+ 两种布局：--layout=stacked|split
  • 例子：npm run render -- --density=douyin --layout=split

真生视频（v1.4+ C 模式）：
  • npm run render:minimax -- --chapter-id=99-demo --max=3
  • 调 mmx-cli 真生（需 pip install minimax-cli + mmx 在 PATH）
  • 每段 10s，最多 3 段，输出 out/minimax/Episode01-bilibili-1.mp4
  • prompt 自动从 images.ts 抽 subject + composition + style + palette
  • 可在 shared/chapters/<id>/prompt-template.txt 写自定义模板

LLM 拆句（v1.4+）：
  • ANTHROPIC_API_KEY=sk-... npm run split-narrations -- \
      --input=script.md --output=shared/chapters/01-foo/narrations.ts --chapter=01-foo
  • 每 step 8-15 字 + 视觉锚点 hint（与 check-alignment HINT 校验对齐）

跨管道校验（v1.4+）：
  • npm run check-alignment         # I1~I4 + HINT 校验
  • npm run check-alignment:strict  # WARN 升级为 ERROR
  • npm run check-alignment -- --dry-run  # 报错但不 exit 1

音频合成：
  npm run extract          # 扫 shared/chapters → audio-segments.json
  npm run synthesize       # 默认 minimax provider 合成
  PRESENTATION_TTS=openai npm run synthesize
  # 自定义 / 没装 mmx 见 scripts/tts-providers/README.md

写章节时必读（单一入口，路径在 SKILL 仓库内）：
  • $SKILL_DIR/references/CHAPTER-CRAFT.md
      Part 0 十条原则 / Part 1 开工 5 问 / Part 2 关系→动作决策树 /
      Part 3 视觉工具箱 / Part 4 时长 / Part 5 反 AI 味反模式 /
      Part 6 代码硬规则 / Part 7 完工自检 / Part 8 反馈速查
  • $SKILL_DIR/themes/$THEME/theme.json
      看 descriptionZh / mood / bestFor —— 参考主题气质
  • $SKILL_DIR/references/REMOTION-MAPPING.md  ← 新增：共享层 .tsx 写法约束

切换主题（覆盖 shared/styles/tokens.css 即可）：
  cp $SKILL_DIR/themes/<id>/tokens.css shared/styles/tokens.css

EOF

# 书籍章节模式额外提示
if [[ "$CHAPTER_FLAG" -eq 1 ]]; then
  cat <<EOF
书籍章节模式额外提示：
  • 删除演示骨架前**先读** BOOK-CHAPTER.md
  • 估时 > 25 分钟时考虑拆集（见 BOOK-CHAPTER.md §1.2）
  • outline 必填：场景卡 + 摘句池
  • 自检 5 层（SCRIPT-STYLE 4 层 + BOOK-CHAPTER §8 第 5 层）
  • 拆集后：remotion/src/compositions/Episode01.tsx 用 .slice() 切 chapters

EOF
fi
