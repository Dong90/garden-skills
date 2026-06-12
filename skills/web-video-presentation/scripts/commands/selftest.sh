#!/usr/bin/env bash
# selftest 子命令：跑 5 层自检（详见 references/CHECKLIST.md）
cmd_selftest() {
  local target="${1:-my-video}"
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  [[ -f "$target/article.md" ]] || { echo "✗ $target/article.md 不存在（先跑 init）"; return 1; }
  [[ -f "$target/script.md"  ]] || { echo "✗ $target/script.md 不存在（先让 agent 写）"; return 1; }
  [[ -f "$target/outline.md" ]] || { echo "✗ $target/outline.md 不存在（先让 agent 写）"; return 1; }

  local fail=0
  echo "▸ 5 层自检 (target=$target)"
  echo

  # ── 第 1 层 · 信息保留度 ≥ 60% ──
  echo "── 第 1 层 · 信息保留度 ≥ 60% ──"
  local ratio pct
  ratio=$(python3 - "$target" <<'PY'
import re, sys
art = open(f"{sys.argv[1]}/article.md", encoding="utf-8").read()
scr = open(f"{sys.argv[1]}/script.md", encoding="utf-8").read()
art_n = len(re.findall(r"[㐀-鿿]", art))
scr_n = len(re.findall(r"[㐀-鿿]", scr))
if art_n == 0:
    print("0/0=0%")
else:
    print(f"{scr_n}/{art_n}={scr_n*100//art_n}%")
PY
)
  echo "  script/article CJK 比: $ratio"
  pct=$(echo "$ratio" | grep -oE "[0-9]+%" | tr -d '%')
  if [[ "${pct:-0}" -ge 60 ]]; then
    echo "  ✓ 通过"
  else
    echo "  ✗ 不通过（< 60%）"
    fail=$((fail+1))
  fi
  echo

  # ── 第 2 层 · 去 AI 味 5 类 ──
  echo "── 第 2 层 · 去 AI 味 5 类 ──"
  local ai_hits
  ai_hits=$(grep -nE "说白了|本质上|底层逻辑|恰恰|正是因为|在某种程度上|归根结底|换句话说" "$target/script.md" 2>/dev/null | head -5 || true)
  if [[ -z "$ai_hits" ]]; then
    echo "  ✓ 通过（无 AI 高频词）"
  else
    echo "  ✗ 不通过（发现 AI 高频词）："
    echo "$ai_hits" | sed 's/^/    /'
    fail=$((fail+1))
  fi
  echo

  # ── 第 3 层 · 念出来节奏（--- 切分）──
  echo "── 第 3 层 · 念出来节奏（--- 切分）──"
  local beat_count
  beat_count=$(grep -c "^---$" "$target/script.md" 2>/dev/null || echo 0)
  # 上面已有 || echo 0
  if [[ "$beat_count" -ge 2 ]]; then
    echo "  ✓ 通过（$beat_count 个节拍）"
  else
    echo "  ✗ 不通过（只有 $beat_count 个节拍，需要 ≥ 2）"
    fail=$((fail+1))
  fi
  echo

  # ── 第 4 层 · outline 字段完整性 ──
  echo "── 第 4 层 · outline 字段完整性 ──"
  for field in "信息池" "场景卡" "摘句池"; do
    if grep -q "$field" "$target/outline.md" 2>/dev/null; then
      echo "  ✓ 含 §$field"
    else
      echo "  ✗ 缺 §$field"
      fail=$((fail+1))
    fi
  done
  echo

  # ── 第 5 层 · 书籍章节特化 ──
  echo "── 第 5 层 · 书籍章节特化 ──"
  if grep -q "主场景" "$target/outline.md" 2>/dev/null && \
     grep -q "物件" "$target/outline.md" 2>/dev/null && \
     grep -q "在场角色" "$target/outline.md" 2>/dev/null; then
    echo "  ✓ 场景卡完整（主场景/物件/角色）"
  else
    echo "  ✗ 场景卡不完整"
    fail=$((fail+1))
  fi
  local quote_count
  quote_count=$(grep -cE '^[[:space:]]*-\s*"' "$target/outline.md" 2>/dev/null; true)
  if [[ "$quote_count" -ge 2 ]]; then
    echo "  ✓ 摘句池 ≥ 2 句（实际 $quote_count 句）"
  else
    echo "  ✗ 摘句池 < 2 句（实际 $quote_count 句）"
    fail=$((fail+1))
  fi
  echo

  # ── 总结 ──
  if [[ $fail -eq 0 ]]; then
    echo "✓ 5/5 通过。可以进入 Checkpoint Plan。"
    return 0
  else
    echo "✗ $fail 项不通过。修完再 selftest。"
    return 1
  fi
}
