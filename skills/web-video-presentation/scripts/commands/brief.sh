#!/usr/bin/env bash
# brief 子命令：把 profile + flag 合成 final brief（机器可读 + 人类可读）

# 命令行 -> "key=value" 字符串（主脚本调用）
#   接受一组 --key=val 或 --key val
#   输出 "key=val" 行
cmd_brief_args_to_kv() {
  local key val
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --theme=*)    echo "theme=${1#--theme=}" ;;
      --voice=*)    echo "voice=${1#--voice=}" ;;
      --pace=*)     echo "pace=${1#--pace=}" ;;
      --bgm=*)      echo "bgm=${1#--bgm=}" ;;
      --visual=*)   echo "visual=${1#--visual=}" ;;
      --audience=*) echo "audience=${1#--audience=}" ;;
      --禁忌=*)     echo "禁忌=${1#--禁忌=}" ;;
      --禁忌)       shift; echo "禁忌=$1" ;;
      --approach=*) echo "approach=${1#--approach=}" ;;
      --theme)       shift; echo "theme=$1" ;;
      --voice)       shift; echo "voice=$1" ;;
      --pace)        shift; echo "pace=$1" ;;
      --bgm)         shift; echo "bgm=$1" ;;
      --visual)      shift; echo "visual=$1" ;;
      --approach)    shift; echo "approach=$1" ;;
      --audience)    shift; echo "audience=$1" ;;
    esac
    shift
  done
}

# 默认 brief
cmd_brief_defaults() {
  cat <<'EOF'
audience=literary
theme=kraft-paper
pace=200
voice=沉稳男声
visual=书法 + 留白
bgm=古琴
禁忌=
exemplar=
EOF
}

# 主入口：合成 brief
#   $1: profile spec（逗号分隔，可空）
#   $@: 额外 flag 覆盖（"key=val" 形式）
# 输出：合并后的 "key=val" 行
cmd_brief_compose() {
  local spec="$1"
  shift
  
  # 1. 默认值
  local merged_kv=()
  while IFS= read -r kv; do
    [[ -n "$kv" ]] && merged_kv+=("$kv")
  done < <(cmd_brief_defaults)
  
  # 2. profile 合并
  if [[ -n "$spec" ]]; then
    local profile_kv
    profile_kv=$(cmd_profile_resolve "$spec" 2>/dev/null) || true
    while IFS= read -r kv; do
      [[ -n "$kv" ]] && merged_kv+=("$kv")
    done <<< "$profile_kv"
  fi
  
  # 3. flag 覆盖
  for kv in "$@"; do
    [[ -n "$kv" ]] && merged_kv+=("$kv")
  done
  
  # 4. 合并去重（后者覆盖前者）
  cmd_brief_merge_override "${merged_kv[@]}"
}

# 写 brief.md 到 target/.book-video/
#   $1: target 目录
#   $2: profile spec
#   $@: flag 覆盖
cmd_brief_write() {
  local target="$1"
  local spec="$2"
  shift 2
  mkdir -p "$target/.book-video"
  
  local merged
  merged=$(cmd_brief_compose "$spec" "$@")
  
  # 写 markdown 格式
  {
    echo "# Brief · $(basename "$target")"
    echo
    echo "> 自动生成 by chapter-to-video.sh — profile + flag 覆盖合成"
    echo
    echo "| 维度 | 值 |"
    echo "|---|---|"
    while IFS='=' read -r k v; do
      [[ -z "$k" ]] && continue
      echo "| $k | $v |"
    done <<< "$merged"
  } > "$target/.book-video/brief.md"
  
  echo "✓ brief.md 写到 $target/.book-video/brief.md"
}

# 覆盖式合并（同名 key REPLACE 不 concat）
#   $@: 一组 "key=val" 行
cmd_brief_merge_override() {
  # 纯 bash + python 实现（兼容 macOS bash 3.2）
  # 同 key REPLACE（不 concat）
  local _tmp
  _tmp=$(mktemp -t wvp-brief-XXXXXX.txt)
  : > "$_tmp"  # 清空
  local _line _key _val
  for _line in "$@"; do
    [[ -z "$_line" ]] && continue
    _key="${_line%%=*}"
    _val="${_line#*=}"
    # 用 python 读取+更新+写回
    python3 - "$_tmp" "$_key" "$_val" <<'PYTHON'
import sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
try:
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "=" in line:
                k, _, v = line.partition("=")
                data[k] = v
except FileNotFoundError:
    pass
data[key] = val
with open(path, "w", encoding="utf-8") as f:
    for k, v in data.items():
        f.write(f"{k}={v}\n")
PYTHON
  done
  # 输出
  cat "$_tmp"
  rm -f "$_tmp"
}
