#!/usr/bin/env bash
# T13: image provider 契约（minimax.sh 必须定义 image_check / image_install_help / image_generate）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

MINIMAX="templates/scripts/image-providers/minimax.sh"
README="templates/scripts/image-providers/README.md"

# ── 1. 文件存在 ──
assert_file_exists "image-providers/minimax.sh 存在" "$MINIMAX"
assert_file_exists "image-providers/README.md 存在" "$README"

# ── 2. minimax.sh 定义了 3 个必需函数 ──
assert_grep "minimax.sh: 定义 image_check" "image_check\\s*\\(\\s*\\)" "$MINIMAX"
assert_grep "minimax.sh: 定义 image_install_help" "image_install_help\\s*\\(\\s*\\)" "$MINIMAX"
assert_grep "minimax.sh: 定义 image_generate" "image_generate\\s*\\(\\s*\\)" "$MINIMAX"

# ── 3. minimax.sh 用 mmx CLI（与 TTS 风格一致）──
assert_grep "minimax.sh: 调用 mmx image" "mmx" "$MINIMAX"
assert_grep "minimax.sh: 包含 --prompt" "prompt" "$MINIMAX"
assert_grep "minimax.sh: 包含 --out" "out" "$MINIMAX"

# ── 4. README.md 文档契约 ──
assert_grep "image-providers/README.md: 说明 minimax 是默认" "minimax" "$README"
assert_grep "image-providers/README.md: 说明 3 函数契约" "image_generate" "$README"

# ── 5. minimax.sh 可 source（语法合法）──
set +e
bash -n "$MINIMAX"
rc=$?
set -e
assert_eq "minimax.sh 语法合法" "0" "$rc"

# ── 6. source 后函数可被调用（不报错）──
(
  source "$MINIMAX"
  # type -t 检查函数是否定义（macOS bash 3.2 兼容）
  type image_check        >/dev/null 2>&1 && echo "image_check defined" || echo "image_check MISSING"
  type image_install_help >/dev/null 2>&1 && echo "image_install_help defined" || echo "image_install_help MISSING"
  type image_generate     >/dev/null 2>&1 && echo "image_generate defined" || echo "image_generate MISSING"
) > /tmp/provider-source.out 2>&1
assert_contains "source 后 image_check 可用" "image_check defined" "$(cat /tmp/provider-source.out)"
assert_contains "source 后 image_install_help 可用" "image_install_help defined" "$(cat /tmp/provider-source.out)"
assert_contains "source 后 image_generate 可用" "image_generate defined" "$(cat /tmp/provider-source.out)"

print_summary "test-image-provider-contract"
