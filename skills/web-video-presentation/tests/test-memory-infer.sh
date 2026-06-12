#!/usr/bin/env bash
# T3: memory 推断（tweaks.log + preferences.json）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# ── 1. 文件契约 ──
assert_file_exists "scripts/commands/memory.sh 存在" "scripts/commands/memory.sh"
assert_grep "memory.sh: 定义 cmd_memory_record" "^cmd_memory_record" "scripts/commands/memory.sh"
assert_grep "memory.sh: 定义 cmd_memory_infer" "^cmd_memory_infer" "scripts/commands/memory.sh"

# ── 2. 准备 tweaks.log fixture ──
TMPDIR=$(make_tmpdir)
export WVP_MEMORY_DIR="$TMPDIR/memory"
mkdir -p "$WVP_MEMORY_DIR"

# 模拟 5 个项目的 tweaks.log（用户历史偏好）
# - 4/5 把 audio 改到 0.85x
# - 3/5 把 BGM 音量调低
# - 5/5 字幕放屏中
cat > "$WVP_MEMORY_DIR/tweaks.log" <<'EOF'
2026-01-15T10:00:00 [p1] audio speed 0.85x
2026-01-15T10:01:00 [p1] subtitle center
2026-01-15T10:02:00 [p1] bgm volume low
2026-02-01T14:00:00 [p2] audio speed 0.85x
2026-02-01T14:01:00 [p2] subtitle center
2026-02-20T09:00:00 [p3] audio speed 0.85x
2026-02-20T09:01:00 [p3] subtitle center
2026-02-20T09:02:00 [p3] bgm volume low
2026-03-10T16:00:00 [p4] audio speed 0.85x
2026-03-10T16:01:00 [p4] subtitle center
2026-03-10T16:02:00 [p4] bgm volume low
2026-04-05T11:00:00 [p5] subtitle center
EOF

# ── 3. cmd_memory_infer 输出 preferences ──
out=$(WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c '
  source scripts/commands/memory.sh
  cmd_memory_infer
')
assert_contains "infer: audio_speed=0.85x" "audio_speed=0.85x" "$out"
assert_contains "infer: subtitle=center" "subtitle=center" "$out"
assert_contains "infer: bgm_volume=low" "bgm_volume=low" "$out"

# ── 4. 写 preferences.json ──
WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c '
  source scripts/commands/memory.sh
  cmd_memory_write_preferences
'
assert_file_exists "preferences.json 落盘" "$WVP_MEMORY_DIR/preferences.json"
assert_contains "preferences.json 含 audio_speed" "audio_speed" "$(cat "$WVP_MEMORY_DIR/preferences.json")"
assert_contains "preferences.json 含 subtitle" "subtitle" "$(cat "$WVP_MEMORY_DIR/preferences.json")"
assert_contains "preferences.json 含 bgm_volume" "bgm_volume" "$(cat "$WVP_MEMORY_DIR/preferences.json")"

# ── 5. cmd_memory_record 追加 ──
WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c '
  source scripts/commands/memory.sh
  cmd_memory_record "audio speed 0.85x" "my-video-test"
'
assert_file_exists "record 后 tweaks.log 仍在" "$WVP_MEMORY_DIR/tweaks.log"
LAST_LINE=$(tail -1 "$WVP_MEMORY_DIR/tweaks.log")
assert_contains "record 追加: 含 tweak" "audio speed 0.85x" "$LAST_LINE"

# ── 6. infer 阈值：单次出现不算偏好（≥2 次才记录）──
WVP_MEMORY_DIR="$(mktemp -d)/memory"
mkdir -p "$WVP_MEMORY_DIR"
echo "2026-01-01T10:00:00 [p1] rare tweak xyz" > "$WVP_MEMORY_DIR/tweaks.log"
out2=$(WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c '
  source scripts/commands/memory.sh
  cmd_memory_infer
')
# 罕见的 xyz tweak 不应出现在 preferences
assert_not_contains "infer: 罕见 tweak 不在 preferences" "xyz" "$out2"

# ── 7. 空 tweaks.log：preferences.json 应为空对象 ──
WVP_MEMORY_DIR="$(mktemp -d)/memory2"
mkdir -p "$WVP_MEMORY_DIR"
: > "$WVP_MEMORY_DIR/tweaks.log"
WVP_MEMORY_DIR="$WVP_MEMORY_DIR" bash -c '
  source scripts/commands/memory.sh
  cmd_memory_write_preferences
'
assert_file_exists "空 tweaks.log: preferences.json 落盘" "$WVP_MEMORY_DIR/preferences.json"
# 应该是空对象
EMPTY=$(python3 -c "import json; d=json.load(open('$WVP_MEMORY_DIR/preferences.json')); print(len(d))")
assert_eq "空 tweaks.log: preferences.json 是空对象" "0" "$EMPTY"

print_summary "test-memory-infer"
