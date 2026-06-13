#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
# synthesize-images.sh —— provider-agnostic 图像生成 runner
#
# 用法：
#   bash scripts/synthesize-images.sh [--force] [--provider=<id>]
#
# env（test 注入用）：
#   WVP_IMG_PROVIDER       注入 provider 文件路径（绕开默认）
#   WVP_IMG_PROMPTS        注入 prompts JSON 路径（绕开 extract-images）
#   WVP_IMG_OUT_ROOT       注入输出根目录（绕开自动推断）
#   WVP_IMG_NO_DEFAULT_CHECK=1  跳过默认 image_check（测试用）
# ────────────────────────────────────────────────────────────────────
set -eo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 找项目根（含 presentation/ 的目录）──
find_project_root() {
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "$dir/src/chapters" || -f "$dir/package.json" ]]; then
      echo "$dir"; return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "$(pwd)"
}

PROJECT_ROOT="${WVP_IMG_PROJECT_ROOT:-$(find_project_root)}"

# ── 默认 provider = minimax（env var PRESENTATION_IMG 可覆盖）──
PROVIDER_NAME="${PRESENTATION_IMG:-minimax}"
PROVIDER_FILE="${WVP_IMG_PROVIDER:-$SCRIPTS_DIR/image-providers/$PROVIDER_NAME.sh}"

# ── 解析参数 ──
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force)        FORCE=1 ;;
    --provider=*)   PROVIDER_NAME="${arg#--provider=}"; PROVIDER_FILE="$SCRIPTS_DIR/image-providers/$PROVIDER_NAME.sh" ;;
    --*)            echo "✗ 未知参数: $arg" >&2; exit 1 ;;
  esac
done

# ── 找 prompts JSON ──
PROMPTS_JSON="${WVP_IMG_PROMPTS:-$PROJECT_ROOT/image-prompts.json}"
[[ -f "$PROMPTS_JSON" ]] || { echo "✗ 找不到 $PROMPTS_JSON（先跑 npm run extract-images）" >&2; exit 1; }

# ── 输出根 ──
OUT_ROOT="${WVP_IMG_OUT_ROOT:-$PROJECT_ROOT}"

# ── 加载 provider ──
[[ -f "$PROVIDER_FILE" ]] || { echo "✗ 找不到 provider: $PROVIDER_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$PROVIDER_FILE"
echo "▸ image provider: $PROVIDER_NAME"

# ── 调 image_check（除非 test 显式跳过）──
if [[ "${WVP_IMG_NO_DEFAULT_CHECK:-0}" != "1" ]]; then
  if ! image_check; then
    image_install_help
    exit 1
  fi
fi

# ── 读 prompts ──
TOTAL=$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$PROMPTS_JSON")
echo "▸ 共 $TOTAL 张图片待生成"
DONE=0
SKIPPED=0
FAILED=0

# ── 循环生成 ──
while IFS= read -r record; do
  [[ -z "$record" ]] && continue
  OUT_REL=$(echo "$record" | python3 -c "import json,sys; print(json.load(sys.stdin)['out'])")
  OUT_PATH="$OUT_ROOT/$OUT_REL"

  # 增量：已存在且不是 --force → 跳过
  if [[ -f "$OUT_PATH" && "$FORCE" -eq 0 ]]; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  mkdir -p "$(dirname "$OUT_PATH")"

  if image_generate "$record" "$OUT_PATH"; then
    DONE=$((DONE + 1))
    echo "  ✓ $OUT_REL"
  else
    FAILED=$((FAILED + 1))
    echo "  ✗ $OUT_REL" >&2
  fi
done < <(python3 -c "import json,sys; [print(json.dumps(r, ensure_ascii=False)) for r in json.load(open(sys.argv[1]))]" "$PROMPTS_JSON")

echo "▸ 完成：$DONE 张生成 / $SKIPPED 跳过 / $FAILED 失败"
[[ $FAILED -eq 0 ]] || exit 1
exit 0
