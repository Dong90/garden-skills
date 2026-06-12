#!/usr/bin/env bash
# garden-furnace — Garden Skills 最常用炼炉：素材 → 精美文章 → 封面 → PDF
#
# 确定性步骤由本脚本跑；写作 / 排版 / 写 prompt 交给 Agent（见 tasks/*.md）。
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${GARDEN_OUTPUT_ROOT:-${ROOT_DIR}/garden-output}"
WORKFLOW="${GARDEN_FURNACE_WORKFLOW:-article}"

# ── skill 路径解析 ─────────────────────────────────────────────
resolve_skill() {
  local name="$1"
  local base p
  for base in \
    "${GARDEN_SKILLS_ROOT:-}" \
    "${HOME}/.agents/skills" \
    "${HOME}/.claude/skills" \
    "${HOME}/.codex/skills" \
    "/tmp/garden-skills-scan/skills"; do
    [[ -n "$base" ]] || continue
    p="${base%/}"
    if [[ -f "${p}/skills/${name}/SKILL.md" ]]; then
      echo "${p}/skills/${name}"
      return 0
    fi
    if [[ -f "${p}/${name}/SKILL.md" ]]; then
      echo "${p}/${name}"
      return 0
    fi
  done
  return 1
}

slug_dir() {
  echo "${OUTPUT_ROOT}/${1}"
}

state_file() {
  echo "$(slug_dir "$1")/STATE.json"
}

write_state() {
  local slug="$1"
  shift
  local dir sf
  dir="$(slug_dir "$slug")"
  sf="${dir}/STATE.json"
  mkdir -p "$dir"
  python3 - "$sf" "$slug" "$WORKFLOW" "$@" <<'PY'
import json, os, sys, datetime
path, slug, workflow = sys.argv[1:4]
updates = {}
for arg in sys.argv[4:]:
    if "=" in arg:
        k, v = arg.split("=", 1)
        updates[k] = v
data = {}
if os.path.isfile(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
data.update(updates)
data["slug"] = slug
data["workflow"] = workflow
data["updated_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY
}

usage() {
  cat <<'EOF'
Garden 炼炉 — 默认 workflow: article（素材 → 精美文章 → 封面 → PDF）

用法:
  ./scripts/garden-furnace.sh doctor
  ./scripts/garden-furnace.sh run <slug> --source <file.md|url.txt>
  ./scripts/garden-furnace.sh init <slug> --source <file>
  ./scripts/garden-furnace.sh scaffold <slug> [--theme=tufte]
  ./scripts/garden-furnace.sh task <slug>          # 生成 Agent 任务卡 tasks/*.md
  ./scripts/garden-furnace.sh cover <slug>       # Mode A 时按 prompt 出图
  ./scripts/garden-furnace.sh pdf <slug>           # article.html → PDF
  ./scripts/garden-furnace.sh status [slug]

环境变量:
  GARDEN_SKILLS_ROOT    garden-skills 仓库根（含 skills/ 子目录）
  GARDEN_OUTPUT_ROOT    产物根目录（默认 <repo>/garden-output）
  ENABLE_GARDEN_IMAGEGEN=1 + OPENAI_API_KEY   封面本地出图（gpt-image-2 Mode A）
  GARDEN_ARTICLE_THEME   scaffold 默认主题（默认 tufte）

典型一条龙:
  1. ./scripts/garden-furnace.sh run my-post --source ./draft.md
  2. 在 Cursor / Claude 打开 tasks/01-write-article.md 让 Agent 写完并 npm run build
  3. ./scripts/garden-furnace.sh cover my-post   # 有 KEY 时
  4. ./scripts/garden-furnace.sh pdf my-post

安装缺失 skill:
  npx skills add ConardLi/garden-skills --skill beautiful-article --skill gpt-image-2
EOF
}

cmd_doctor() {
  local ok=0
  command -v node >/dev/null 2>&1 || { echo "✗ 需要 Node.js"; ok=1; }
  command -v python3 >/dev/null 2>&1 || { echo "✗ 需要 python3"; ok=1; }

  local skill
  for skill in beautiful-article gpt-image-2; do
    if resolve_skill "$skill" >/dev/null 2>&1; then
      echo "✓ skill: $skill → $(resolve_skill "$skill")"
    else
      echo "✗ 未找到 skill: $skill（npx skills add ConardLi/garden-skills --skill $skill）"
      ok=1
    fi
  done

  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    echo "✓ OPENAI_API_KEY 已设置"
  else
    echo "○ OPENAI_API_KEY 未设置（封面步骤将只生成 prompt 任务卡）"
  fi

  if [[ "${ENABLE_GARDEN_IMAGEGEN:-}" =~ ^(1|true|yes|on)$ ]]; then
    echo "✓ ENABLE_GARDEN_IMAGEGEN 已开启"
  else
    echo "○ ENABLE_GARDEN_IMAGEGEN 未开启（export ENABLE_GARDEN_IMAGEGEN=1 可本地出图）"
  fi

  return "$ok"
}

cmd_init() {
  local slug="$1"
  shift
  local source=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
  done
  [[ -n "$source" ]] || { echo "需要 --source <file>" >&2; exit 1; }
  [[ -f "$source" ]] || { echo "源文件不存在: $source" >&2; exit 1; }

  local dir
  dir="$(slug_dir "$slug")"
  mkdir -p "${dir}/source" "${dir}/tasks" "${dir}/cover"
  cp -f "$source" "${dir}/source/input$(printf '%s' "$source" | sed -E 's/.*(\.[^./]+)$/\1/')"
  write_state "$slug" \
    phase=init \
    "source=$(basename "$source")" \
    article_workspace=
  echo "✓ 炼炉已点火: ${dir}"
  echo "  源稿: ${dir}/source/"
}

cmd_scaffold() {
  local slug="$1"
  shift
  local theme="${GARDEN_ARTICLE_THEME:-tufte}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --theme=*) theme="${1#--theme=}"; shift ;;
      --theme) theme="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
  done

  local ba_skill ws_dir
  ba_skill="$(resolve_skill beautiful-article)" || {
    echo "✗ 未找到 beautiful-article" >&2
    exit 1
  }
  ws_dir="$(slug_dir "$slug")/article-workspace"
  mkdir -p "$(dirname "$ws_dir")"
  bash "${ba_skill}/scripts/scaffold.sh" "$ws_dir" "--theme=${theme}"

  write_state "$slug" \
    phase=scaffolded \
    article_workspace=article-workspace \
    "article_theme=${theme}"
  echo "✓ 文章工作区: ${ws_dir}"
  echo "  下一步: ./scripts/garden-furnace.sh task ${slug}"
}

cmd_task() {
  local slug="$1"
  local dir ba_skill gi_skill
  dir="$(slug_dir "$slug")"
  ba_skill="$(resolve_skill beautiful-article)" || exit 1
  gi_skill="$(resolve_skill gpt-image-2)" || exit 1
  mkdir -p "${dir}/tasks"

  cat > "${dir}/tasks/01-write-article.md" <<EOF
# 炼炉任务 01 · 写成精美文章

**炼炉 slug:** \`${slug}\`
**必读 Skill:** \`${ba_skill}/SKILL.md\`
**工作区:** \`${dir}/article-workspace\`
**源稿:** \`${dir}/source/\`

## 你要做的

1. 读源稿，按 beautiful-article 的 Phase 4–7 完成首屏 + 全部 Section。
2. 在 \`${dir}/article-workspace\` 内改 \`article/Article.tsx\`，遵守 component-policy / raw-policy / 当前 theme profile。
3. 跑 \`npm run dev\` 预览，\`npm run build\` 产出 \`article/article.html\`。
4. 信息保留率优先，不要删源稿事实。

## 完成标准

- [ ] \`${dir}/article-workspace/article/article.html\` 存在且可打开
- [ ] \`npm run typecheck\` 通过（若有）

完成后执行:
\`\`\`bash
./scripts/garden-furnace.sh cover ${slug}
./scripts/garden-furnace.sh pdf ${slug}
\`\`\`
EOF

  cat > "${dir}/tasks/02-cover-image.md" <<EOF
# 炼炉任务 02 · 封面 / 头图 prompt

**炼炉 slug:** \`${slug}\`
**必读 Skill:** \`${gi_skill}/SKILL.md\`
**参考模板:** \`${gi_skill}/references/poster-editorial/\`（或 poster / product-visuals 下合适模板）

## 你要做的

1. 读已完成文章的标题与摘要气质。
2. 选一个 gpt-image-2 模板，填字段，写出**最终英文 prompt**（一字不改可喂模型）。
3. 保存到: \`${dir}/cover/prompt.txt\`

## 完成标准

- [ ] \`${dir}/cover/prompt.txt\` 存在

有 OPENAI_API_KEY 且 ENABLE_GARDEN_IMAGEGEN=1 时，脚本会自动出图:
\`\`\`bash
./scripts/garden-furnace.sh cover ${slug}
\`\`\`
EOF

  write_state "$slug" phase=tasks_ready
  echo "✓ Agent 任务卡:"
  echo "  ${dir}/tasks/01-write-article.md"
  echo "  ${dir}/tasks/02-cover-image.md"
  echo ""
  echo "→ 在 Cursor / Claude 打开 01，写完文章后再处理 02 与 cover。"
}

cmd_cover() {
  local slug="$1"
  local dir gi_skill prompt_file image_out mode_json
  dir="$(slug_dir "$slug")"
  gi_skill="$(resolve_skill gpt-image-2)" || exit 1
  prompt_file="${dir}/cover/prompt.txt"
  image_out="${dir}/cover/cover.png"

  mode_json="$(node "${gi_skill}/scripts/check-mode.js" --json 2>/dev/null || true)"
  if [[ -z "$mode_json" ]]; then
    echo "✗ gpt-image-2 check-mode 失败" >&2
    exit 1
  fi

  local mode
  mode="$(printf '%s' "$mode_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mode',''))")"

  if [[ ! -f "$prompt_file" ]]; then
    echo "○ 尚无 ${prompt_file}"
    echo "  先让 Agent 执行 tasks/02-cover-image.md，或手写 prompt.txt"
    exit 0
  fi

  if [[ "$mode" != "A" ]]; then
    echo "○ gpt-image-2 当前模式: ${mode}（非 Mode A，跳过 generate.js）"
    echo "  prompt 已就绪: ${prompt_file}"
    echo "  用宿主图像工具或设置 ENABLE_GARDEN_IMAGEGEN=1 + OPENAI_API_KEY 后重试"
    exit 0
  fi

  node "${gi_skill}/scripts/generate.js" \
    --promptfile "$prompt_file" \
    --image "$image_out" \
    --json
  write_state "$slug" phase=cover_done cover_image=cover/cover.png
  echo "✓ 封面: ${image_out}"
}

cmd_pdf() {
  local slug="$1"
  local dir ba_skill ws html pdf
  dir="$(slug_dir "$slug")"
  ba_skill="$(resolve_skill beautiful-article)" || exit 1
  ws="${dir}/article-workspace"
  html="${ws}/article/article.html"
  pdf="${dir}/article.pdf"

  [[ -f "$html" ]] || {
    echo "✗ 还没有 ${html}" >&2
    echo "  先完成 tasks/01-write-article.md（npm run build）" >&2
    exit 1
  }

  (cd "$ws" && bash "${ba_skill}/scripts/html-to-pdf.sh" "article/article.html" "${pdf}")
  write_state "$slug" phase=pdf_done pdf=article.pdf
  echo "✓ PDF: ${pdf}"
}

cmd_status() {
  local slug="${1:-}"
  if [[ -z "$slug" ]]; then
    echo "炼炉目录: ${OUTPUT_ROOT}"
    if [[ -d "$OUTPUT_ROOT" ]]; then
      find "$OUTPUT_ROOT" -maxdepth 2 -name 'STATE.json' -print 2>/dev/null | while read -r f; do
        python3 -c "import json; d=json.load(open('$f')); print(f\"  {d.get('slug','?')}: phase={d.get('phase','?')}\")"
      done
    fi
    return 0
  fi
  local sf
  sf="$(state_file "$slug")"
  [[ -f "$sf" ]] || { echo "无此炼炉: $slug" >&2; exit 1; }
  python3 -m json.tool "$sf"
}

cmd_run() {
  local slug="$1"
  shift
  local source="" theme="${GARDEN_ARTICLE_THEME:-tufte}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      --theme=*) theme="${1#--theme=}"; shift ;;
      --theme) theme="$2"; shift 2 ;;
      *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
  done
  [[ -n "$source" ]] || { echo "run 需要 --source <file>" >&2; exit 1; }

  cmd_init "$slug" --source "$source"
  cmd_scaffold "$slug" --theme="$theme"
  cmd_task "$slug"

  cat <<EOF

════════════════════════════════════════════════════════
炼炉「${slug}」已搭好 · workflow=${WORKFLOW}
════════════════════════════════════════════════════════

产物目录: $(slug_dir "$slug")

下一步（人工 / Agent）:
  1. 打开 tasks/01-write-article.md → 写完并 npm run build
  2. 打开 tasks/02-cover-image.md  → 写 cover/prompt.txt
  3. ./scripts/garden-furnace.sh cover ${slug}
  4. ./scripts/garden-furnace.sh pdf ${slug}

EOF
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    doctor) cmd_doctor ;;
    init) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_init "$@" ;;
    scaffold) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_scaffold "$@" ;;
    task) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_task "$@" ;;
    cover) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_cover "$@" ;;
    pdf) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_pdf "$@" ;;
    status) cmd_status "${1:-}" ;;
    run) [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_run "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "未知命令: $cmd" >&2; usage; exit 1 ;;
  esac
}

main "$@"
