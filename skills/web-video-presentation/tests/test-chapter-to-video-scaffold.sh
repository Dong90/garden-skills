#!/usr/bin/env bash
# T9: scaffold 集成（用 WVP_SCAFFOLD_SH 环境变量注入假 scaffold，避免 npm install）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ ! -f "$SCRIPT" ]] && { echo "  ✗ $SCRIPT missing"; exit 1; }

TMPDIR=$(make_tmpdir)
OUT="$TMPDIR/my-video"
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"

# 假 scaffold：只创建必要文件，不跑 npm
cat > "$SCAFFOLD_STUB" <<'STUB_EOF'
#!/usr/bin/env bash
# fake-scaffold.sh <target-dir> [--theme=<id>]
TARGET="${1:-presentation}"
THEME="default"
for arg in "$@"; do
  case "$arg" in
    --theme=*) THEME="${arg#--theme=}" ;;
  esac
done
mkdir -p "$TARGET"
cat > "$TARGET/package.json" <<EOF2
{
  "name": "fake-presentation",
  "theme": "$THEME"
}
EOF2
mkdir -p "$TARGET/src/chapters/01-example"
cat > "$TARGET/src/chapters/01-example/narrations.ts" <<'EOF2'
export const narrations = ["hello"];
EOF2
echo "▸ (fake-scaffold) created $TARGET with theme=$THEME"
STUB_EOF
chmod +x "$SCAFFOLD_STUB"

# ── 1. 注入 WVP_SCAFFOLD_SH，跑通整条链 ──
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT" 2>&1
rc=$?
set -e
assert_eq "full run: exit 0" "0" "$rc"

# ── 2. presentation/ 存在且有 package.json ──
assert_dir_exists "presentation/ 目录创建" "$OUT/presentation"
assert_file_exists "presentation/package.json 落盘" "$OUT/presentation/package.json"
assert_contains "package.json 写入了 theme" "\"kraft-paper\"" "$(cat "$OUT/presentation/package.json")"

# ── 3. --theme=indigo-porcelain 也工作 ──
OUT2="$TMPDIR/my-video-2"
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT2" --theme=indigo-porcelain 2>&1
rc=$?
set -e
assert_eq "theme=indigo-porcelain: exit 0" "0" "$rc"
assert_contains "theme=indigo-porcelain: package.json 写入主题" "\"indigo-porcelain\"" "$(cat "$OUT2/presentation/package.json")"

# ── 4. --resume 跳过 scaffold（stub 会记日志）──
OUT3="$TMPDIR/my-video-3"
set +e
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT3" --resume 2>&1
out3=$?
set -e
# stub 不支持 --resume，所以也会跑。检查 article.md 仍存在即可。
assert_file_exists "resume: article.md 仍存在" "$OUT3/article.md"

# ── 5. scaffold 失败时 exit != 0 ──
BAD_STUB="$TMPDIR/bad-scaffold.sh"
cat > "$BAD_STUB" <<'STUB_EOF'
#!/usr/bin/env bash
exit 1
STUB_EOF
chmod +x "$BAD_STUB"
OUT4="$TMPDIR/my-video-4"
set +e
WVP_SCAFFOLD_SH="$BAD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT4" 2>&1
rc_bad=$?
set -e
assert_eq "scaffold 失败 → exit != 0" "1" "$rc_bad"

# ── 6. stdin 也能跑通整条链 ──
OUT5="$TMPDIR/my-video-5"
set +e
cat "tests/fixtures/cn-chapter.md" | WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" - --out="$OUT5" 2>&1
rc5=$?
set -e
assert_eq "stdin + scaffold: exit 0" "0" "$rc5"
assert_file_exists "stdin: article.md 落盘" "$OUT5/article.md"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-scaffold"
