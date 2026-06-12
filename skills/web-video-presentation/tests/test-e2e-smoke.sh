#!/usr/bin/env bash
# T23: 端到端冒烟（init → status → selftest → pipeline --dry-run）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }

# 真实短章节（公版《匆匆》节选）
TMPDIR=$(make_tmpdir)
CHAP="$TMPDIR/test-chapter.md"
cat > "$CHAP" <<'EOF'
# 匆匆 · 朱自清

燕子去了，有再来的时候；杨柳枯了，有再青的时候；桃花谢了，有再开的时候。
但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？
我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。
像针尖上一滴水滴在大海里，我的日子滴在时间的流里，没有声音，也没有影子。
我不禁头涔涔而泪潸潸了。
EOF

# fake scaffold + fake npm
FAKE_BIN="$TMPDIR/fakebin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/scaffold" <<'EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOF
chmod +x "$FAKE_BIN/scaffold"
cat > "$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
echo "(fake npm) $*"; exit 0
EOF
chmod +x "$FAKE_BIN/npm"

# ── 1. 跑 init ──
OUT="$TMPDIR/my-video"
WVP_SCAFFOLD_SH="$FAKE_BIN/scaffold" bash "$SCRIPT" "$CHAP" --out="$OUT" 2>&1 >/dev/null
assert_dir_exists  "e2e: init 创建 my-video/"          "$OUT"
assert_file_exists "e2e: init 落盘 article.md"          "$OUT/article.md"
assert_file_exists "e2e: init 落盘 meta.json"           "$OUT/meta.json"
assert_file_exists "e2e: init 落盘 STATE.md"            "$OUT/STATE.md"
assert_file_exists "e2e: init 落盘 BOOK-CHAPTER.md"    "$OUT/BOOK-CHAPTER.md"

# ── 2. 写 fixture script.md + outline.md ──
cat > "$OUT/script.md" <<'EOF'
# 口播稿

燕子去了，有再来的时候。

---

杨柳枯了，有再青的时候。

---

桃花谢了，有再开的时候。

---

但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？

---

我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。

---

像针尖上一滴水滴在大海里，我的日子滴在时间的流里，没有声音，也没有影子。

---

我不禁头涔涔而泪潸潸了。
EOF

cat > "$OUT/outline.md" <<'EOF'
# Outline

## 1. opening — 匆匆（7 steps · ~30s）

**信息池**：
- 时间锚："燕子去了有再来的时候" —— article L1
- 数字：八千多日子 —— article L3
- 引用：「头涔涔而泪潸潸」 —— article L5

**场景卡**：
- 主场景：春天 / 庭院 / 阳光 / 微风
- 关键物件：燕子 / 杨柳 / 桃花
- 在场角色：作者（独白）
- 氛围基线：怀旧 / 流逝感

**开发计划**：
- step 1 — "燕子去了，有再来的时候。"
- step 2 — "杨柳枯了，有再青的时候。"
- step 3 — "桃花谢了，有再开的时候。"
- step 4 — "但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？"
- step 5 — "我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。"
- step 6 — "像针尖上一滴水滴在大海里..."
- step 7 — "我不禁头涔涔而泪潸潸了。"

**摘句池**：
- "燕子去了，有再来的时候"
- "我们的日子为什么一去不复返呢"
- "我不禁头涔涔而泪潸潸了"
EOF

# ── 3. 跑 status ──
set +e
status_out=$(bash "$SCRIPT" status "$OUT" 2>&1)
rc_status=$?
set -e
assert_eq "e2e: status exit 0" "0" "$rc_status"
assert_contains "e2e: status 含 title"     "title:"     "$status_out"
assert_contains "e2e: status 含 theme"     "kraft-paper" "$status_out"
assert_contains "e2e: status 含 lang"      "zh"         "$status_out"
assert_contains "e2e: status 含 provider"  "minimax"    "$status_out"
assert_contains "e2e: status 列 article"   "✓ article.md" "$status_out"
assert_contains "e2e: status 列 STATE"     "STATE.md"   "$status_out"

# ── 4. 跑 selftest（5/5 应通过）──
set +e
selftest_out=$(bash "$SCRIPT" selftest "$OUT" 2>&1)
rc_selftest=$?
set -e
assert_eq "e2e: selftest 5/5 → exit 0" "0" "$rc_selftest"
assert_contains "e2e: selftest 输出 5/5" "5/5" "$selftest_out"

# ── 5. 跑 pipeline --dry-run（4 步列出）──
set +e
pipeline_out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" pipeline "$OUT" --dry-run 2>&1)
rc_pipe=$?
set -e
assert_eq "e2e: pipeline --dry-run exit 0" "0" "$rc_pipe"
for step in "extract-narrations" "synthesize-audio" "extract-images" "synthesize-images"; do
  assert_contains "e2e: pipeline 列出 $step" "$step" "$pipeline_out"
done

# ── 6. 验证 meta.json 字段 ──
assert_contains "e2e: meta.json title" "匆匆" "$(cat "$OUT/meta.json")"
assert_contains "e2e: meta.json theme" "kraft-paper" "$(cat "$OUT/meta.json")"
assert_contains "e2e: meta.json image_provider" "minimax" "$(cat "$OUT/meta.json")"

# ── 7. 验证 STATE.md 内容 ──
assert_contains "e2e: STATE.md 当前阶段"  "当前阶段"  "$(cat "$OUT/STATE.md")"
assert_contains "e2e: STATE.md Phase 0"   "Phase 0"   "$(cat "$OUT/STATE.md")"
assert_contains "e2e: STATE.md 下一步"    "下一步"    "$(cat "$OUT/STATE.md")"

rm -rf "$TMPDIR"
print_summary "test-e2e-smoke"
