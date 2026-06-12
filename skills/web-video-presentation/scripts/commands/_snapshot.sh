#!/usr/bin/env bash
# 共享 helper：snapshot_create / snapshot_list / snapshot_restore
# 其他子命令 source 本文件来用
#   source "$SKILL_DIR/scripts/commands/_snapshot.sh"
#
# 设计：
#   - 快照存到 $target/.book-video/snapshots/phase-P<n>-<hash>.tar.gz
#   - tar 包内容是相对 $target 目录的路径（不包 node_modules / snapshots/ 自身 / .git）
#   - 每个 phase 最多保留 5 个快照（按 mtime 删旧的）
#   - hash 用时间戳的 sha256 前 8 位 + 随机数（避免同日多次同 hash）

snapshot_dir() {
  echo "$1/.book-video/snapshots"
}

snapshot_excludes=(
  "--exclude=./.book-video/snapshots"
  "--exclude=./.git"
  "--exclude=./presentation/node_modules"
  "--exclude=./presentation/dist"
  "--exclude=./presentation/.vite"
  "--exclude=./presentation/public/audio"
  "--exclude=./presentation/public/images"
)

snapshot_create() {
  local target="$1" phase="$2"
  [[ -d "$target" ]] || { echo "✗ $target 不存在" >&2; return 1; }
  # 相对路径转绝对（保证 tar -cf 写到正确位置）
  [[ "$target" != /* ]] && target="$(cd "$target" && pwd)"
  local snapdir
  snapdir=$(snapshot_dir "$target")
  mkdir -p "$snapdir"
  local hash
  hash=$(python3 -c "import hashlib,time;print(hashlib.sha256(str(time.time_ns()).encode()).hexdigest()[:8])")
  local snap="$snapdir/phase-${phase}-${hash}.tar.gz"
  # 包内容是相对 $target 的路径
  (cd "$target" && tar -czf "$snap" \
    "${snapshot_excludes[@]}" \
    . ) || { echo "✗ snapshot 失败" >&2; return 1; }
  # 修剪：每 phase 最多 5 个
  local old
  old=$(ls -1t "$snapdir"/phase-${phase}-*.tar.gz 2>/dev/null | tail -n +6)
  [[ -n "$old" ]] && echo "$old" | xargs rm -f
  echo "$snap"
}

snapshot_list() {
  local target="$1"
  local snapdir
  snapdir=$(snapshot_dir "$target")
  [[ -d "$snapdir" ]] || { echo "(无快照)"; return 0; }
  ls -1t "$snapdir"/phase-*-*.tar.gz 2>/dev/null || echo "(无快照)"
}

snapshot_restore() {
  local target="$1" phase="$2"
  [[ "$target" != /* ]] && target="$(cd "$target" && pwd)"
  local snapdir
  snapdir=$(snapshot_dir "$target")
  [[ -d "$snapdir" ]] || { echo "✗ 无 snapshots 目录（$snapdir）" >&2; return 1; }
  local snap
  snap=$(ls -1t "$snapdir"/phase-${phase}-*.tar.gz 2>/dev/null | head -1)
  if [[ -z "$snap" || ! -f "$snap" ]]; then
    echo "✗ 找不到 $phase 的快照（先跑完 $phase 再回退）" >&2
    return 1
  fi
  # 恢复（清掉非快照内容后展开）
  # 注意：tar -xz 会保留 .book-video/snapshots 之外的所有相对路径
  (cd "$target" && tar -xzf "$snap") || { echo "✗ 解压失败" >&2; return 1; }
  echo "$snap"
}
