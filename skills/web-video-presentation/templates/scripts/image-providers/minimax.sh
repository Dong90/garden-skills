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
#   prompt_json: {"prompt":"...","size":"1920x1080","style":"...","negative":"...","seed":N}
#   out_path:    目标 PNG 路径（runner 保证父目录已建）
image_generate() {
  local prompt_json="$1"
  local out="$2"

  # 解析 prompt_json（python 拿字段，避免 jq 依赖；跨平台稳）
  local prompt size style negative seed
  read prompt size style negative seed < <(python3 - "$prompt_json" <<'PY'
import json, sys
p = json.loads(sys.argv[1])
print(p.get("prompt", ""),
      p.get("size", "1920x1080"),
      p.get("style", ""),
      p.get("negative", ""),
      p.get("seed", ""))
PY
)

  # mmx image generate 假定接口（如果你的 mmx 子命令不同，
  # 改这一行就行；其它 provider 不用动）
  local args=(
    image generate
    --prompt "$prompt"
    --out "$out"
    --size "$size"
  )
  [[ -n "$style"    ]] && args+=( --style    "$style"    )
  [[ -n "$negative" ]] && args+=( --negative "$negative" )
  [[ -n "$seed"     ]] && args+=( --seed     "$seed"     )

  mmx "${args[@]}" >/dev/null 2>&1
}
