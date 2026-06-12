#!/usr/bin/env bash
# T1: --help / -h 输出用法
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"

# ── 失败前置：脚本不存在就不测 ──
if [[ ! -f "$SCRIPT" ]]; then
  echo "  $(printf '\033[0;31m✗\033[0m') FAIL PRECONDITION: $SCRIPT does not exist yet"
  echo "    (this is expected on RED — write the script to make this test pass)"
  _TEST_TOTAL=1
  _TEST_FAIL=1
  _TEST_FAILURES+=("$SCRIPT missing")
  print_summary "test-chapter-to-video-help"
  exit 1
fi

# ── 测试用例 ──
run_capture bash "$SCRIPT" --help
assert_exit "--help exits 0" "0" bash "$SCRIPT" --help
assert_contains "--help mentions chapter-to-video" "chapter-to-video" "$RUN_OUT"
assert_contains "--help mentions --theme" "--theme" "$RUN_OUT"
assert_contains "--help mentions --out" "--out" "$RUN_OUT"
assert_contains "--help mentions --list-themes" "--list-themes" "$RUN_OUT"
assert_contains "--help mentions --provider" "--provider" "$RUN_OUT"
assert_contains "--help mentions --no-audio" "--no-audio" "$RUN_OUT"
assert_contains "--help mentions --resume" "--resume" "$RUN_OUT"
assert_contains "--help mentions --episodes" "--episodes" "$RUN_OUT"
assert_contains "--help mentions --lang" "--lang" "$RUN_OUT"
assert_contains "--help mentions --title" "--title" "$RUN_OUT"

run_capture bash "$SCRIPT" -h
assert_exit "-h exits 0" "0" bash "$SCRIPT" -h
assert_contains "-h works as alias" "chapter-to-video" "$RUN_OUT"

print_summary "test-chapter-to-video-help"
