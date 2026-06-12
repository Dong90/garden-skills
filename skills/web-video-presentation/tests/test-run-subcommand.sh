#!/usr/bin/env bash
# T26: chapter-to-video.sh run 子命令 —— state-driven dispatch
# 不同 phase 走不同分支：
#   无 my-video  → 提示跑 init
#   P0 + 无 script → 输出"让 Cursor agent 写 script.md + outline.md"提示
#   script+outline 在 + selftest 没跑过 → 跑 selftest
#   selftest 通过 → 跑 pipeline（如 presentation/ 在）
#   pipeline 跑过 → 提示跑 /chapter-to-video-record
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"

# ── 准备 fakebin ──
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
# 匆匆 · 朱自清

燕子去了，有再来的时候。
EOS

OUT="$TMPDIR/my-video"

# ── 1. run --help 应说明 5 步子任务映射 ──
run_help=$(bash "$SCRIPT" run --help 2>&1 || true)
if [[ -n "$run_help" ]]; then
  assert_contains "run --help: 含 5 步" "5 步" "$run_help"
fi

# ── 2. 无 my-video → 提示需要 init ──
out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" run my-video 2>&1 || true)
assert_contains "无 my-video: 提示需要 init" "init" "$out"

# ── 3. init 后再 run：应输出"让 Cursor agent 写"提示 ──
WVP_SCAFFOLD_SH="$FAKE_BIN/scaffold" PATH="$FAKE_BIN:$PATH" \
  bash "$SCRIPT" "$CHAP" --out="$OUT" 2>&1 >/dev/null

phase=$(python3 -c "import json; print(json.load(open('$OUT/.book-video/state.json'))['phase'])")
assert_eq "init 后 state.phase" "P0" "$phase"

out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" run my-video 2>&1 || true)
assert_contains "P0 done, 无 script.md: 提示写稿" "script" "$out"

# ── 4. 写入 script.md + outline.md，再 run：应跑 selftest ──
cat > "$OUT/script.md" <<'EOS'
# 稿子

燕子去了，有再来的时候。
---
EOS
cat > "$OUT/outline.md" <<'EOS'
# Outline

## 场景卡
- 主场景：村口
- 物件：燕子
- 在场角色：叙述者

## 摘句池
- "燕子去了"
- "再来的时候"
EOS

out=$(cd "$TMPDIR" && bash "$OLDPWD/scripts/chapter-to-video.sh" run my-video 2>&1 || true)
assert_contains "P1 done, selftest 应跑" "5 层自检" "$out"

print_summary "test-run-subcommand"
