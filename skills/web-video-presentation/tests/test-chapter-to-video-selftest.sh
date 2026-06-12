#!/usr/bin/env bash
# T21: chapter-to-video.sh selftest 子命令
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }
[[ -f "scripts/commands/selftest.sh" ]] || { echo "  ✗ scripts/commands/selftest.sh missing"; exit 1; }
[[ -f "references/CHECKLIST.md" ]] || { echo "  ✗ references/CHECKLIST.md missing"; exit 1; }

# ── 1. 文件契约 ──
assert_grep "selftest.sh: 定义 cmd_selftest" "^cmd_selftest" "scripts/commands/selftest.sh"
assert_grep "CHECKLIST.md: 5 层自检" "5 层" "references/CHECKLIST.md"
assert_grep "CHECKLIST.md: 信息保留度" "信息保留度" "references/CHECKLIST.md"
assert_grep "CHECKLIST.md: 去 AI 味" "去 AI 味" "references/CHECKLIST.md"

TMPDIR=$(make_tmpdir)
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOF
chmod +x "$SCAFFOLD_STUB"

# ── 2. 准备合格 fixture（5/5 应通过）──
GOOD="$TMPDIR/good"
mkdir -p "$GOOD"
cat > "$GOOD/article.md" <<'ART'
# 测试章节

这是一段足够长的测试内容。中文要有 200+ 字才能让信息保留度算得有意义。
所以这里要写很多字。燕子去了有再来的时候，杨柳枯了有再青的时候，
桃花谢了有再开的时候。聪明的你告诉我，我们的日子为什么一去不复返呢。
我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。
ART
cat > "$GOOD/script.md" <<'SCR'
# 口播稿

燕子去了，有再来的时候。

---

杨柳枯了，有再青的时候。

---

桃花谢了，有再开的时候。

---

但是聪明的，你告诉我，我们的日子为什么一去不复返呢。

---

我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。

---

在默默里算着，八千多日子已经从我手中溜去，像针尖上一滴水滴在大海里，我的日子滴在时间的流里，没有声音，也没有影子。
SCR
cat > "$GOOD/outline.md" <<'OUT'
# Outline

## 1. opening

**信息池**：
- 时间锚：燕子去了 —— article L1

**场景卡**：
- 主场景：春天庭院
- 关键物件：燕子
- 在场角色：作者
- 氛围基线：怀旧

**摘句池**：
- "燕子去了，有再来的时候"
- "杨柳枯了，有再青的时候"
- "桃花谢了，有再开的时候"
OUT

# 跑 selftest
set +e
out_good=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" selftest "$GOOD" 2>&1)
rc_good=$?
set -e
assert_eq "selftest: 5/5 通过 → exit 0" "0" "$rc_good"
assert_contains "selftest: 含 '5/5'" "5/5" "$out_good"
assert_contains "selftest: 含'第 1 层'" "第 1 层" "$out_good"
assert_contains "selftest: 含'第 5 层'" "第 5 层" "$out_good"

# ── 3. AI 味检测 ──
BAD="$TMPDIR/bad"
mkdir -p "$BAD"
cp "$GOOD/article.md" "$BAD/article.md"
cat > "$BAD/script.md" <<'SCR'
# 口播稿

说白了，这个东西本质上就是底层逻辑。

---

恰恰相反，正因为这个，所以我们才说归根结底是这样。
SCR
cp "$GOOD/outline.md" "$BAD/outline.md"
set +e
out_bad=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" selftest "$BAD" 2>&1)
rc_bad=$?
set -e
assert_eq "selftest: AI 味 → exit != 0" "1" "$rc_bad"
assert_contains "selftest: 输出含'AI 高频词'" "AI 高频词" "$out_bad"

# ── 4. outline 缺字段检测 ──
MISSING="$TMPDIR/missing"
mkdir -p "$MISSING"
cp "$GOOD/article.md" "$MISSING/article.md"
cp "$GOOD/script.md"  "$MISSING/script.md"
cat > "$MISSING/outline.md" <<'OUT'
# Outline
## 1. ch1
信息池：...（无场景卡 / 无摘句池）
OUT
set +e
out_missing=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" selftest "$MISSING" 2>&1)
rc_missing=$?
set -e
assert_eq "selftest: 缺 outline 字段 → exit != 0" "1" "$rc_missing"

# ── 5. 缺文件检测 ──
NOFILE="$TMPDIR/nofile"
mkdir -p "$NOFILE"
echo "# x" > "$NOFILE/article.md"
# script.md + outline.md 都没有
set +e
out_nofile=$(WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" bash "$SCRIPT" selftest "$NOFILE" 2>&1)
rc_nofile=$?
set -e
assert_eq "selftest: 缺文件 → exit != 0" "1" "$rc_nofile"
assert_contains "selftest: 报错含'script.md 不存在'" "script.md 不存在" "$out_nofile"

rm -rf "$TMPDIR"
print_summary "test-chapter-to-video-selftest"
