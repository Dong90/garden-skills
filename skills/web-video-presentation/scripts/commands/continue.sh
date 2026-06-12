#!/usr/bin/env bash
# continue 子命令：test 模式后接着跑 audio + record
cmd_continue() {
  local target="${1:-my-video}"
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  [[ -f "$target/.book-video/state.json" ]] || { echo "✗ state.json 不存在（先跑 init）"; return 1; }
  
  local mode test_flag audio record
  mode=$(python3 -c "import json; print(json.load(open('$target/.book-video/state.json'))['mode'])" 2>/dev/null || echo "full")
  test_flag=$(python3 -c "import json; print(json.load(open('$target/.book-video/state.json'))['test'])" 2>/dev/null || echo "False")
  audio=$(python3 -c "import json; print(json.load(open('$target/.book-video/state.json'))['audio'])" 2>/dev/null || echo "True")
  record=$(python3 -c "import json; print(json.load(open('$target/.book-video/state.json'))['record'])" 2>/dev/null || echo "True")
  
  echo "▸ continue · target=$target"
  echo "  mode: $mode"
  echo "  audio: $audio"
  echo "  record: $record"
  echo
  
  if [[ "$test_flag" != "True" ]]; then
    echo "  (不是 test 模式，无需 continue——直接跑 init 即可)"
    return 0
  fi
  
  # 跑 audio
  if [[ "$audio" == "False" ]]; then
    echo "── 1/2 ── audio (provider=${PRESENTATION_TTS:-minimax})"
    cd "$target/presentation" || return 1
    if PRESENTATION_TTS="${PRESENTATION_TTS:-minimax}" npm run synthesize-audio 2>&1 | sed 's/^/  /'; then
      # 更新 state.json
      python3 -c "
import json
p = '$target/.book-video/state.json'
d = json.load(open(p))
d['audio'] = True
open(p, 'w').write(json.dumps(d, ensure_ascii=False, indent=2) + chr(10))
"
      echo "  ✓ audio 完成"
    else
      echo "  ✗ audio 失败"
      return 1
    fi
  fi
  
  # 跑 record
  if [[ "$record" == "False" ]]; then
    echo "── 2/2 ── record (ffmpeg)"
    if PRESENTATION_RECORD=auto bash scripts/synthesize-record.sh "$target" 2>&1 | sed 's/^/  /'; then
      python3 -c "
import json
p = '$target/.book-video/state.json'
d = json.load(open(p))
d['record'] = True
d['mode'] = 'full'
d['test'] = False
open(p, 'w').write(json.dumps(d, ensure_ascii=False, indent=2) + chr(10))
"
      echo "  ✓ record 完成"
    else
      echo "  ✗ record 失败"
      return 1
    fi
  fi
  
  echo
  echo "✓ continue 完成。可在 $target/recording/ 找到 final.mp4"
}
