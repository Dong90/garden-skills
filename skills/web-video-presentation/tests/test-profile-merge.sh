#!/usr/bin/env bash
# T1: profile 组合
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# ── 1. 文件契约 ──
assert_file_exists "scripts/commands/profile.sh 存在" "scripts/commands/profile.sh"
assert_grep "profile.sh: 定义 cmd_profile_resolve" "^cmd_profile_resolve" "scripts/commands/profile.sh"

# ── 2. 准备 profile fixture ──
TMPDIR=$(make_tmpdir)
mkdir -p "$TMPDIR/profiles"

cat > "$TMPDIR/profiles/蒙学.md" <<'EOF'
---
name: 蒙学
audience: kids-3-6
theme: kraft-paper
pace: 极慢
visual: 书法 + 山水
bgm: 古琴 + 童声吟唱
references: 央视《百家讲坛》少年版
禁忌: 不现代化
---
exemplar: "人之初，性本善"
EOF

cat > "$TMPDIR/profiles/整体养育.md" <<'EOF'
---
name: 整体养育
audience: kids-7-12
voice: 温柔女声
approach: 情景剧 + 家长视角
禁忌: 不说教 / 不比较
---
exemplar: "你刚才的感受是...?"
EOF

cat > "$TMPDIR/profiles/base-kids.md" <<'EOF'
---
name: base-kids
audience: kids-7-12
theme: bauhaus-bold
pace: 250
---
基础 kids profile
EOF

cat > "$TMPDIR/profiles/inherits-kids.md" <<'EOF'
---
name: inherits-kids
inherits: base-kids
voice: 童声
---
继承 kids
EOF

# ── helper: 跑 resolve 拿输出 ──
run_resolve() {
  local spec="$1"
  WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c '
    source scripts/commands/profile.sh
    cmd_profile_resolve "$1" 2>&1
  ' _ "$spec"
}

# ── 3. 合并（蒙学 + 整体养育）──
out_merge=$(run_resolve "蒙学,整体养育")
assert_contains "合并: 蒙学的 audience 保留" "kids-3-6" "$out_merge"
assert_contains "合并: 蒙学的 theme 保留" "kraft-paper" "$out_merge"
assert_contains "合并: 整体养育的 voice 注入" "温柔女声" "$out_merge"
assert_contains "合并: 整体养育的 approach 注入" "情景剧" "$out_merge"
# 禁忌 concat
assert_contains "合并: 禁忌不现代化" "不现代化" "$out_merge"
assert_contains "合并: 禁忌不说教" "不说教" "$out_merge"

# ── 4. inherits ──
out_inh=$(run_resolve "inherits-kids")
assert_contains "inherits: 父 audience" "kids-7-12" "$out_inh"
assert_contains "inherits: 父 theme" "bauhaus-bold" "$out_inh"
assert_contains "inherits: 父 pace=250" "250" "$out_inh"
assert_contains "inherits: 子 voice=童声" "童声" "$out_inh"

# ── 5. 单 profile ──
out_single=$(run_resolve "蒙学")
assert_contains "单 profile: theme=kraft-paper" "kraft-paper" "$out_single"
assert_contains "单 profile: 禁忌不现代化" "不现代化" "$out_single"

# ── 6. 缺失 profile ──
set +e
WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c '
  source scripts/commands/profile.sh
  cmd_profile_resolve "不存在的" 2>&1
' > /tmp/merge4.out 2>&1
rc4=$?
set -e
assert_eq "缺失: exit 1" "1" "$rc4"
assert_contains "缺失: 报错" "找不到" "$(cat /tmp/merge4.out)"

# ── 7. 缺 name ──
cat > "$TMPDIR/profiles/noname.md" <<'EOF'
---
audience: kids-3-6
---
EOF
set +e
WVP_PROFILE_PATH="$TMPDIR/profiles" bash -c '
  source scripts/commands/profile.sh
  cmd_profile_resolve "noname" 2>&1
' > /tmp/merge5.out 2>&1
rc5=$?
set -e
assert_eq "缺 name: exit 1" "1" "$rc5"
assert_contains "缺 name: 报错含 name" "name" "$(cat /tmp/merge5.out)"

# ── 8. search path: 全局能找到 ──
mkdir -p "$TMPDIR/global"
mkdir -p "$TMPDIR/global/.wvp/profiles"
cat > "$TMPDIR/global/.wvp/profiles/global-only.md" <<'EOF'
---
name: global-only
audience: kids-3-6
theme: pastel-dream
---
EOF
out_g=$(WVP_PROFILE_PATH="$TMPDIR/global/.wvp/profiles" bash -c '
  source scripts/commands/profile.sh
  cmd_profile_resolve "global-only" 2>&1
')
assert_contains "全局: pastel-dream 找到" "pastel-dream" "$out_g"

# ── 9. search path: 项目级覆盖全局 ──
mkdir -p "$TMPDIR/proj/.wvp/profiles"
mkdir -p "$TMPDIR/global/.wvp/profiles"
cat > "$TMPDIR/proj/.wvp/profiles/dual.md" <<'EOF'
---
name: dual
theme: bauhaus-bold
---
EOF
cat > "$TMPDIR/global/.wvp/profiles/dual.md" <<'EOF'
---
name: dual
theme: pastel-dream
---
EOF
export PROFILE_SH="$(pwd)/scripts/commands/profile.sh"
out_d=$(cd "$TMPDIR/proj" && WVP_PROFILE_PATH="$TMPDIR/global/.wvp/profiles" bash -c '
  source "$PROFILE_SH"
  result=$(cmd_profile_resolve "dual" 2>&1)
  echo "$result"
')
assert_contains "优先级: 项目级 (bauhaus-bold) 覆盖全局" "bauhaus-bold" "$out_d"
assert_not_contains "优先级: 不用全局的 (pastel-dream)" "pastel-dream" "$out_d"

rm -rf "$TMPDIR"
print_summary "test-profile-merge"
