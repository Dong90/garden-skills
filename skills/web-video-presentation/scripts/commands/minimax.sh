#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# minimax 子命令 —— 用 minimax-cli 真生视频（mmx video generate）
#
# 通用流程（不绑死任何具体书/章节/prompt 模板）：
#   1. 读用户给的输入文件（article / 文本片段），用 python 准算"中文 + 英文词"字数
#   2. 估算"原文字数 → 分钟"（中速 ~4 字/秒，1 分钟 ~240 字）
#   3. 交互问主体 / 场景 / 风格（默认 cinematic editorial illustration）
#   4. 给出 5/8 档时长选项（1/2/3/5/10 或 1/2/3/5/10/15/20/30 min），用户选
#   5. 算 N = 目标秒数 / 6（minimax 硬限制 6s/段）
#   6. 从原文中用启发式抽 N 句"关键句"（中英标点兼容 + 字数均衡 + 长度截断）
#   7. 调 minimax N 次（一次 1 段，6s），失败时记录 stderr 到日志
#   8. ffmpeg concat 拼成 1 个 mp4
#   9. 输出到 out/minimax/<basename>-<min>min.mp4
#
# 用法：
#   bash chapter-to-video.sh minimax <my-video> --input=<article.md>
#   bash chapter-to-video.sh minimax my-video --input=chapter1.md --max=20
#   bash chapter-to-video.sh minimax my-video --input=... --dry
#
# 参数：
#   --input=<file>     输入文章（必填）。支持 .md / .txt
#   --max=<N>          最多生成 N 段（默认 30，成本控制）
#   --dry              只打印计划，不调 API
#   --provider=<model> minimax 模型（默认 MiniMax-Hailuo-2.3）
#   --scene=<hint>     场景提示（默认空，会交互询问）
#   --style=<hint>     风格提示（默认 cinematic editorial illustration）
#
# 适用：任何"文→视频"项目，不绑 images.ts / 不绑 v1.4 脚手架。
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

cmd_minimax() {
  local target="${1:-my-video}"
  shift || true

  local input=""
  local max_segs=30
  local dry=0
  local provider="MiniMax-Hailuo-2.3"
  local scene=""
  local style="cinematic editorial illustration with painterly brushstrokes, warm cream paper background, soft natural window light, muted forest green and warm flesh tones"

  for arg in "$@"; do
    case "$arg" in
      --input=*)     input="${arg#--input=}";;
      --max=*)       max_segs="${arg#--max=}";;
      --dry)         dry=1;;
      --provider=*)  provider="${arg#--provider=}";;
      --scene=*)     scene="${arg#--scene=}";;
      --style=*)     style="${arg#--style=}";;
      --*)           echo "✗ minimax: 未知参数 $arg" >&2; return 1;;
      *)            target="$arg";;
    esac
  done

  if [[ -z "$input" ]]; then
    echo "✗ minimax: --input=<file> 必填" >&2
    echo "  例: bash chapter-to-video.sh minimax my-video --input=my-video/article.md" >&2
    return 1
  fi
  if [[ ! -f "$input" ]]; then
    echo "✗ minimax: 找不到输入文件 $input" >&2
    return 1
  fi

  # ── 1. 算字数（python 严格算 CJK + 英文词，避开 wc -m 高估） ──
  local chars
  chars=$(python3 - "$input" <<'PYEND'
import re, sys
text = open(sys.argv[1]).read()
cjk = len(re.findall(r'[一-鿿]', text))
# 英文按 word 切
en_words = len(re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)*", text))
# 数字按 token 计
digits = len(re.findall(r'\d+', text))
print(cjk + en_words + digits)
PYEND
)
  chars=${chars:-0}

  # 中速 4 字/秒；估算总分钟（向上取整）
  local est_min=$(( (chars + 240 - 1) / 240 ))
  if (( est_min < 1 )); then est_min=1; fi

  echo
  echo "▸ minimax · target=$target · input=$input"
  echo "  原文字数: $chars (CJK+英文词)"
  echo "  估算时长 (4 字/秒): ~$est_min min"
  echo

  # ── 2. 交互问主体（如果没传 --scene）──
  if [[ -z "$scene" ]]; then
    echo "请描述视频主体（例：a small child / a woman in her 30s / a teacher / a stray cat）："
    printf "主体: "
    read -r scene
    if [[ -z "$scene" ]]; then
      echo "✗ 主体不能为空" >&2
      return 1
    fi
  fi

  # ── 3. 选时长档位 ──
  echo
  echo "选目标时长（minimax 6s/段，最多 $max_segs 段）："
  local min_options=(1 2 3 5 10)
  for i in "${!min_options[@]}"; do
    local m="${min_options[$i]}"
    local segs=$(( m * 60 / 6 ))
    echo "  $((i+1))) $m min  →  $segs 段"
  done
  local extra_start=6
  if (( est_min > 10 )); then
    echo "  6) 15 min  →  $((15 * 60 / 6)) 段"
    echo "  7) 20 min  →  $((20 * 60 / 6)) 段"
    echo "  8) 30 min  →  $((30 * 60 / 6)) 段"
    extra_start=6
  fi
  echo
  printf "选 (1-8): "
  read -r choice
  local target_min=0
  case "$choice" in
    1|2|3|4|5) target_min="${min_options[$((choice-1))]}";;
    6) target_min=15;;
    7) target_min=20;;
    8) target_min=30;;
    *) echo "✗ 无效选择"; return 1;;
  esac

  local total_secs=$(( target_min * 60 ))
  local n_segs=$(( total_secs / 6 ))
  if (( n_segs > max_segs )); then
    echo "▸ minimax: 段数 $n_segs > 上限 $max_segs，自动截到 $max_segs 段 ($((max_segs * 6))s = $((max_segs * 6 / 60)) min)"
    n_segs=$max_segs
  fi
  echo
  echo "▸ 目标: $target_min min · $n_segs 段 × 6s"
  echo "  主体: $scene"
  echo "  风格: $style"
  echo

  # ── 4. 启发式抽 N 句关键句 ──
  # 策略：按 . / ? / ! / 。 / ！ / ？ 切句，按字数均衡分配到 N 段。
  # 每段取 1 句最具"能量"的（最长）—— 限制每句 ≤ 200 字符避免 minimax 截断。
  local sentences_file
  sentences_file=$(mktemp -t minimax-sentences-XXXXXX.txt)
  python3 - "$input" "$n_segs" > "$sentences_file" <<'PYEND'
import re, sys, random
text = open(sys.argv[1]).read()
# 中英文标点都算
parts = re.split(r'(?<=[。！？!?\.])', text)
# 去空白 / 短句 / 引号
sents = []
for p in parts:
    s = p.strip().strip('"\'“”‘’').strip()
    if len(s) >= 6:
        # 单句超 200 字符：截到 200 + "..."
        if len(s) > 200:
            s = s[:197] + "..."
        sents.append(s)
n = int(sys.argv[2])
if not sents:
    sents = ["a continuing visual scene"]
# 平均分桶
buckets = [[] for _ in range(n)]
for i, s in enumerate(sents):
    buckets[i % n].append(s)
# 每桶挑 1 句（最长）
out = []
for b in buckets:
    if b:
        out.append(max(b, key=len))
    else:
        out.append(random.choice(sents))
for line in out:
    print(line)
PYEND

  echo "── 抽出的 $n_segs 句 ──"
  nl -ba "$sentences_file" | head -n "$n_segs"
  echo

  if (( dry == 1 )); then
    echo "(--dry 模式：跳过 mmx 调用 + 拼片)"
    rm -f "$sentences_file"
    return 0
  fi

  # ── 5. 调 minimax N 次 ──
  command -v mmx >/dev/null || { echo "✗ mmx 不在 PATH" >&2; rm -f "$sentences_file"; return 1; }

  local out_dir="$target/out/minimax"
  mkdir -p "$out_dir"
  local segs_dir
  segs_dir=$(mktemp -d -t minimax-segs-XXXXXX)

  local base
  base=$(basename "$input" | sed -E 's/\.[^.]+$//')

  echo "▸ 调 minimax $n_segs 次（每段 6s）..."
  local fail_log
  fail_log=$(mktemp -t minimax-fail-XXXXXX.log)
  local n_failed=0

  for ((i=0; i<n_segs; i++)); do
    local sent
    sent=$(sed -n "$((i+1))p" "$sentences_file")
    local prompt="cinematic 6 second video, $style. A $scene: $sent. The camera slowly pushes in. No text, no logos, no watermark."
    local out_mp4="$segs_dir/seg-$(printf '%02d' $((i+1))).mp4"
    printf "  ▸ 段 %d/%d: %s\n" "$((i+1))" "$n_segs" "${sent:0:40}..."
    if ! env -u HTTPS_PROXY -u HTTP_PROXY mmx video generate \
        --prompt "$prompt" \
        --model "$provider" \
        --download "$out_mp4" >"$out_mp4.log" 2>&1; then
      echo "    ✗ minimax 失败（段 $((i+1))），log: $out_mp4.log" >&2
      echo "--- 段 $((i+1)) prompt ---" >> "$fail_log"
      echo "$prompt" >> "$fail_log"
      echo "--- log ---" >> "$fail_log"
      cat "$out_mp4.log" >> "$fail_log" 2>/dev/null || true
      echo "" >> "$fail_log"
      n_failed=$((n_failed+1))
    fi
  done

  # ── 6. concat 拼成 1 个 mp4 ──
  local concat_list
  concat_list=$(mktemp -t minimax-concat-XXXXXX.txt)
  for f in "$segs_dir"/seg-*.mp4; do
    [[ -f "$f" ]] && echo "file '$f'" >> "$concat_list"
  done
  local final="$out_dir/${base}-${target_min}min.mp4"
  if [[ -s "$concat_list" ]]; then
    ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$final" 2>&1 | tail -3
    echo
    echo "✓ 完成 → $final"
    ffprobe -v error -show_entries format=duration,size -of default=noprint_wrappers=1 "$final"
    if (( n_failed > 0 )); then
      echo "⚠ $n_failed 段失败，详情见 $fail_log"
    fi
  else
    echo "✗ 没有段成功" >&2
    echo "失败日志: $fail_log"
    return 1
  fi

  rm -f "$sentences_file" "$concat_list"
  rm -rf "$segs_dir"
  [[ -f "$fail_log" && ! -s "$fail_log" ]] && rm -f "$fail_log"
}
