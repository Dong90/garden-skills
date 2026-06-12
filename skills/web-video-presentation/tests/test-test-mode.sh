#!/usr/bin/env bash
# T2: test mode（--test 跳过 audio+record，continue 接着跑）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }
[[ -f "scripts/commands/continue.sh" ]] || { echo "  ✗ scripts/commands/continue.sh missing"; exit 1; }

# ── 1. --help 含 --test / --continue ──
help_out=$(bash "$SCRIPT" --help 2>&1)
assert_contains "--help 含 --test"     "--test"     "$help_out"
assert_contains "--help 含 --continue" "--continue" "$help_out"

# ── 2. router: continue 已注册 ──
assert_file_exists "commands/continue.sh 存在" "scripts/commands/continue.sh"
assert_grep "continue.sh: 定义 cmd_continue" "^cmd_continue" "scripts/commands/continue.sh"

# ── 3. --test 写入 state.json ──
TMPDIR=$(make_tmpdir)
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOF
chmod +x "$SCAFFOLD_STUB"

OUT="$TMPDIR/my-video"
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" \
  --out="$OUT" --test 2>&1
rc=$?
set -e
assert_eq "init --test: exit 0" "0" "$rc"

assert_file_exists "state.json 落盘" "$OUT/.book-video/state.json"
assert_contains "state.json mode=test" '"mode": "test"' "$(cat "$OUT/.book-video/state.json")"

# state.json 应含 test / audio=false / record=false
if grep -q '"test": true' "$OUT/.book-video/state.json"; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "state.json 含 test=true"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("state.json 缺 test=true")
  _log_fail "state.json 缺 test=true"
fi

assert_contains "state.json audio=false" '"audio": false' "$(cat "$OUT/.book-video/state.json")"
assert_contains "state.json images=true (test 仍出图)" '"images": true' "$(cat "$OUT/.book-video/state.json")"

if grep -q '"record": false' "$OUT/.book-video/state.json"; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "state.json record=false"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("state.json record 应为 false")
  _log_fail "state.json record 应为 false"
fi

# ── 4. init 输出提示 test 模式 ──
out2=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" \
  --out="$TMPDIR/my-video-2" --test 2>&1)
assert_contains "init 输出含 test 提示" "test" "$out2"

# ── 5. continue 子命令：能跑（exit 0 或 1）──
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" continue "$OUT" 2>&1 >/dev/null
rc3=$?
set -e
if [[ $rc3 -eq 0 || $rc3 -eq 1 ]]; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "continue: 能运行 (exit=$rc3)"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("continue 异常退出 ($rc3)")
  _log_fail "continue 异常退出 ($rc3)"
fi

# ── 6. 不传 --test 时，audio 默认开，无 test=true ──
OUT3="$TMPDIR/my-video-3"
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" \
  --out="$OUT3" 2>&1 >/dev/null
assert_contains "默认: audio=true" '"audio": true' "$(cat "$OUT3/.book-video/state.json")"
if grep -qE '"test": true' "$OUT3/.book-video/state.json"; then
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("默认模式不应有 test=true")
  _log_fail "默认模式不应有 test=true"
else
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "默认模式: 无 test=true"
fi

rm -rf "$TMPDIR"
print_summary "test-test-mode"
