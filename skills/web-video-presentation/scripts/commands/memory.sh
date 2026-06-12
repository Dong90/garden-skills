#!/usr/bin/env bash
# memory 子命令：tweaks.log + preferences.json

# 路径默认 ~/.wvp/memory/，可被 WVP_MEMORY_DIR 覆盖
cmd_memory_dir() {
  echo "${WVP_MEMORY_DIR:-$HOME/.wvp/memory}"
}

# 记录一条 tweak 到 tweaks.log
#   $1: tweak 描述（如 "audio speed 0.85x"）
#   $2: project 名（可选，默认 "unknown"）
cmd_memory_record() {
  local tweak="$1"
  local project="${2:-unknown}"
  [[ -z "$tweak" ]] && { echo "✗ tweak 不能为空" >&2; return 1; }
  local dir
  dir=$(cmd_memory_dir)
  mkdir -p "$dir"
  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  echo "$ts [$project] $tweak" >> "$dir/tweaks.log"
}

# 从 tweaks.log 推断偏好（出现 ≥ 2 次的（type, value））
# 输出 key=value 行
cmd_memory_infer() {
  local dir
  dir=$(cmd_memory_dir)
  [[ -f "$dir/tweaks.log" ]] || return 0

  local _script
  _script=$(mktemp -t wvp-mem-XXXXXX.py)
  cat > "$_script" <<'PYTHON'
import sys, re
from collections import Counter
type_value_count = Counter()
with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        m = re.match(r"^[\d\-T:Z]+ \[[^\]]+\] (.+)$", line)
        if not m:
            continue
        tweak = m.group(1).strip()
        for pattern, t in [
            ("audio speed", "audio_speed"),
            ("bgm volume", "bgm_volume"),
            ("subtitle", "subtitle"),
            ("theme", "theme"),
            ("voice", "voice"),
            ("pace", "pace"),
        ]:
            if pattern in tweak:
                value = tweak.replace(pattern, "").strip()
                type_value_count[(t, value)] += 1
                break
    type_best = {}
    for (t, v), n in type_value_count.items():
        if n >= 2:
            if t not in type_best or n > type_value_count[type_best[t]]:
                type_best[t] = (t, v)
    for t, (_, v) in type_best.items():
        print(f"{t}={v}")
PYTHON
  python3 "$_script" "$dir/tweaks.log"
  rm -f "$_script"
}

# 把推断结果写到 preferences.json（value 是字符串）
cmd_memory_write_preferences() {
  local dir
  dir=$(cmd_memory_dir)
  mkdir -p "$dir"
  local inferred
  inferred=$(cmd_memory_infer)
  local _script
  _script=$(mktemp -t wvp-mem-XXXXXX.py)
  cat > "$_script" <<'PYTHON'
import sys, json
path = sys.argv[1]
inferred = sys.argv[2]
prefs = {}
for line in inferred.splitlines():
    if "=" in line:
        k, v = line.split("=", 1)
        prefs[k] = v
with open(path, "w", encoding="utf-8") as f:
    json.dump(prefs, f, ensure_ascii=False, indent=2)
    f.write("\n")
PYTHON
  python3 "$_script" "$dir/preferences.json" "$inferred"
  rm -f "$_script"
}

# 读 preferences.json
# 输出 key=value 行
cmd_memory_read_preferences() {
  local dir
  dir=$(cmd_memory_dir)
  [[ -f "$dir/preferences.json" ]] || return 0
  local _script
  _script=$(mktemp -t wvp-mem-XXXXXX.py)
  cat > "$_script" <<'PYTHON'
import sys, json
with open(sys.argv[1], encoding="utf-8") as f:
    prefs = json.load(f)
for k, v in prefs.items():
    print(f"{k}={v}")
PYTHON
  python3 "$_script" "$dir/preferences.json"
  rm -f "$_script"
}
