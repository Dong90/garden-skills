#!/usr/bin/env bash
# status 子命令：看 my-video/ 当前状态
cmd_status() {
  local target="${1:-my-video}"
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  [[ -f "$target/meta.json" ]] || { echo "✗ $target/meta.json 缺失"; return 1; }
  python3 - "$target" <<'PYEOF'
import json, os, sys
root = sys.argv[1]
meta = json.load(open(f"{root}/meta.json"))
print(f"📁 {root}/")
print(f"  title:    {meta.get('title', '?')}")
print(f"  theme:    {meta.get('theme', '?')}")
print(f"  lang:     {meta.get('lang', '?')}")
print(f"  provider: {meta.get('provider', '?')} (TTS)")
print(f"  image_provider: {meta.get('image_provider', '?')}")
print(f"  episodes: {meta.get('episodes', 1)}")
print(f"  est_min:  {meta.get('est_min', '?')}")
print(f"  words:    {meta.get('words', '?')}")
chap_root = f"{root}/presentation/src/chapters"
if os.path.isdir(chap_root):
    chapters = sorted(os.listdir(chap_root))
    print(f"  chapters: {len(chapters)} 个")
    for c in chapters:
        narr = f"{chap_root}/{c}/narrations.ts"
        marker = "✓" if os.path.exists(narr) else "·"
        print(f"    {marker} {c}")
print()
artifacts = ["article.md", "BOOK-CHAPTER.md", "SCRIPT-STYLE.md", "OUTLINE-FORMAT.md", "CHAPTER-CRAFT.md", "meta.json", "STATE.md"]
for a in artifacts:
    p = f"{root}/{a}"
    marker = "✓" if os.path.exists(p) else "·"
    print(f"  {marker} {a}")
print()
audio_dir = f"{root}/presentation/public/audio"
if os.path.isdir(audio_dir):
    n = sum(1 for _, _, files in os.walk(audio_dir) for f in files if f.endswith(".mp3"))
    print(f"  audio: {n} 个 mp3 段")
img_dir = f"{root}/presentation/public/images"
if os.path.isdir(img_dir):
    n = sum(1 for _, _, files in os.walk(img_dir) for f in files if f.endswith((".png", ".jpg")))
    print(f"  images: {n} 张")
PYEOF
}
