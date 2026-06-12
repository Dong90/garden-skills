#!/usr/bin/env bash
# status 子命令：看 my-video/ 当前状态
#   - title / theme / lang / provider（meta.json）
#   - 当前 phase（state.json）
#   - 4 步剧本进度（plan / run / status / record）
#   - 5 步子任务进度（init / 写稿 / 验收 / 多媒体 / 录屏）
#   - 章节 / 音频 / 图片数
#   - 快照列表（最近 5 个）

cmd_status() {
  local target="${1:-my-video}"
  local verbose=0
  shift 2>/dev/null || true
  for arg in "$@"; do
    [[ "$arg" == "--verbose" || "$arg" == "-v" ]] && verbose=1
  done
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  [[ -f "$target/meta.json" ]] || { echo "✗ $target/meta.json 缺失"; return 1; }

  local SKILL_DIR
  SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  # shellcheck disable=SC1091
  source "$SKILL_DIR/scripts/commands/_snapshot.sh"

  python3 - "$target" "$verbose" <<'PYEOF'
import json, os, sys
root, verbose = sys.argv[1], sys.argv[2] == "1"
meta = json.load(open(f"{root}/meta.json"))
state_path = f"{root}/.book-video/state.json"
state = json.load(open(state_path)) if os.path.exists(state_path) else {}
phase = state.get("phase", "P0")
phase_status = state.get("phase_status", "?")

print(f"📁 {root}/")
print(f"  title:    {meta.get('title', '?')}")
print(f"  theme:    {meta.get('theme', '?')}")
print(f"  lang:     {meta.get('lang', '?')}")
print(f"  provider: {meta.get('provider', '?')} (TTS)")
print(f"  image_provider: {meta.get('image_provider', '?')}")
print(f"  episodes: {meta.get('episodes', 1)}")
print(f"  est_min:  {meta.get('est_min', '?')}")
print(f"  words:    {meta.get('words', '?')}")
print()

# 4 步剧本
plan_done = "·"
run_done = "·"
status_done = "·"
record_done = "·"
if phase != "P0" or phase_status != "?":
    plan_done = "✓"  # plan 总是可做（read-only）
    if phase in ("P1", "P2", "P3", "P4"):
        run_done = "✓"
    if phase in ("P3", "P4"):
        record_done = "✓"
# 4 步剧本 = plan / run / status / record
print("📊 4 步剧本")
print(f"  [{plan_done}] plan   [{run_done}] run   [{status_done}] status   [{record_done}] record")
print()

# 5 步子任务
script_exists = os.path.exists(f"{root}/script.md")
outline_exists = os.path.exists(f"{root}/outline.md")
chap_root = f"{root}/presentation/src/chapters"
chap_count = len([d for d in os.listdir(chap_root) if os.path.isdir(f"{chap_root}/{d}")]) if os.path.isdir(chap_root) else 0

init_done = phase in ("P0", "P1", "P2", "P3", "P4") and phase_status == "done"
write_done = script_exists and outline_exists
verify_done = phase in ("P1", "P2", "P3", "P4")
media_done = phase in ("P2", "P3", "P4") and phase_status == "done"
record_status = phase in ("P3", "P4")

def mark(b): return "✓" if b else "▱"
print("📊 5 步子任务")
print(f"  {mark(init_done)} 1. init             (phase={phase}, status={phase_status})")
print(f"  {mark(write_done)} 2. 写稿             (script.md={script_exists}, outline.md={outline_exists})")
print(f"  {mark(verify_done)} 3. 验收             (selftest/judge)")
print(f"  {mark(media_done)} 4. 多媒体           (audio + image)")
print(f"  {mark(record_status)} 5. 录屏             (npm run dev + QuickTime)")
print()

# 章节 / 音频 / 图片
if os.path.isdir(chap_root):
    print(f"📁 章节: {chap_count} 个 (在 {chap_root})")
    if verbose:
        for c in sorted(os.listdir(chap_root)):
            narr = f"{chap_root}/{c}/narrations.ts"
            marker = "✓" if os.path.exists(narr) else "·"
            print(f"    {marker} {c}")
else:
    print("📁 章节: 0 个 (presentation/ 未脚手架或 src/chapters/ 不存在)")

audio_dir = f"{root}/presentation/public/audio"
n_audio = sum(1 for _, _, files in os.walk(audio_dir) for f in files if f.endswith(".mp3")) if os.path.isdir(audio_dir) else 0
img_dir = f"{root}/presentation/public/images"
n_img = sum(1 for _, _, files in os.walk(img_dir) for f in files if f.endswith((".png", ".jpg"))) if os.path.isdir(img_dir) else 0
print(f"🎙  音频: {n_audio} 段")
print(f"🖼  图片: {n_img} 张")
print()

# 快照
snap_dir = f"{root}/.book-video/snapshots"
if os.path.isdir(snap_dir):
    snaps = sorted([f for f in os.listdir(snap_dir) if f.endswith(".tar.gz")], reverse=True)
    if snaps:
        print(f"📦 快照: {len(snaps)} 个 (最新 5 个)")
        for s in snaps[:5]:
            size = os.path.getsize(f"{snap_dir}/{s}") // 1024
            print(f"    • {s} ({size}KB)")
        print()
        print("  回退: chapter-to-video.sh rollback", root, "--to=P<n> --yes")
    else:
        print("📦 快照: 0 个")
else:
    print("📦 快照: 0 个")
print()

# next_action
print(f"⏭  下一步: {state.get('next_action', '?')}")
PYEOF
}
