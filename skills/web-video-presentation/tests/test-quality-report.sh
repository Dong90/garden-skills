#!/usr/bin/env bash
# T4: 质量报告卡（8 维度评分 + vs 历史平均 + 报告 md）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# ── 1. 文件契约 ──
assert_file_exists "scripts/commands/judge.sh 存在" "scripts/commands/judge.sh"
assert_grep "judge.sh: 定义 cmd_judge" "^cmd_judge" "scripts/commands/judge.sh"

# ── 2. 准备 my-video/ fixture ──
TMPDIR=$(make_tmpdir)
export WVP_MEMORY_DIR="$TMPDIR/memory"
mkdir -p "$WVP_MEMORY_DIR/history"
mkdir -p "$TMPDIR/my-video"
mkdir -p "$TMPDIR/my-video/.book-video"

# 写 state.json
cat > "$TMPDIR/my-video/.book-video/state.json" <<'EOF'
{
  "phase": "P0",
  "phase_status": "done",
  "mode": "full",
  "test": false,
  "audio": true,
  "images": true,
  "record": true,
  "episodes": 1,
  "audience": "kids-3-6"
}
EOF

# 写 article.md
cat > "$TMPDIR/my-video/article.md" <<'EOF'
# 三字经节选
人之初，性本善。性相近，习相远。
苟不教，性乃迁。教之道，贵以专。
EOF

# 写 script.md（含 article.md 的金句）
cat > "$TMPDIR/my-video/script.md" <<'EOF'
# 口播稿

人之初，性本善。

---

性相近，习相远。

---

苟不教，性乃迁。

---

教之道，贵以专。
EOF

# 写 outline.md
cat > "$TMPDIR/my-video/outline.md" <<'EOF'
# Outline

## 1. opening

**信息池**：人之初

**场景卡**：
- 主场景：私塾
- 关键物件：书 / 笔墨
- 在场角色：小孩

**摘句池**：
- "人之初，性本善"
- "教之道，贵以专"
EOF

# 写 brief.md
cat > "$TMPDIR/my-video/.book-video/brief.md" <<'EOF'
# Brief
audience: kids-3-6
theme: kraft-paper
style: 蒙学
EOF

# 写历史平均（audience=kids-3-6）
cat > "$WVP_MEMORY_DIR/history/kids-3-6.json" <<'EOF'
{
  "author_voice":       0.85,
  "visual_coherence":   0.78,
  "pacing":             0.75,
  "audio_quality":      0.82,
  "emotional_impact":   0.80,
  "cultural_authenticity": 0.90,
  "cinematic_match":    0.77,
  "audience_fit":       0.83
}
EOF

# ── 3. 跑 judge ──
WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c "
  source scripts/commands/judge.sh
  cmd_judge '$TMPDIR/my-video'
" > /tmp/judge.out 2>&1

assert_file_exists "judge 输出 quality-report.md" "$TMPDIR/my-video/.book-video/quality-report.md"
assert_file_exists "judge 输出 quality-report.json" "$TMPDIR/my-video/.book-video/quality-report.json"

# ── 4. JSON 8 维度都在 ──
json_content=$(cat "$TMPDIR/my-video/.book-video/quality-report.json")
for dim in author_voice visual_coherence pacing audio_quality emotional_impact cultural_authenticity cinematic_match audience_fit; do
  if [[ "$json_content" == *"\"$dim\""* ]]; then
    _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _log_pass "JSON 含 $dim"
  else
    _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
    _TEST_FAILURES+=("JSON 缺 $dim")
    _log_fail "JSON 缺 $dim"
  fi
done

# ── 5. JSON 总分（average）──
total=$(python3 -c "import json; d=json.load(open('$TMPDIR/my-video/.book-video/quality-report.json')); print(round(sum(d['scores'].values())/len(d['scores']), 2))" 2>/dev/null || echo "?")
[[ "$total" != "?" && "$total" != "0" ]] && {
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "JSON 总分算出来: $total"
}

# ── 6. 报告 md 含维度 ──
md_content=$(cat "$TMPDIR/my-video/.book-video/quality-report.md")
for dim in author_voice visual_coherence pacing audio_quality emotional_impact cultural_authenticity cinematic_match audience_fit; do
  assert_contains "report.md 含 $dim" "$dim" "$md_content"
done
assert_contains "report.md 含'改进'" "改进" "$md_content"
assert_contains "report.md 含'总分'" "总分" "$md_content"

# ── 7. author_voice 评分：script 含 article 金句 → 应得高分 ──
# 三字经 4 句都在 script.md
python3 -c "
import json
d = json.load(open('$TMPDIR/my-video/.book-video/quality-report.json'))
av = d['scores']['author_voice']
print(f'author_voice={av}')
assert av >= 0.9, f'author_voice too low: {av}'
print('PASS')
" > /tmp/av.out 2>&1
assert_contains "author_voice ≥ 0.9（金句都在）" "PASS" "$(cat /tmp/av.out)"

# ── 8. pacing 评分：script 4 step → 合理 ──
python3 -c "
import json
d = json.load(open('$TMPDIR/my-video/.book-video/quality-report.json'))
p = d['scores']['pacing']
print(f'pacing={p}')
assert p >= 0.7, f'pacing too low: {p}'
print('PASS')
" > /tmp/p.out 2>&1
assert_contains "pacing ≥ 0.7" "PASS" "$(cat /tmp/p.out)"

# ── 9. vs 历史平均：报告含比较 ──
assert_contains "report.md vs 历史" "历史" "$md_content"
# 历史 audience 没匹配的，不要 hard fail（不强求）
# 至少报告里能找到"对比"或"vs"
grep -qE "历史|vs" "$TMPDIR/my-video/.book-video/quality-report.md" && {
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "report.md 含历史对比"
}

# ── 10. missing article.md / script.md：graceful fallback ──
EMPTYDIR="$TMPDIR/empty"
mkdir -p "$EMPTYDIR/.book-video"
cat > "$EMPTYDIR/.book-video/state.json" <<'EOF'
{"audience": "kids-3-6"}
EOF
set +e
WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c "
  source scripts/commands/judge.sh
  cmd_judge '$EMPTYDIR' 2>&1
" > /tmp/empty-judge.out 2>&1
rc_empty=$?
set -e
# exit 0 或 1 都可，但不能 crash
[[ $rc_empty -eq 0 || $rc_empty -eq 1 ]] && {
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "空目录: 不 crash (exit=$rc_empty)"
}

rm -rf "$TMPDIR"
print_summary "test-quality-report"
