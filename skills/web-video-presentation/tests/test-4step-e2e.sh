#!/usr/bin/env bash
# E2E · 4 步剧本 + 回退 完整跑通
# 用法: bash tests/test-4step-e2e.sh
# 前置: 仓库根, tmpdir 可写

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
TMPDIR=$(make_tmpdir)
CHAP="$TMPDIR/chapter.md"
OUT="$TMPDIR/my-video"

# fakebin 让 init 能跑
FAKE_BIN="$TMPDIR/fakebin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/scaffold" <<'EOS'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET/src/chapters/01-prologo"; echo '{"name":"x"}' > "$TARGET/package.json"; cat > "$TARGET/src/chapters/01-prologo/narrations.ts" <<'TS'
export const narrations = ["step 1", "step 2", "step 3"];
TS
exit 0
EOS
chmod +x "$FAKE_BIN/scaffold"
cat > "$FAKE_BIN/npm" <<'EOS'
#!/usr/bin/env bash
case "$2" in
  extract-narrations) echo '{"segments":[]}' > presentation/audio-segments.json;;
  synthesize-audio) mkdir -p presentation/public/audio; touch presentation/public/audio/1.mp3;;
  extract-images) echo '{"images":[]}' > presentation/image-prompts.json;;
  synthesize-images) mkdir -p presentation/public/images; touch presentation/public/images/cover.png;;
esac
echo "ok ($*)"; exit 0
EOS
chmod +x "$FAKE_BIN/npm"

# 短章节（够 selftest 第 1 层 ≥ 60% 信息保留）
cat > "$CHAP" <<'EOS'
# 测试章节

多年以后，奥雷里亚诺·布恩迪亚上校站在行刑队面前，准会想起父亲带他去见识冰块的那个遥远的下午。那时候的马孔多是一个只有二十户人家的小村子，泥巴和芦苇盖的屋子排在河边，河水清澈，沿着遍布石头的河床流过。
EOS

echo "═══ E2E: 4 步剧本完整跑 ═══"
echo ""

# ── 步 0 · init ──
echo "[1/9] init"
WVP_SCAFFOLD_SH="$FAKE_BIN/scaffold" PATH="$FAKE_BIN:$PATH" \
  bash "$SCRIPT" "$CHAP" --out="$OUT" 2>&1 >/dev/null
assert_dir_exists  "init: 创建 my-video/"  "$OUT"
assert_file_exists "init: 写 state.json"   "$OUT/.book-video/state.json"
phase=$(python3 -c "import json;print(json.load(open('$OUT/.book-video/state.json'))['phase'])")
assert_eq "init: state.phase" "P0" "$phase"

# ── 步 1 · plan ──
echo "[2/9] plan"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" status "$OUT" 2>&1)
assert_contains "plan: 4 步剧本" "4 步剧本" "$out"
assert_contains "plan: 5 步子任务" "5 步子任务" "$out"
assert_contains "plan: 1 快照" "1 个" "$out"

# ── 写稿（手动）──
echo "[3/9] 写稿 (script + outline)"
cat > "$OUT/script.md" <<'EOS'
# 稿子

多年以后，奥雷里亚诺·布恩迪亚上校站在行刑队面前，准会想起父亲带他去见识冰块的那个遥远的下午。
---
那时候的马孔多是一个只有二十户人家的小村子，泥巴和芦苇盖的屋子排在河边。
---
河水清澈，沿着遍布石头的河床流过。
---
EOS
cat > "$OUT/outline.md" <<'EOS'
# Outline
## 信息池
- 奥雷里亚诺
- 马孔多
## 场景卡
- 主场景：行刑队前
- 物件：冰块
- 在场角色：上校
## 摘句池
- "多年以后"
- "马孔多"
EOS
assert_file_exists "写稿: script.md"   "$OUT/script.md"
assert_file_exists "写稿: outline.md"  "$OUT/outline.md"

# ── 步 2 · run #1: 跑 selftest + judge + 推 P1 ──
echo "[4/9] run #1: 跑 selftest + judge + 推 P1"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" run "$OUT" 2>&1)
assert_contains "run #1: 5 层自检" "5 层" "$out"
assert_contains "run #1: judge 评分" "总分" "$out"
assert_contains "run #1: P1 快照" "phase-P1-" "$out"
phase=$(python3 -c "import json;print(json.load(open('$OUT/.book-video/state.json'))['phase'])")
assert_eq "run #1: 推 P1" "P1" "$phase"

# ── 步 3 · status ──
echo "[5/9] status"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" status "$OUT" 2>&1)
assert_contains "status: 2/4 步" "plan" "$out"  # 至少 plan ✓
assert_contains "status: 写稿完成" "2. 写稿" "$out"

# ── 步 2 · run #2: 跑 pipeline + 推 P2 ──
echo "[6/9] run #2: 跑 pipeline + 推 P2"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" run "$OUT" 2>&1)
assert_contains "run #2: pipeline 4 步" "extract-narrations" "$out"
assert_contains "run #2: P2 快照" "phase-P2-" "$out"
phase=$(python3 -c "import json;print(json.load(open('$OUT/.book-video/state.json'))['phase'])")
assert_eq "run #2: 推 P2" "P2" "$phase"

# ── 步 2 · run #3: 提示录屏 ──
echo "[7/9] run #3: 提示录屏"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" run "$OUT" 2>&1)
assert_contains "run #3: 提示 record" "record" "$out"

# ── 步 4 · 快照列表 ──
echo "[8/9] snapshots"
out=$(bash "$SCRIPT" snapshots "$OUT" 2>&1)
assert_contains "snapshots: P0" "P0" "$out"
assert_contains "snapshots: P1" "P1" "$out"
assert_contains "snapshots: P2" "P2" "$out"

# ── 步 5 · rollback ──
echo "[9/9] rollback --to=P0"
# 先造点改动
echo "junk" >> "$OUT/script.md"
bash "$SCRIPT" rollback "$OUT" --to=P0 --yes 2>&1 >/dev/null
phase=$(python3 -c "import json;print(json.load(open('$OUT/.book-video/state.json'))['phase'])")
assert_eq "rollback: 回到 P0" "P0" "$phase"
status=$(python3 -c "import json;print(json.load(open('$OUT/.book-video/state.json'))['phase_status'])")
assert_eq "rollback: 标记 rolled_back" "rolled_back" "$status"

print_summary "test-4step-e2e"
