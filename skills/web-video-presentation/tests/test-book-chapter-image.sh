#!/usr/bin/env bash
# T17: BOOK-CHAPTER.md 含图片生成指南 + scaffold.sh 接 image-providers
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# ── 1. BOOK-CHAPTER.md 新增"图片生成"section ──
assert_grep "BOOK-CHAPTER.md: 含 §图片生成" "图片生成" "references/BOOK-CHAPTER.md"
assert_grep "BOOK-CHAPTER.md: 提到 images.ts" "images.ts" "references/BOOK-CHAPTER.md"
assert_grep "BOOK-CHAPTER.md: 提到 image-prompts.json" "image-prompts.json" "references/BOOK-CHAPTER.md"
assert_grep "BOOK-CHAPTER.md: 提到 1920x1080" "1920x1080" "references/BOOK-CHAPTER.md"
assert_grep "BOOK-CHAPTER.md: 提到 minimax 默认" "minimax" "references/BOOK-CHAPTER.md"

# ── 2. scaffold.sh 接 image-providers ──
assert_grep "scaffold.sh: 提到 image-providers" "image-providers" "scripts/scaffold.sh"
assert_grep "scaffold.sh: 提到 synthesize-images" "synthesize-images" "scripts/scaffold.sh"
assert_grep "scaffold.sh: 提到 extract-images" "extract-images" "scripts/scaffold.sh"
# minimax.sh 应被复制
assert_grep "scaffold.sh: 复制 image-providers/minimax.sh" "image-providers/minimax.sh" "scripts/scaffold.sh"

# ── 3. template 文件结构完整 ──
assert_file_exists "template: image-providers/minimax.sh" "templates/scripts/image-providers/minimax.sh"
assert_file_exists "template: image-providers/README.md" "templates/scripts/image-providers/README.md"
assert_file_exists "template: synthesize-images.sh" "templates/scripts/synthesize-images.sh"
# extract-images.ts 暂不要求（让用户自己写 image prompts）

# ── 4. SKILL.md 提到 image provider 切换 ──
assert_grep "SKILL.md: 提到 synthesize-images" "synthesize-images" "SKILL.md"

print_summary "test-book-chapter-image"
