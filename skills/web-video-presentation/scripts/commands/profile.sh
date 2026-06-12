#!/usr/bin/env bash
# profile 子命令：解析用户 --profile=蒙学,整体养育，合并为 merged brief

# 搜索路径（先项目级，再用户全局）
cmd_profile_search_paths() {
  local paths=()
  # 项目级
  paths+=("./.wvp/profiles")
  # 用户全局
  paths+=("${WVP_PROFILE_PATH:-$HOME/.wvp/profiles}")
  # 显式追加
  [[ -n "${WVP_PROFILE_EXTRA_PATH:-}" ]] && paths+=("$WVP_PROFILE_EXTRA_PATH")
  printf '%s\n' "${paths[@]}"
}

# 找单个 profile 文件路径
#   $1: profile 名
# 返回：文件路径（stdout）
# 退出：找不到 → 1
cmd_profile_find_file() {
  local name="$1"
  local path
  while IFS= read -r path; do
    [[ -f "$path/$name.md" ]] && { echo "$path/$name.md"; return 0; }
  done < <(cmd_profile_search_paths)
  echo "✗ 找不到 profile: $name" >&2
  echo "  搜索路径:" >&2
  while IFS= read -r path; do
    echo "    - $path" >&2
  done < <(cmd_profile_search_paths)
  return 1
}

# 解析 profile 的 frontmatter → 关联数组
#   $1: profile 文件路径
# 输出 key=value 行（YAML 简化版）
# 不支持嵌套，只支持 key: value
cmd_profile_parse() {
  local file="$1"
  [[ -f "$file" ]] || { echo "✗ 文件不存在: $file" >&2; return 1; }
  # 抽 --- 之间的 frontmatter
  local in_fm=0
  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      if [[ $in_fm -eq 0 ]]; then
        in_fm=1
        continue
      else
        break
      fi
    fi
    if [[ $in_fm -eq 1 ]]; then
      # 跳过空行 / 注释
      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
      # 解析 key: value
      if [[ "$line" =~ ^([\一-\鿿a-zA-Z_][\一-\鿿a-zA-Z0-9_]*):[[:space:]]*(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local val="${BASH_REMATCH[2]}"
        # 去掉首尾空格
        val="${val#"${val%%[![:space:]]*}"}"
        val="${val%"${val##*[![:space:]]}"}"
        echo "${key}=${val}"
      fi
    fi
  done < "$file"
}

# 合并多个 key=value 字符串（后写覆盖前写）
#   $@: 一组 "key=value" 行
# 输出：合并后的 key=value
cmd_profile_merge_kv() {
  # 纯 bash 实现（兼容 bash 3.2 + macOS default）
  # 输入：多行 "key=val"
  # 输出：合并后的 "key=val"（同 key 用 " | " 连）
  local _items=""
  local _line _key _val
  for _line in "$@"; do
    [[ -z "$_line" ]] && continue
    _key="${_line%%=*}"
    _val="${_line#*=}"
    # 检查 _key 是否已存在
    if [[ "$_items" == *"$_key|"* || "$_items" == *"|$_key|"* ]]; then
      # 已存在：找到原值行，追加
      local _existing=""
      local _new_items=""
      local _item
      while IFS='|' read -r _k _v; do
        [[ -z "$_k" ]] && continue
        if [[ "$_k" == "$_key" ]]; then
          _existing="${_existing}${_k}|${_v} | ${_val}\n"
        else
          _existing="${_existing}${_k}|${_v}\n"
        fi
      done <<< "$(echo -e "$_items")"
      _items=""
      while IFS='|' read -r _k _v; do
        [[ -z "$_k" ]] && continue
        _items="${_items}${_k}=${_v}\n"
      done <<< "$(printf '%b' "$_existing")"
    else
      _items="${_items}${_key}=${_val}\n"
    fi
  done
  printf '%b' "$_items"
}


# 主入口：解析 --profile=A,B,C → 输出 merged key=value
#   $1: 逗号分隔的 profile 名
cmd_profile_resolve() {
  local spec="$1"
  [[ -z "$spec" ]] && { echo "✗ --profile 不能为空" >&2; return 1; }
  
  # 逗号分隔
  local IFS=','
  local names=($spec)
  
  # 收集所有 profile 的 key=value
  local all_kv=()
  for name in "${names[@]}"; do
    # trim 空白
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [[ -z "$name" ]] && continue
    
    local file
    file="$(cmd_profile_find_file "$name")" || return 1
    
    # 检查必需 frontmatter: name
    local has_name=0
    while IFS= read -r kv; do
      [[ "$kv" == "name="* ]] && has_name=1 && break
    done < <(cmd_profile_parse "$file")
    if [[ $has_name -eq 0 ]]; then
      echo "✗ profile 缺必需字段 name: $file" >&2
      return 1
    fi
    
    # 处理 inherits
    local inherits=""
    while IFS= read -r kv; do
      [[ "$kv" == "inherits="* ]] && inherits="${kv#inherits=}"
    done < <(cmd_profile_parse "$file")
    
    if [[ -n "$inherits" ]]; then
      # 递归解析父（父在前）
      local parent_kv
      parent_kv=$(cmd_profile_resolve "$inherits") || return 1
      while IFS= read -r kv; do
        all_kv+=("$kv")
      done <<< "$parent_kv"
    fi
    
    # 子自身的字段
    while IFS= read -r kv; do
      # inherits 字段已处理
      [[ "$kv" == "inherits="* ]] && continue
      all_kv+=("$kv")
    done < <(cmd_profile_parse "$file")
  done
  
  # 合并
  cmd_profile_merge_kv "${all_kv[@]}"
}
