#!/usr/bin/env bash
# ────────────────────────────────────────────────────────────────────
# MiniMax image provider — uses the official mmx-cli.
#
# Docs:  https://platform.minimaxi.com/docs/token-plan/minimax-cli
# Repo:  https://github.com/MiniMax-AI/cli
#
# 默认 provider —— 与 audio 侧 mmx speech synthesize 同源。
# 若你的 mmx 子命令叫别的（例如 mmx i2i），把下面 mmx image generate
# 那一行改掉就行；本 skill 的 provider 抽象 = 一个 .sh 文件 + 3 个函数。
# ────────────────────────────────────────────────────────────────────

image_check() {
  if ! command -v mmx >/dev/null; then
    echo "✗ mmx CLI not found in PATH." >&2
    return 1
  fi
  if ! mmx auth status >/dev/null 2>&1; then
    echo "✗ mmx is not authenticated." >&2
    return 1
  fi
}

image_install_help() {
  cat <<'EOF' >&2
To use the MiniMax image provider:

  Install:  npm install -g mmx-cli
  Login:    mmx auth login --api-key sk-xxxxx
            (get a key at https://platform.minimaxi.com)

Or pick another provider:
  PRESENTATION_IMG=<name> npm run synthesize-images
See image-providers/README.md for the list and how to add your own.
EOF
}

# image_generate <prompt_json> <out_path>
#   prompt_json: {"prompt":"...","size":"1920x1080","style":"...","negative":"...","seed":N,
#                 "imageReference":"<rel-path>","referenceStrength":0.6}
#   out_path:    目标 PNG 路径（runner 保证父目录已建）
#
# 错误处理：mmx 失败时打印 prompt 摘要到 stderr（不吞错），退出非 0 让 runner 记 failed。
image_generate() {
  local prompt_json="$1"
  local out="$2"

  # 逐字段用 python 读，避开 bash `read` 的 IFS 切分问题（中文 prompt 必含空格）
  local prompt size style negative seed image_reference reference_strength
  prompt=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("prompt",""))' < "$prompt_json")
  size=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("size","1920x1080"))' < "$prompt_json")
  style=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("style",""))' < "$prompt_json")
  negative=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("negative",""))' < "$prompt_json")
  seed=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("seed",""))' < "$prompt_json")
  image_reference=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("imageReference",""))' < "$prompt_json")
  reference_strength=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("referenceStrength",""))' < "$prompt_json")

  local args=(
    image generate
    --prompt "$prompt"
    --out "$out"
    --size "$size"
  )
  [[ -n "$style"             ]] && args+=( --style             "$style"             )
  [[ -n "$negative"          ]] && args+=( --negative          "$negative"          )
  [[ -n "$seed"              ]] && args+=( --seed              "$seed"              )
  [[ -n "$image_reference"   ]] && args+=( --image-reference  "$image_reference"  )
  [[ -n "$reference_strength" ]] && args+=( --reference-strength "$reference_strength" )

  if ! mmx "${args[@]}"; then
    # 不吞错 —— 把 prompt 摘要和文件路径打出来，便于诊断
    local preview="${prompt:0:80}"
    [[ ${#prompt} -gt 80 ]] && preview="${preview}..."
    echo "  ✗ mmx 失败" >&2
    echo "    prompt:    $preview" >&2
    echo "    style:     ${style:-<none>}" >&2
    echo "    negative:  ${negative:-<none>}" >&2
    echo "    out:       $out" >&2
    return 1
  fi
}
