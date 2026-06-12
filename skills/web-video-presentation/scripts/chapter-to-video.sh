#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# chapter-to-video.sh —— 书籍章节 → 可录屏视频演示的一键入口
#
# 用法：
#   bash scripts/chapter-to-video.sh <chapter.{md,txt}> [选项]
#   cat chapter.md | bash scripts/chapter-to-video.sh - [选项]
#
# 选项：
#   --theme=<id>          主题 id（默认 kraft-paper）
#   --out=<dir>           输出根目录（默认 my-video/）
#   --lang=<zh|en>        强制主语言
#   --title=<name>        视频标题
#   --episodes=<n>        强制拆 n 集
#   --provider=<id>       TTS provider（默认 minimax）
#   --no-audio            跳过音频合成提示
#   --no-images           跳过图片生成提示
#   --no-record           跳过录屏
#   --test                测试模式：跳过 audio + record，只跑视觉
#   --image-provider=<id> 图片 provider（默认 minimax；可换 openai / stability / 自定义）
#
# 细粒度 brief 维度（任一可覆盖 profile）：
#   --theme=<id>         主题（如 kraft-paper / paper-press / bauhaus-bold）
#   --voice=<name>        TTS 音色（沉稳男声 / 温柔女声 / 明亮童声）
#   --pace=<spec>         节奏（极慢 / 慢 / 标准 / 250 字/分）
#   --bgm=<spec>          背景音乐（古琴 / 钢琴 / 流行 / lo-fi）
#   --visual=<spec>       视觉风格（书法 + 留白 / 水彩 / 插画 / 卡通）
#   --禁忌=<spec>         禁忌（不现代化 / 不说教 / 不比较 ...）
#   --continue [target]   接着跑 test 模式跳过的 audio + record
#   --resume              跳过已存在的步骤
#   --list-themes         列出可用主题
#   -h, --help            帮助
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── 子命令路由：status / selftest / pipeline（必须在 arg 解析之前）──
if [[ "${1:-}" =~ ^(status|selftest|pipeline)$ ]]; then
  SUBCMD="$1"; shift
  SUBCMD_FILE="$SKILL_DIR/scripts/commands/$SUBCMD.sh"
  if [[ -f "$SUBCMD_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SUBCMD_FILE"
    if declare -f "cmd_$SUBCMD" >/dev/null; then
      cmd_"$SUBCMD" "$@"
      exit $?
    else
      echo "✗ 子命令 $SUBCMD 已注册但 cmd_$SUBCMD 未实现" >&2
      exit 1
    fi
  else
    echo "✗ 未知子命令: $SUBCMD (status / selftest / pipeline)" >&2
    exit 1
  fi
fi

TEMPLATES="$SKILL_DIR/templates"
THEMES_DIR="$SKILL_DIR/themes"
REFERENCES="$SKILL_DIR/references"

# ── 默认值 ──
THEME="kraft-paper"
OUT="my-video"
LANG=""
TITLE=""
EPISODES=""
PROVIDER="minimax"
AUDIO=1
RESUME=0
INPUT=""
IMG_PROVIDER="minimax"
PROFILE=""
IMAGES=1
TEST_MODE=0
RECORD=1
# 用户可覆盖的 5 个 brief 维度（默认值）
BRIEF_AUDIENCE=""     # 默认从 --audience 推
BRIEF_THEME=""
BRIEF_VOICE=""
BRIEF_PACE=""
BRIEF_BGM=""
BRIEF_VISUAL=""
BRIEF_TABOO=""
die() { echo "✗ $*" >&2; exit 1; }
log() { echo "▸ $*"; }
ok()  { echo "✓ $*"; }

list_themes() {
  echo "可用主题（$THEMES_DIR）："
  echo
  for dir in "$THEMES_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    local meta="$dir/theme.json"
    [[ -f "$meta" ]] || continue
    local id name desc
    id=$(grep -E "\"id\""        "$meta" | head -n1 | sed -E "s/.*\"id\":[[:space:]]*\"([^\"]+)\".*/\1/")
    name=$(grep -E "\"nameZh\""   "$meta" | head -n1 | sed -E "s/.*\"nameZh\":[[:space:]]*\"([^\"]+)\".*/\1/")
    desc=$(grep -E "\"descriptionZh\"" "$meta" | head -n1 | sed -E "s/.*\"descriptionZh\":[[:space:]]*\"([^\"]+)\".*/\1/")
    printf "  • %-22s %s\n      %s\n\n" "$id" "$name" "$desc"
  done
  echo "默认：$THEME（文学气质）。"
}



usage() {
  sed -n '2,32p' "$0" | sed -E 's/^# ?//'
  exit 0
}

# ── 解析参数（完整版）──
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)            usage ;;
    --resume)             RESUME=1 ;;
    --list-themes)        list_themes; exit 0 ;;
    --out=*)              OUT="${1#--out=}" ;;
    --lang=*)             LANG="${1#--lang=}" ;;
    --title=*)            TITLE="${1#--title=}" ;;
    --episodes=*)         EPISODES="${1#--episodes=}" ;;
    --provider=*)         PROVIDER="${1#--provider=}" ;;
    --no-audio)           AUDIO=0 ;;
    --no-images)          IMAGES=0 ;;
    --no-record)          RECORD=0 ;;
    --test)                TEST_MODE=1; AUDIO=0; RECORD=0 ;;
    --image-provider=*)   IMG_PROVIDER="${1#--image-provider=}" ;;
    --profile=*)          PROFILE="${1#--profile=}" ;;
    --profile)            shift; PROFILE="$1" ;;
    --theme=*)            THEME="${1#--theme=}"; BRIEF_THEME="${1#--theme=}" ;;
    --theme)              shift; THEME="$1"; BRIEF_THEME="$1" ;;
    --voice=*)            BRIEF_VOICE="${1#--voice=}" ;;
    --voice)              shift; BRIEF_VOICE="$1" ;;
    --pace=*)             BRIEF_PACE="${1#--pace=}" ;;
    --pace)               shift; BRIEF_PACE="$1" ;;
    --bgm=*)              BRIEF_BGM="${1#--bgm=}" ;;
    --bgm)                shift; BRIEF_BGM="$1" ;;
    --visual=*)           BRIEF_VISUAL="${1#--visual=}" ;;
    --visual)             shift; BRIEF_VISUAL="$1" ;;
    --禁忌=*)             BRIEF_TABOO="${1#--禁忌=}" ;;
    --禁忌)               shift; BRIEF_TABOO="$1" ;;
    -)                    INPUT="-" ;;
    -*)                   die "未知参数: $1" ;;
    *)                    [[ -z "$INPUT" ]] && INPUT="$1" || die "只能指定一个输入文件" ;;
  esac
  shift
done

# ── 验证输入存在（必须在 while 循环之后做，因为允许 -）──
[[ -n "$INPUT" ]] || die "必须指定输入文件或 '-' (stdin)。跑 --help 看用法。"

# ── 验证主题 ──
THEME_DIR="$THEMES_DIR/$THEME"
[[ -d "$THEME_DIR" ]] || die "主题不存在: $THEME（跑 --list-themes 看全部）"
[[ -f "$THEME_DIR/tokens.css" ]] || die "主题 $THEME 缺 tokens.css"

# ── 读取输入：stdin 落盘到临时文件，文件路径直接用 ──
TMP_ARTICLE=""
if [[ "$INPUT" = "-" ]]; then
  TMP_ARTICLE="$(mktemp -t chapter-XXXXXX.md)"
  cat > "$TMP_ARTICLE"
  trap 'rm -f "$TMP_ARTICLE"' EXIT
  INPUT="$TMP_ARTICLE"
elif [[ ! -f "$INPUT" ]]; then
  die "找不到文件: $INPUT"
fi

# ── 验证前置依赖 ──
command -v node >/dev/null || die "需要 node（>=18），但 PATH 里没找到"
command -v npm  >/dev/null || die "需要 npm，但 PATH 里没找到"
NODE_MAJOR=$(node -v | sed -E "s/v([0-9]+).*/\1/")
[[ "$NODE_MAJOR" -lt 18 ]] && die "node 版本太低：$(node -v)，需要 >= 18"

# ── 启发式语言检测（python 做 CJK 字符统计，跨平台可靠）──
if [[ -z "$LANG" ]]; then
  LANG=$(python3 - "$INPUT" <<'PY'
import re, sys
with open(sys.argv[1], encoding="utf-8") as f:
    s = f.read()
cjk = len(re.findall(r"[㐀-鿿]", s))
total = len(s)
print("zh" if total > 0 and cjk * 100 // total > 30 else "en")
PY
)
fi
log "检测到主语言: $LANG"

# ── 字数 + 估时 ──
read WORDS RATE UNIT < <(python3 - "$INPUT" "$LANG" <<'PY'
import re, sys
path, lang = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    s = f.read()
if lang == "zh":
    n = len(re.findall(r"[㐀-鿿]", s))
    print(f"{n} 200 字")
else:
    n = len(re.findall(r"[A-Za-z]+", s))
    print(f"{n} 130 词")
PY
)
read WORDS _ _ < <(echo "$WORDS $RATE $UNIT")
EST_MIN=$(( (WORDS + RATE - 1) / RATE ))
log "字数 ~$WORDS  /  估时 ~$EST_MIN 分钟（$RATE $UNIT/分）"

# ── 拆集决策（按 BOOK-CHAPTER.md §1.2 表）──
if [[ -z "$EPISODES" ]]; then
  if [[ $EST_MIN -le 15 ]]; then
    EPISODES=1
  elif [[ $EST_MIN -le 25 ]]; then
    log "⚠ 估时 $EST_MIN 分钟 偏长。考虑 --episodes=2 拆集（详见 BOOK-CHAPTER.md §1.2）"
    EPISODES=1
  else
    log "⚠ 估时 $EST_MIN 分钟过长。**强烈建议 --episodes=2 或 3**。"
    EPISODES=1
  fi
fi
log "集数: $EPISODES"

# ── 准备输出目录 ──
if [[ -d "$OUT" && "$RESUME" -eq 0 ]]; then
  die "目标目录 '$OUT' 已存在。换个名字 / --out=<新路径>，或加 --resume 复用"
fi
mkdir -p "$OUT"

# ── 落盘 article.md（始终覆盖，保证 input 是真相源）──
cp "$INPUT" "$OUT/article.md"
log "落盘 article.md"

# ── 复制特化规则到项目里（提醒 agent 走特化支路）──
if [[ ! -f "$REFERENCES/BOOK-CHAPTER.md" ]]; then
  log "⚠ references/BOOK-CHAPTER.md 不存在，agent 将无法读特化规则（见 SKILL.md 改动）"
else
  cp "$REFERENCES/BOOK-CHAPTER.md"  "$OUT/BOOK-CHAPTER.md" 2>/dev/null || log "⚠ copy BOOK-CHAPTER.md failed"
fi
cp "$REFERENCES/SCRIPT-STYLE.md"   "$OUT/SCRIPT-STYLE.md"
cp "$REFERENCES/OUTLINE-FORMAT.md"  "$OUT/OUTLINE-FORMAT.md"
cp "$REFERENCES/CHAPTER-CRAFT.md"   "$OUT/CHAPTER-CRAFT.md"
log "复制 reference docs 到 $OUT/（agent 必读）"

# ── 取标题 ──
if [[ -z "$TITLE" ]]; then
  TITLE=$(grep -m1 -E "^#\s+" "$INPUT" | sed -E "s/^#\s+//" | head -c 60)
  [[ -z "$TITLE" ]] && TITLE="$(basename "${INPUT%.*}")"
fi
# ── 写 brief.md（profile + flag 覆盖合成）──
BRIEF_STR=""
[[ -n "$BRIEF_THEME"  ]] && BRIEF_STR="$BRIEF_STR theme=$BRIEF_THEME"
[[ -n "$BRIEF_VOICE"  ]] && BRIEF_STR="$BRIEF_STR voice=$BRIEF_VOICE"
[[ -n "$BRIEF_PACE"   ]] && BRIEF_STR="$BRIEF_STR pace=$BRIEF_PACE"
[[ -n "$BRIEF_BGM"    ]] && BRIEF_STR="$BRIEF_STR bgm=$BRIEF_BGM"
[[ -n "$BRIEF_VISUAL" ]] && BRIEF_STR="$BRIEF_STR visual=$BRIEF_VISUAL"
[[ -n "$BRIEF_TABOO"  ]] && BRIEF_STR="$BRIEF_STR 禁忌=$BRIEF_TABOO"
BRIEF_STR="${BRIEF_STR#"${BRIEF_STR%%[![:space:]]*}"}"
source "$SKILL_DIR/scripts/commands/profile.sh"
source "$SKILL_DIR/scripts/commands/brief.sh"
# shellcheck disable=SC2086
IFS=" " cmd_brief_write "$OUT" "$PROFILE" $BRIEF_STR
log "写 brief.md（profile + flag 覆盖）"

# ── 写 STATE.md（自动跟踪进度，每次 init 覆盖）──
cat > "$OUT/STATE.md" <<EOF
# State · $TITLE

> 自动生成 by chapter-to-video.sh — 不要手改，下次 init 会覆盖

## 当前阶段
- [x] Phase 0 · init（chapter-to-video.sh init）
- [ ] Phase 1 · 内容（script.md + outline.md）
- [ ] Phase 2 · 网页（章节实现）
- [ ] Phase 3 · 音频 + 图片
- [ ] Phase 4 · 录屏

## 配置快照
- 主题：$THEME
- 语言：$LANG
- 估时：~$EST_MIN 分钟
- 集数：$EPISODES
- TTS provider：$PROVIDER
- 图片 provider：$IMG_PROVIDER

## 下一步
1. 在 Cursor 里输入 /chapter-to-video 让 agent 读 BOOK-CHAPTER.md
2. 调 agent 生成 script.md 和 outline.md
3. 跑 \`chapter-to-video.sh selftest my-video\` 验 5 层
4. 调 agent 实现第 1 章
5. 跑 \`chapter-to-video.sh pipeline my-video\` 一键生成音频+图片
6. 浏览器开 http://localhost:5173/?auto=1 + 录屏

更新于：$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
log "写 STATE.md（自动跟踪进度）"


# ── 写 meta.json ──
python3 - "$OUT/meta.json" "$TITLE" "$THEME" "$LANG" "$PROVIDER" "$AUDIO" "$EPISODES" "$WORDS" "$EST_MIN" "$RATE" "$UNIT" "$IMAGES" "$IMG_PROVIDER" <<'PY'
import json, sys
path, title, theme, lang, provider, audio, eps, words, est_min, rate, unit, images, image_provider = sys.argv[1:14]
data = {
    "title":          title,
    "theme":          theme,
    "lang":           lang,
    "provider":       provider,
    "audio":          bool(int(audio)),
    "images":         bool(int(images)),
    "image_provider": image_provider,
    "episodes":       int(eps),
    "words":          int(words),
    "est_min":        int(est_min),
    "rate":           int(rate),
    "unit":           unit,
    "article":        "article.md",
    "created":        __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
log "写 meta.json（agent 和 CI 会读）"

# ── 写 state.json ──
python3 - "$OUT/.book-video/state.json" "$TEST_MODE" "$AUDIO" "$IMAGES" "$RECORD" "$EPISODES" <<'PY'
import json, sys
path, test_mode, audio, images, record, episodes = sys.argv[1:7]
data = {
    "phase":         "P0",
    "phase_status":   "done",
    "mode":           "test" if int(test_mode) else "full",
    "test":           bool(int(test_mode)),
    "audio":          bool(int(audio)),
    "images":         bool(int(images)),
    "record":         bool(int(record)),
    "episodes":       int(episodes),
    "next_action":    "让 agent 读 BOOK-CHAPTER.md 生成 script.md",
    "created":        __import__("datetime").datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
}
import os
os.makedirs(os.path.dirname(path), exist_ok=True)
open(path, "w").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
PY
log "写 state.json（机器可读）"


# ── 跑脚手架（除非 --resume 且 presentation/ 已存在）──
SCAFFOLD_CMD="${WVP_SCAFFOLD_SH:-$SKILL_DIR/scripts/scaffold.sh}"
if [[ -d "$OUT/presentation" && "$RESUME" -eq 1 && -f "$OUT/presentation/package.json" ]]; then
  log "presentation/ 已存在且 --resume，跳过脚手架"
else
  log "▸ 跑脚手架（主题: $THEME）"
  if ! bash "$SCAFFOLD_CMD" "$OUT/presentation" --theme="$THEME" 2>&1 | sed "s/^/    /"; then
    die "scaffold 失败：$SCAFFOLD_CMD"
  fi
fi

# ── 打印 next-step 提示（agent + user 各一段）──
cat <<EOF

════════════════════════════════════════════════════════════
  ✓ 准备完成
════════════════════════════════════════════════════════════

📁 $OUT/
  ├── .book-video/
  │   └── state.json      ← 机器可读状态（含 test 标记）
  ├── meta.json            ← 标题/主题/集数/估时
  ├── article.md           ← 你的章节
  ├── BOOK-CHAPTER.md      ← 章节特化规则（agent 必读）
  └── presentation/        ← Vite + React + TS 项目（主题: $THEME）

════════════════════════════════════════════════════════════
  给 agent 的指令（复制粘贴）
════════════════════════════════════════════════════════════

  请按 SKILL.md Phase 1.1 第三行（书籍章节支路）继续。
  输入:  $OUT/article.md
  规则:  $OUT/BOOK-CHAPTER.md
  主题:  $THEME（已选定）
  模式:  A 逐章确认

════════════════════════════════════════════════════════════
  音频（章节实现 + 自检通过后再做）
════════════════════════════════════════════════════════════

  cd $OUT/presentation
  npm run extract-narrations
  npm run synthesize-audio      # 默认 $PROVIDER provider
EOF

if [[ "$TEST_MODE" -eq 1 ]]; then
  cat <<EOF2

════════════════════════════════════════════════════════════
  test 模式提示
════════════════════════════════════════════════════════════

  你跳过了 audio + record。
  
  看完视觉后，跑这个补上：
    bash skills/web-video-presentation/scripts/chapter-to-video.sh continue $OUT
EOF2
fi

if [[ "$IMAGES" -eq 1 ]]; then
  cat <<EOF2

════════════════════════════════════════════════════════════
  图片（章节实现 + 自检通过后再做）
════════════════════════════════════════════════════════════

  npm run extract-images        # 扫所有章节 images.ts → image-prompts.json
  npm run synthesize-images     # 默认 $IMG_PROVIDER provider
                              # 换 provider：PRESENTATION_IMG=<name> npm run synthesize-images
                              # 加 provider：见 scripts/image-providers/README.md
EOF2
fi
exit 0

