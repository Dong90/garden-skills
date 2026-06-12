#!/usr/bin/env bash
# T11: 文档契约（SKILL.md / OUTLINE-FORMAT.md / BOOK-CHAPTER.md 必填 section）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

# ── SKILL.md：Phase 1.1 表新增"书籍章节"行 + 精简版 section ──
assert_grep "SKILL.md: Phase 1.1 含书籍章节行" "书籍的某一章节" "SKILL.md"
assert_grep "SKILL.md: Phase 1.1 含 BOOK-CHAPTER 引用" "BOOK-CHAPTER" "SKILL.md"
assert_grep "SKILL.md: 含精简版 section" "书籍章节精简版" "SKILL.md"
assert_grep "SKILL.md: 精简版提到 2 问" "2 问" "SKILL.md"

# ── OUTLINE-FORMAT.md：新增"书籍章节专用字段" ──
assert_grep "OUTLINE-FORMAT.md: 含书籍章节字段 section" "书籍章节专用字段" "references/OUTLINE-FORMAT.md"
assert_grep "OUTLINE-FORMAT.md: 含场景卡" "场景卡" "references/OUTLINE-FORMAT.md"
assert_grep "OUTLINE-FORMAT.md: 含摘句池" "摘句池" "references/OUTLINE-FORMAT.md"

# ── BOOK-CHAPTER.md：6 个核心 section 都在 ──
for sec in "为什么需要特化" "长度处理" "声口保留" "场景 / 角色" "主题推荐矩阵" "节奏调整" "质量门"; do
  assert_grep "BOOK-CHAPTER.md: 含 §$sec" "$sec" "references/BOOK-CHAPTER.md"
done

# ── scaffold.sh: --chapter 支持 + BOOK-CHAPTER.md copy ──
assert_grep "scaffold.sh: 含 --chapter case" "\-\-chapter" "scripts/scaffold.sh"
assert_grep "scaffold.sh: 含 BOOK-CHAPTER 复制" "BOOK-CHAPTER.md" "scripts/scaffold.sh"

# ── chapter-to-video.sh: 关键步骤都在 ──
assert_grep "chapter-to-video.sh: 含语言检测" "LANG" "scripts/chapter-to-video.sh"
assert_grep "chapter-to-video.sh: 含拆集决策" "EPISODES" "scripts/chapter-to-video.sh"
assert_grep "chapter-to-video.sh: 含 scaffold 调用" "scaffold" "scripts/chapter-to-video.sh"
assert_grep "chapter-to-video.sh: 含 meta.json 写" "meta.json" "scripts/chapter-to-video.sh"
assert_grep "chapter-to-video.sh: BOOK-CHAPTER.md 复制" "BOOK-CHAPTER.md" "scripts/chapter-to-video.sh"

print_summary "test-skill-md-contracts"
