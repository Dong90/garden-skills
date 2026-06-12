#!/usr/bin/env bash
# T27: snapshot / rollback —— 任意 phase 可回退
#   1. snapshot <target> --phase=P0     → 写 tar.gz 到 .book-video/snapshots/
#   2. snapshots <target>               → 列出快照
#   3. rollback <target> --to=P0 --yes  → 从 P0 快照恢复
#   4. rollback 后 state.json.phase = P0
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
TMPDIR=$(make_tmpdir)
FAKE_BIN="$TMPDIR/fakebin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/scaffold" <<'EOS'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOS
chmod +x "$FAKE_BIN/scaffold"
cat > "$FAKE_BIN/npm" <<'EOS'
#!/usr/bin/env bash
echo "(fake npm) $*"; exit 0
EOS
chmod +x "$FAKE_BIN/npm"

CHAP="$TMPDIR/test-chapter.md"
cat > "$CHAP" <<'EOS'
# 测试章节

这是测试文本。
EOS

OUT="$TMPDIR/my-video"

# ── 1. init ──
WVP_SCAFFOLD_SH="$FAKE_BIN/scaffold" PATH="$FAKE_BIN:$PATH" \
  bash "$SCRIPT" "$CHAP" --out="$OUT" 2>&1 >/dev/null
assert_dir_exists "init: 创建 $OUT" "$OUT"
assert_file_exists "init: 写 state.json" "$OUT/.book-video/state.json"

# ── 2. 写 script.md + outline.md（模拟 P1 写稿完成）──
cat > "$OUT/script.md" <<'EOS'
# 稿子

测试
---
EOS
cat > "$OUT/outline.md" <<'EOS'
# Outline

## 场景卡
- 主场景：测试
- 物件：笔
- 在场角色：作者

## 摘句池
- "测试"
- "文本"
EOS

# ── 3. snapshot P0（init done 状态）──
out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" snapshot my-video --phase=P0 2>&1 || true)
assert_contains "snapshot P0: 提示成功" "phase-P0" "$out"

snap_dir="$OUT/.book-video/snapshots"
assert_dir_exists "snapshots/ 目录创建" "$snap_dir"

p0_snap=$(ls "$snap_dir"/phase-P0-*.tar.gz 2>/dev/null | head -1)
assert_file_exists "P0 快照存在" "$p0_snap"

# ── 4. snapshot P1 ──
out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" snapshot my-video --phase=P1 2>&1 || true)
assert_contains "snapshot P1: 提示成功" "phase-P1" "$out"
p1_snap=$(ls "$snap_dir"/phase-P1-*.tar.gz 2>/dev/null | head -1)
assert_file_exists "P1 快照存在" "$p1_snap"

# ── 5. snapshots 列表 ──
out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" snapshots my-video 2>&1 || true)
assert_contains "snapshots 列表: 显示 P0" "P0" "$out"
assert_contains "snapshots 列表: 显示 P1" "P1" "$out"

# ── 6. rollback --to=P0 --yes ──
out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" rollback my-video --to=P0 --yes 2>&1 || true)
assert_contains "rollback: 提示恢复" "P0" "$out"

# 7. state.phase 应回 P0
phase=$(python3 -c "import json; print(json.load(open('$OUT/.book-video/state.json')).get('phase', '?'))")
assert_eq "rollback 后 state.phase" "P0" "$phase"

print_summary "test-snapshot-rollback"
