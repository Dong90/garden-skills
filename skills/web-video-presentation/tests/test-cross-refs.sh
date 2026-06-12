#!/usr/bin/env bash
# T12: 跨文档引用（只检查本次改动涉及的 .md 文件，相对路径按源文件解析）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# 本次改动涉及的文件
SOURCES=(
  "SKILL.md"
  "references/BOOK-CHAPTER.md"
  "references/OUTLINE-FORMAT.md"
)

resolve_path() {
  local src="$1" ref="$2"
  case "$ref" in
    http*|/*|\#*) echo ""; return ;;
  esac
  local src_dir
  src_dir="$(dirname "$src")"
  if [[ "$ref" != */* ]]; then
    if [[ "$src_dir" = "." ]]; then
      echo "$ref"
    else
      echo "$src_dir/$ref"
    fi
    return
  fi
  if [[ "$src_dir" = "." ]]; then
    echo "$ref"
  else
    python3 - "$src_dir" "$ref" <<'PY'
import os, sys
print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))
PY
  fi
}

total_refs=0
missing_refs=0

for src in "${SOURCES[@]}"; do
  [[ -f "$src" ]] || { _TEST_FAIL=$((_TEST_FAIL+1)); _log_fail "source missing: $src"; continue; }
  
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    # 跳过 [text](http://...)  或 [text](#anchor)
    if [[ "$match" == *"http"* || "$match" == *"#"* ]]; then continue; fi
    # 提取路径
    path=$(echo "$match" | sed -E 's/.*\]\(([^)]+)\).*/\1/')
    path="${path%%#*}"
    [[ -z "$path" ]] && continue
    resolved=$(resolve_path "$src" "$path")
    [[ -z "$resolved" ]] && continue
    [[ "$resolved" != *.md ]] && continue
    total_refs=$((total_refs + 1))
    if [[ -f "$resolved" ]]; then
      _TEST_PASS=$((_TEST_PASS + 1))
      _TEST_TOTAL=$((_TEST_TOTAL + 1))
    else
      _TEST_FAIL=$((_TEST_FAIL + 1))
      _TEST_TOTAL=$((_TEST_TOTAL + 1))
      _TEST_FAILURES+=("$src: missing ref → resolved=$resolved")
      _log_fail "$src: missing ref $resolved" "from: $match"
      missing_refs=$((missing_refs + 1))
    fi
  done < <(grep -ohE '\[[^]]+\]\([^)]+\.md\)' "$src" 2>/dev/null)
done

echo
if [[ $total_refs -gt 0 && $missing_refs -eq 0 ]]; then
  _log_pass "all $total_refs refs across ${#SOURCES[@]} files resolve"
else
  _log_fail "$missing_refs/$total_refs refs are broken"
fi

# 关键引用必须存在
assert_grep "SKILL.md 引用 BOOK-CHAPTER.md" "BOOK-CHAPTER" "SKILL.md"
assert_grep "chapter-to-video.sh 引用 BOOK-CHAPTER" "BOOK-CHAPTER" "scripts/chapter-to-video.sh"
assert_grep "OUTLINE-FORMAT.md 引用 BOOK-CHAPTER" "BOOK-CHAPTER" "references/OUTLINE-FORMAT.md"

print_summary "test-cross-refs"
