#!/usr/bin/env bash
# T10: scaffold.sh --chapter 开关
# 用 fake npm 避免真实网络/磁盘
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCAFFOLD="scripts/scaffold.sh"
[[ ! -f "$SCAFFOLD" ]] && { echo "  ✗ $SCAFFOLD missing"; exit 1; }

TMPDIR=$(make_tmpdir)
FAKE_BIN="$TMPDIR/fakebin"
mkdir -p "$FAKE_BIN"

# ── fake npm / npx / node / tsc ──
cat > "$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
# fake npm: 只创建 vite 项目的最小结构
# 处理：
#   npm create vite@latest <dir> -- --template react-ts
#   npm install
#   npm install --save-dev <pkg>
case "$*" in
  *"create vite"*)
    # 末位是目标目录
    TARGET="$3"
    [[ -d "$TARGET" ]] || mkdir -p "$TARGET/src"
    [[ -f "$TARGET/package.json" ]] || echo '{"name":"x","dependencies":{"react":"^18"},"devDependencies":{}}' > "$TARGET/package.json"
    ;;
  *"install"*)
    # no-op
    ;;
esac
exit 0
EOF
cat > "$FAKE_BIN/npx" <<'EOF'
#!/usr/bin/env bash
# fake npx tsc：永远退出 0
exit 0
EOF
cat > "$FAKE_BIN/tsc" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$FAKE_BIN/node" <<'EOF'
#!/usr/bin/env bash
# fake node: 仅支持 "node -e <js>"（scaffold.sh 用来合并 package.json scripts）
if [[ "$1" == "-e" ]]; then
  shift 2   # skip -e and the JS string
  exit 0
fi
exit 0
EOF
chmod +x "$FAKE_BIN/"*

# ── 1. 不带 --chapter：不应该创建 BOOK-CHAPTER.md ──
OUT1="$TMPDIR/no-chapter"
set +e
PATH="$FAKE_BIN:$PATH" bash "$SCAFFOLD" "$OUT1" --theme=kraft-paper 2>&1
rc=$?
set -e
assert_eq "scaffold.sh 默认 exit 0" "0" "$rc"
assert_dir_exists "scaffold.sh 创建项目" "$OUT1"
# 关键断言：没有 BOOK-CHAPTER.md
if [[ -f "$OUT1/BOOK-CHAPTER.md" ]]; then
  _TEST_FAIL=$((_TEST_FAIL+1))
  _TEST_FAILURES+=("default mode: BOOK-CHAPTER.md 不应存在")
  _log_fail "default mode: BOOK-CHAPTER.md 不应存在"
else
  _TEST_PASS=$((_TEST_PASS+1))
  _log_pass "default mode: BOOK-CHAPTER.md 不存在"
fi
_TEST_TOTAL=$((_TEST_TOTAL+1))

# ── 2. 带 --chapter：应创建 BOOK-CHAPTER.md ──
OUT2="$TMPDIR/with-chapter"
set +e
PATH="$FAKE_BIN:$PATH" bash "$SCAFFOLD" "$OUT2" --theme=kraft-paper --chapter 2>&1
rc=$?
set -e
assert_eq "scaffold.sh --chapter exit 0" "0" "$rc"
assert_dir_exists "--chapter: 创建项目" "$OUT2"
assert_file_exists "--chapter: BOOK-CHAPTER.md 落盘" "$OUT2/BOOK-CHAPTER.md"
# 内容应当从 references/ 复制
SRC_BOOK="$TMPDIR/../references/BOOK-CHAPTER.md"
diff -q "$OUT2/BOOK-CHAPTER.md" "references/BOOK-CHAPTER.md" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
  _TEST_PASS=$((_TEST_PASS+1))
  _log_pass "--chapter: BOOK-CHAPTER.md 与 references/ 内容一致"
else
  _TEST_FAIL=$((_TEST_FAIL+1))
  _TEST_FAILURES+=("--chapter: BOOK-CHAPTER.md 内容与 references/ 不一致")
  _log_fail "--chapter: BOOK-CHAPTER.md 内容与 references/ 不一致"
fi
_TEST_TOTAL=$((_TEST_TOTAL+1))

# ── 3. --chapter 模式下，输出应提示"书籍章节模式额外提示" ──
OUT3="$TMPDIR/with-chapter-2"
set +e
PATH="$FAKE_BIN:$PATH" bash "$SCAFFOLD" "$OUT3" --theme=kraft-paper --chapter 2>&1 | grep -q "书籍章节模式"
rc_grep=$?
set -e
assert_eq "--chapter: 输出含'书籍章节模式'提示" "0" "$rc_grep"

rm -rf "$TMPDIR"
print_summary "test-scaffold-chapter-flag"
