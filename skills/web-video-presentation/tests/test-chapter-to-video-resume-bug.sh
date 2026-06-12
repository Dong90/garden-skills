#!/usr/bin/env bash
# T19a: 修 --resume bug + status + STATE.md
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }

TMPDIR=$(make_tmpdir)
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOF
chmod +x "$SCAFFOLD_STUB"

# ── 1. 修 bug：目录已存在 + ! --resume → die（保留）──
# 目录已存在 + --resume → 继续（应能跑完，--resume 跳过 scaffold）
OUT="$TMPDIR/mv"
mkdir -p "$OUT"  # 模拟"已存在的 my-video/"
echo "fake" > "$OUT/something.md"
set +e
out1=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT" 2>&1)
rc1=$?
set -e
assert_eq "已存在 + 不带 --resume → exit != 0" "1" "$rc1"
assert_contains "已存在 + 不带 --resume → 报错" "已存在" "$out1"

# ── 2. --resume 复用：能跑完、article.md 存在 ──
set +e
out2=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT" --resume 2>&1)
rc2=$?
set -e
assert_eq "已存在 + --resume → exit 0" "0" "$rc2"
assert_file_exists "--resume 后 article.md 存在" "$OUT/article.md"

# ── 3. status 子命令存在 + 输出 meta 信息 ──
set +e
status_out=$(bash "$SCRIPT" status "$OUT" 2>&1)
rc_status=$?
set -e
assert_eq "status: exit 0" "0" "$rc_status"
assert_contains "status: 含 title" "title:" "$status_out"
assert_contains "status: 含 theme" "kraft-paper" "$status_out"
assert_contains "status: 含 provider" "minimax" "$status_out"
assert_contains "status: 含 image_provider" "image_provider" "$status_out"
assert_contains "status: 列 article.md" "✓ article.md" "$status_out"
assert_contains "status: 列 STATE.md" "STATE.md" "$status_out"

# ── 4. STATE.md 自动生成 ──
assert_file_exists "STATE.md 落盘" "$OUT/STATE.md"
assert_contains "STATE.md: 当前阶段" "当前阶段" "$(cat "$OUT/STATE.md")"
assert_contains "STATE.md: Phase 0 完成" "Phase 0" "$(cat "$OUT/STATE.md")"
assert_contains "STATE.md: 下一步" "下一步" "$(cat "$OUT/STATE.md")"
assert_contains "STATE.md: minimax" "minimax" "$(cat "$OUT/STATE.md")"

# ── 5. router: status 是已注册子命令（其它脚本实现了）──
assert_file_exists "router: commands/status.sh 已注册" "scripts/commands/status.sh"
assert_grep    "router: status.sh 定义 cmd_status" "^cmd_status" "scripts/commands/status.sh"
# 试调一个会 die 的子命令（如有）：不依赖其它子命令，只验 status 自身能跑
set +e
bash "$SCRIPT" status /nonexistent/path 2>&1
rc5=$?
set -e
assert_eq "router: status /nonexistent → exit != 0" "1" "$rc5"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-resume-bug"
