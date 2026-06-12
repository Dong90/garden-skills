#!/usr/bin/env bash
# judge 子命令：8 维度评分 + 报告

# 启发式评分（无 LLM 依赖）
# 输出 key=score 行
cmd_judge_score() {
  local target="$1"
  local article="$target/article.md"
  local script="$target/script.md"
  local outline="$target/outline.md"
  local brief="$target/.book-video/brief.md"
  local state="$target/.book-video/state.json"
  
  local _script
  _script=$(mktemp -t wvp-judge-XXXXXX.py)
  cat > "$_script" <<'PYTHON'
import sys, re, os
target = sys.argv[1]
article = open(f"{target}/article.md", encoding="utf-8").read() if os.path.exists(f"{target}/article.md") else ""
script = open(f"{target}/script.md", encoding="utf-8").read() if os.path.exists(f"{target}/script.md") else ""
outline = open(f"{target}/outline.md", encoding="utf-8").read() if os.path.exists(f"{target}/outline.md") else ""
brief = open(f"{target}/.book-video/brief.md", encoding="utf-8").read() if os.path.exists(f"{target}/.book-video/brief.md") else ""

scores = {}

# 1. author_voice: script 含 article 金句的比例
def author_voice():
    # 抽 article 里的关键短句（4-15 字）
    candidates = re.findall(r"[一-鿿]{3,15}", article)
    candidates = [c for c in candidates if len(c) >= 3][:30]
    if not candidates:
        return 0.5
    hits = sum(1 for c in candidates if c in script)
    return min(1.0, hits / max(1, len(candidates) * 0.3))

# 2. visual_coherence: brief 是否含 theme/style
def visual_coherence():
    if not brief:
        return 0.6
    has_theme = "theme" in brief or "visual" in brief
    return 0.9 if has_theme else 0.7

# 3. pacing: script 的 step 数（--- 分隔）是否合理
def pacing():
    if not script:
        return 0.5
    beats = script.count("\n---\n") + script.count("\n---") 
    n_beats = max(1, beats)
    # 4-12 step 合理
    if 4 <= n_beats <= 12:
        return 0.9
    if 3 <= n_beats <= 15:
        return 0.7
    return 0.5

# 4. audio_quality: 有 script（音频源）就有
def audio_quality():
    if not script:
        return 0.4
    # script 字数 vs step 数
    chars = len(re.sub(r"\s", "", script))
    beats = max(1, script.count("\n---") + 1)
    avg = chars / beats
    # 30-100 字/step 合理
    if 30 <= avg <= 100:
        return 0.85
    return 0.7

# 5. emotional_impact: 关键词密度（情绪词）
def emotional_impact():
    emo_words = ["愁", "悲", "怅", "温暖", "勇敢", "希望", "爱", "怕", "喜", "思"]
    s_count = sum(script.count(w) for w in emo_words)
    if s_count == 0:
        return 0.6
    if 1 <= s_count <= 20:
        return 0.85
    return 0.7

# 6. cultural_authenticity: 不含西方 cliché
def cultural_authenticity():
    bad = ["教堂", "钟楼", "英文logo", "santa", "halloween"]
    has_bad = any(w in (article + script) for w in bad)
    return 0.4 if has_bad else 0.9

# 7. cinematic_match: brief 含 style 关键词
def cinematic_match():
    if not brief:
        return 0.6
    style_words = ["侯孝贤", "蒙学", "是枝裕和", "水墨", "书法", "古琴", "慢节奏", "留白"]
    has = any(w in brief for w in style_words)
    return 0.85 if has else 0.65

# 8. audience_fit: 句长
def audience_fit():
    # 读 state.json audience
    state = open(f"{target}/.book-video/state.json", encoding="utf-8").read() if os.path.exists(f"{target}/.book-video/state.json") else "{}"
    audience = "literary"
    m = re.search(r'"audience":\s*"([^"]+)"', state)
    if m:
        audience = m.group(1)
    # 句长范围
    if "kids-3-6" in audience:
        max_len = 12
    elif "kids-7-12" in audience:
        max_len = 20
    elif "kids-13-18" in audience:
        max_len = 25
    else:
        max_len = 30
    if not script:
        return 0.5
    sentences = re.findall(r"[。！？]", script)
    n_sent = max(1, len(sentences))
    # 抽脚本里的句子
    parts = re.split(r"[。！？]", script)
    parts = [p for p in parts if p.strip()]
    if not parts:
        return 0.5
    avg = sum(len(p) for p in parts) / len(parts)
    if avg <= max_len:
        return 0.9
    if avg <= max_len * 1.3:
        return 0.75
    return 0.6

scores["author_voice"] = round(author_voice(), 2)
scores["visual_coherence"] = round(visual_coherence(), 2)
scores["pacing"] = round(pacing(), 2)
scores["audio_quality"] = round(audio_quality(), 2)
scores["emotional_impact"] = round(emotional_impact(), 2)
scores["cultural_authenticity"] = round(cultural_authenticity(), 2)
scores["cinematic_match"] = round(cinematic_match(), 2)
scores["audience_fit"] = round(audience_fit(), 2)

print("SCORES_JSON_START")
import json
print(json.dumps(scores, ensure_ascii=False, indent=2))
print("SCORES_JSON_END")
PYTHON
  python3 "$_script" "$target"
  rm -f "$_script"
}

# 主入口
cmd_judge() {
  local target="${1:-my-video}"
  [[ -d "$target" ]] || { echo "✗ $target 不存在"; return 1; }
  [[ -d "$target/.book-video" ]] || { echo "✗ .book-video/ 不存在（先跑 init）"; return 1; }
  
  # 跑评分
  local out
  out=$(cmd_judge_score "$target")
  
  # 抽 JSON 部分
  local json_block
  json_block=$(echo "$out" | sed -n '/SCORES_JSON_START/,/SCORES_JSON_END/p' | sed '1d;$d')
  
  if [[ -z "$json_block" ]]; then
    echo "✗ judge 评分失败" >&2
    return 1
  fi
  
  # 写 JSON
  echo "$json_block" | python3 -c "
import sys, json
data = json.load(sys.stdin)
out = {
    'target': '$target',
    'scores': data,
    'average': round(sum(data.values()) / len(data), 2),
    'created': __import__('datetime').datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
}
print(json.dumps(out, ensure_ascii=False, indent=2))
" > "$target/.book-video/quality-report.json"
  
  # 写 markdown 报告
  WVP_MEMORY_DIR="${WVP_MEMORY_DIR:-$HOME/.wvp/memory}" \
  python3 - "$target/.book-video/quality-report.json" "$target" "$WVP_MEMORY_DIR" <<'PY'
import sys, json, os
report_path = sys.argv[1]
target = sys.argv[2]
memory_dir = sys.argv[3]
with open(report_path, encoding="utf-8") as f:
    report = json.load(f)
scores = report["scores"]
avg = report["average"]

# 找历史平均
state = json.load(open(f"{target}/.book-video/state.json", encoding="utf-8")) if os.path.exists(f"{target}/.book-video/state.json") else {}
audience = state.get("audience", "literary")
hist_path = f"{memory_dir}/history/{audience}.json"
hist = {}
if os.path.exists(hist_path):
    hist = json.load(open(hist_path, encoding="utf-8"))

# 生成报告 md
lines = []
lines.append(f"# 质量报告 · {target}")
lines.append("")
lines.append(f"> 生成于 {report['created']} · audience: {audience}")
lines.append("")
lines.append("## 8 维度评分")
lines.append("")
lines.append("| 维度 | 分数 | vs 历史 |")
lines.append("|---|---|---|")
for dim, val in scores.items():
    h = hist.get(dim)
    if h is not None:
        diff = round(val - h, 2)
        marker = "↑" if diff > 0.05 else ("↓" if diff < -0.05 else "·")
        lines.append(f"| {dim} | {val} | {marker} {diff:+.2f} |")
    else:
        lines.append(f"| {dim} | {val} | (无历史) |")
lines.append("")
lines.append(f"**总分**: {avg}")
lines.append("")

# 改进建议
lines.append("## 改进建议")
lines.append("")
suggestions = []
if scores.get("author_voice", 1.0) < 0.7:
    suggestions.append("- ⚠ **作者声口偏低**: script 应保留更多 article 的关键短句")
if scores.get("pacing", 1.0) < 0.6:
    suggestions.append("- ⚠ **节奏异常**: step 数偏离 4-12 范围")
if scores.get("cultural_authenticity", 1.0) < 0.6:
    suggestions.append("- ⚠ **文化真实性低**: 检测到西方 cliché，需重写")
if scores.get("audience_fit", 1.0) < 0.7:
    suggestions.append(f"- ⚠ **audience_fit 低**: 句长可能超出 {audience} 适龄范围")
if not suggestions:
    suggestions.append("- 💡 全部维度良好。可以微调以追求更高分。")
lines.extend(suggestions)
lines.append("")

open(report_path.replace(".json", ".md"), "w", encoding="utf-8").write("\n".join(lines))
print(f"✓ 报告写到 {report_path.replace('.json', '.md')}")
PY
  
  echo
  echo "✓ judge 完成"
  cat "$target/.book-video/quality-report.md" | head -20
}
