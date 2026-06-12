#!/usr/bin/env bash
# T4: 输入源（文件 / stdin）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
FIXT="tests/fixtures/sample-chapter.md"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }
[[ ! -f "$FIXT"  ]] && { echo "  ✗ fixture $FIXT missing"; exit 1; }

TMPDIR=$(make_tmpdir)
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'STUB_EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"
mkdir -p "$TARGET"
echo '{"name":"x"}' > "$TARGET/package.json"
exit 0
STUB_EOF
chmod +x "$SCAFFOLD_STUB"

# ── 1. 文件输入：跑通主流程 ──
set +e
out_file=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "$FIXT" --out="$TMPDIR/file-mode" 2>&1)
rc_file=$?
set -e
assert_not_contains "file input: 不报'找不到文件'" "找不到文件" "$out_file"
assert_contains "file input: 进入主流程（应见'准备完成'）" "准备完成" "$out_file"
assert_dir_exists "file input: --out 目录创建" "$TMPDIR/file-mode"

# ── 2. stdin 输入 ──
set +e
out_stdin=$(cat "$FIXT" | WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" - --out="$TMPDIR/stdin-mode" 2>&1)
rc_stdin=$?
set -e
assert_not_contains "stdin input: 不报'找不到文件'" "找不到文件" "$out_stdin"
assert_contains "stdin input: 进入主流程（应见'准备完成'）" "准备完成" "$out_stdin"
assert_dir_exists "stdin input: --out 目录创建" "$TMPDIR/stdin-mode"

# ── 3. stdin 落盘到 article.md（非空）──
assert_file_exists "stdin: article.md 落盘" "$TMPDIR/stdin-mode/article.md"
STDIN_BYTES=$(wc -c < "$TMPDIR/stdin-mode/article.md" | tr -d ' ')
if [[ "$STDIN_BYTES" -gt 10 ]]; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "stdin: article.md 非空 ($STDIN_BYTES bytes)"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("stdin: article.md is empty ($STDIN_BYTES bytes)")
  _log_fail "stdin: article.md 空"
fi

# ── 4. stdin + --lang=zh 强制覆盖 ──
set +e
out_force=$(cat "$FIXT" | WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" - --out="$TMPDIR/stdin-force" --lang=zh 2>&1)
set -e
assert_contains "stdin + --lang=zh: 强制 zh" "检测到主语言: zh" "$out_force"

# ── 5. 文件 + --lang=en 强制覆盖 ──
set +e
out_force2=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "$FIXT" --out="$TMPDIR/file-force" --lang=en 2>&1)
set -e
assert_contains "file + --lang=en: 强制 en" "检测到主语言: en" "$out_force2"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-input"
