#!/usr/bin/env bash
# T2: --list-themes 列出主题
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

# ── 应当列出 23 个主题（已知）──
EXPECTED_THEMES=(
  "kraft-paper" "paper-press" "vintage-editorial"
  "forest-ink" "chalk-garden" "dark-botanical"
  "indigo-porcelain" "midnight-press" "swiss-ikb"
  "neon-cyber" "blueprint" "bauhaus-bold"
  "pastel-dream" "electric-studio" "newsroom"
  "warm-keynote" "dune" "split-canvas"
  "monochrome-print" "terminal-green" "bold-signal"
  "sunset-zine"
)

run_capture bash "$SCRIPT" --list-themes
assert_exit "--list-themes exits 0" "0" bash "$SCRIPT" --list-themes
assert_contains "output mentions 可用主题" "可用主题" "$RUN_OUT"

# 抽样几个最关键的主题
for t in "kraft-paper" "paper-press" "vintage-editorial" "neon-cyber" "indigo-porcelain"; do
  assert_contains "lists theme: $t" "$t" "$RUN_OUT"
done

# 默认主题应该被标注
assert_contains "default theme annotated" "默认" "$RUN_OUT"

# 必须不存在占位 TODO
assert_not_contains "no TODO placeholder" "TODO: list themes" "$RUN_OUT"

print_summary "test-chapter-to-video-list-themes"
