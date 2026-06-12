#!/usr/bin/env bash
# pipeline 子命令：一键跑 audio + image + 给出录屏指引
cmd_pipeline() {
  local target="${1:-my-video}"
  shift 2>/dev/null || true
  
  local skip_audio=0 skip_images=0 dry_run=0
  for arg in "$@"; do
    case "$arg" in
      --skip-audio)  skip_audio=1 ;;
      --skip-images) skip_images=1 ;;
      --dry-run)     dry_run=1 ;;
    esac
  done
  
  local proj="$target/presentation"
  [[ -d "$proj" ]] || { echo "✗ $proj 不存在（先跑 chapter-to-video.sh init）" >&2; return 1; }
  [[ -f "$proj/package.json" ]] || { echo "✗ $proj/package.json 不存在（脚手架没装好）" >&2; return 1; }
  
  echo "▸ pipeline · target=$target"
  echo "  audio:  $([ $skip_audio -eq 1 ] && echo skip || echo run)"
  echo "  images: $([ $skip_images -eq 1 ] && echo skip || echo run)"
  echo "  dry-run: $([ $dry_run -eq 1 ] && echo yes || echo no)"
  echo
  
  cd "$proj" || return 1
  
  local total=0 done=0 failed=0
  local title step
  
  # ── 1. extract-narrations ──
  if [[ $skip_audio -eq 0 ]]; then
    total=$((total+1))
    step=$total
    title="extract-narrations"
    echo "── $step/$((step+skip_images*2)) ── npm run $title"
    if [[ $dry_run -eq 1 ]]; then
      echo "  (dry-run)"
      done=$((done+1))
    elif npm run "$title" 2>&1 | sed 's/^/  /'; then
      done=$((done+1))
    else
      failed=$((failed+1))
      echo "  ✗ 失败"
    fi
    echo
  fi
  
  # ── 2. synthesize-audio ──
  if [[ $skip_audio -eq 0 ]]; then
    total=$((total+1))
    step=$total
    title="synthesize-audio"
    echo "── $step/$step ── npm run $title (provider=${PRESENTATION_TTS:-minimax})"
    if [[ $dry_run -eq 1 ]]; then
      echo "  (dry-run)"
      done=$((done+1))
    elif PRESENTATION_TTS="${PRESENTATION_TTS:-minimax}" npm run "$title" 2>&1 | sed 's/^/  /'; then
      done=$((done+1))
    else
      failed=$((failed+1))
      echo "  ✗ 失败"
    fi
    echo
  fi
  
  # ── 3. extract-images ──
  if [[ $skip_images -eq 0 ]]; then
    total=$((total+1))
    step=$total
    title="extract-images"
    echo "── $step/$step ── npm run $title"
    if [[ $dry_run -eq 1 ]]; then
      echo "  (dry-run)"
      done=$((done+1))
    elif npm run "$title" 2>&1 | sed 's/^/  /'; then
      done=$((done+1))
    else
      failed=$((failed+1))
      echo "  ⚠ 失败（可能你还没写 images.ts，加 --skip-images 跳过图片）"
    fi
    echo
  fi
  
  # ── 4. synthesize-images ──
  if [[ $skip_images -eq 0 ]]; then
    total=$((total+1))
    step=$total
    title="synthesize-images"
    echo "── $step/$step ── npm run $title (provider=${PRESENTATION_IMG:-minimax})"
    if [[ $dry_run -eq 1 ]]; then
      echo "  (dry-run)"
      done=$((done+1))
    elif PRESENTATION_IMG="${PRESENTATION_IMG:-minimax}" npm run "$title" 2>&1 | sed 's/^/  /'; then
      done=$((done+1))
    else
      failed=$((failed+1))
      echo "  ✗ 失败"
    fi
    echo
  fi
  
  # ── 总结 ──
  echo "════════════════════════════════════════"
  echo "  pipeline: $done/$total 步完成，$failed 步失败"
  echo "════════════════════════════════════════"
  echo
  echo "▸ 下一步："
  echo "  1. 跑 status 看音频/图片数："
  echo "     chapter-to-video.sh status $target"
  echo "  2. 启动 dev server："
  echo "     cd $proj && npm run dev"
  echo "  3. 浏览器开 http://localhost:5173/?auto=1"
  echo "  4. 按 SPACE 启动 + 录屏"
  
  [[ $failed -eq 0 ]] && return 0 || return 1
}
