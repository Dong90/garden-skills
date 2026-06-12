#!/usr/bin/env bash
# tests/run.sh —— 跑 tests/test-*.sh 全部
# 用法：bash tests/run.sh [single-test-file]
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # cd 到 skill 根目录

PATTERN='test-*.sh'
if [[ -n "${1:-}" ]]; then PATTERN="$1"; fi

echo "═══ web-video-presentation test suite ═══"
echo "    pattern: $PATTERN"
echo

overall_fail=0
ran=0
for f in tests/$PATTERN; do
  [[ -f "$f" ]] || { echo "  (no test files matching $PATTERN)"; exit 0; }
  ran=$((ran + 1))
  echo "── $f ──"
  if bash "$f"; then
    :
  else
    overall_fail=$((overall_fail + 1))
  fi
  echo
done

echo "═══ summary ═══"
echo "  files run: $ran"
echo "  files failed: $overall_fail"
exit "$overall_fail"
