#!/usr/bin/env bash
# T5: profile + flag 覆盖（flag 总能覆盖 profile 的任何维度）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

SCRIPT="scripts/chapter-to-video.sh"
[[ -f "$SCRIPT" ]] || { echo "  ✗ $SCRIPT missing"; exit 1; }
[[ -f "scripts/commands/brief.sh" ]] || { echo "  ✗ scripts/commands/brief.sh missing"; exit 1; }

# ── 1. 文件契约 ──
assert_grep "brief.sh: 定义 cmd_brief_compose" "^cmd_brief_compose" "scripts/commands/brief.sh"
assert_grep "brief.sh: 定义 cmd_brief_write" "^cmd_brief_write" "scripts/commands/brief.sh"

# ── 2. 准备 profile fixture ──
TMPDIR=$(make_tmpdir)
SCAFFOLD_STUB="$TMPDIR/fake-scaffold.sh"
cat > "$SCAFFOLD_STUB" <<'EOF'
#!/usr/bin/env bash
TARGET="${1:-presentation}"; mkdir -p "$TARGET"; echo '{}' > "$TARGET/package.json"; exit 0
EOF
chmod +x "$SCAFFOLD_STUB"

mkdir -p "$TMPDIR/profiles"
cat > "$TMPDIR/profiles/蒙学.md" <<'EOF'
---
name: 蒙学
audience: kids-3-6
theme: kraft-paper
pace: 极慢
visual: 书法 + 山水
bgm: 古琴 + 童声吟唱
禁忌: 不现代化
---
exemplar: "人之初，性本善"
EOF

cat > "$TMPDIR/profiles/整体养育.md" <<'EOF'
---
name: 整体养育
voice: 温柔女声
approach: 情景剧
禁忌: 不说教
---
exemplar: "你刚才的感受是?"
EOF

# brief.sh 是被 source 后用其函数
# 测试纯函数：传环境变量 + profile + flags，输出 merged brief

# ── 3. 测试 1：纯 profile 输出 ──
out1=$(WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c "source scripts/commands/profile.sh; source scripts/commands/brief.sh; cmd_brief_compose \"蒙学\"")
assert_contains "纯 profile: theme=kraft-paper" "theme=kraft-paper" "$out1"
assert_contains "纯 profile: 禁忌=不现代化" "禁忌" "$out1"
assert_contains "纯 profile: 含 exemplar" "exemplar" "$out1"

# ── 4. 测试 2：profile 链 + flag 覆盖 ──
# 期望：theme 被覆盖为 paper-press
out2=$(WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c "source scripts/commands/profile.sh; source scripts/commands/brief.sh; cmd_brief_compose \"蒙学,整体养育\" \"theme=paper-press\" \"禁忌=禁止暴力\" \"voice=明亮女声\"")
assert_contains "覆盖: theme=paper-press" "theme=paper-press" "$out2"
assert_not_contains "覆盖: 不用 kraft-paper" "kraft-paper" "$out2"
assert_contains "覆盖: 禁忌=禁止暴力（不是 不现代化 也不说教）" "禁止暴力" "$out2"
assert_not_contains "覆盖: 不用 不现代化" "不现代化" "$out2"
assert_not_contains "覆盖: 不用 不说教" "不说教" "$out2"
assert_contains "覆盖: voice=明亮女声" "明亮女声" "$out2"
assert_not_contains "覆盖: 不用 温柔女声" "温柔女声" "$out2"
assert_contains "覆盖: 蒙学的 pace 还在" "极慢" "$out2"
assert_contains "覆盖: 蒙学的 audience 还在" "kids-3-6" "$out2"
assert_contains "覆盖: 整体养育的 approach 还在" "情景剧" "$out2"

# ── 5. 测试 3：不传 profile，纯 flag ──
out3=$(WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c "source scripts/commands/profile.sh; source scripts/commands/brief.sh; cmd_brief_compose \"\" \"audience=kids-7-12\" \"theme=warm-keynote\" \"pace=250\" \"voice=明亮女声\"")
assert_contains "纯 flag: audience=kids-7-12" "kids-7-12" "$out3"
assert_contains "纯 flag: theme=warm-keynote" "warm-keynote" "$out3"
assert_contains "纯 flag: voice=明亮女声" "明亮女声" "$out3"

# ── 6. 测试 4：空（无 profile 无 flag）—— audience=literary 默认 ──
out4=$(WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c "source scripts/commands/profile.sh; source scripts/commands/brief.sh; cmd_brief_compose \"\"")
assert_contains "空: audience=literary (默认)" "literary" "$out4"

# ── 7. 测试 5：写 brief.md ──
mkdir -p "${TMPDIR}/my-video/.book-video"; WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c "source scripts/commands/profile.sh; source scripts/commands/brief.sh; cmd_brief_write \"${TMPDIR}/my-video\" \"蒙学\" \"theme=paper-press\""

assert_file_exists "brief.md 落盘" "$TMPDIR/my-video/.book-video/brief.md"
assert_contains "brief.md 含 paper-press" "paper-press" "$(cat "$TMPDIR/my-video/.book-video/brief.md")"
assert_contains "brief.md 含 kids-3-6" "kids-3-6" "$(cat "$TMPDIR/my-video/.book-video/brief.md")"

# ── 8. 集成：完整 init 跑，看 brief.md 是否写对 ──
OUT2="$TMPDIR/integration"
WVP_SCAFFOLD_SH="$SCAFFOLD_STUB" WVP_PROFILE_PATH="$TMPDIR/profiles" bash "$SCRIPT" "tests/fixtures/cn-chapter.md" --out="$OUT2" --profile=蒙学 --theme=paper-press 2>&1 >/dev/null
assert_file_exists "init: brief.md 落盘" "$OUT2/.book-video/brief.md"
assert_contains "init: paper-press" "paper-press" "$(cat "$OUT2/.book-video/brief.md")"

# ── 9. 主脚本 --help 列出新 flags ──
help_out=$(bash "$SCRIPT" --help 2>&1)
for flag in "--theme" "--voice" "--pace" "--bgm" "--visual" "--禁忌"; do
  # --禁忌 名字不规则，跳过
  if [[ "$flag" == "--禁忌" ]]; then continue; fi
  assert_contains "--help 含 $flag" "$flag" "$help_out"
done

rm -rf "$TMPDIR"
print_summary "test-profile-flag-override"
