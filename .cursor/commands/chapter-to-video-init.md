---
name: chapter-to-video-init
description: **第一步** —— 从一段章节文字建 my-video/ 脚手架。**写操作**。state-driven run 的 5 步子任务 #1。
---

# /chapter-to-video-init

把一段书籍章节 → my-video/ 脚手架（脚手架 + 4 步剧本状态 + P0 快照）。

## 什么时候调

- **第一次用**——my-video/ 还不存在
- 想换主题 / 换输入文件重新开始
- 任何"我要建一个新项目"的情况

## 行为

1. 跟用户（或 agent）要 2 件事：
   - **章节路径**：`/path/to/chapter.md`（或 stdin 喂入）
   - **主题**：`kraft-paper`（默认） / `paper-press` / `vintage-editorial` / `forest-ink` ...
2. 调 `bash skills/web-video-presentation/scripts/chapter-to-video.sh <chapter> --out=my-video --theme=<theme>`
3. bash 落 `my-video/article.md` / `meta.json` / `STATE.md` / `presentation/`（Vite+React+TS）
4. 写 `.book-video/state.json`（`phase=P0, status=done`）
5. **自动写 `phase-P0-xxx.tar.gz` 快照**
6. agent 输出"准备完成"提示，让用户调 `/chapter-to-video-plan` 看进度

## 跑法

**直接传路径**（最常见）：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /path/to/chapter.md \
  --out=my-video \
  --theme=kraft-paper
```

**stdin 喂入**（agent 拿到的章节文本直接喂）：
```bash
echo "# 章节内容..." | bash skills/web-video-presentation/scripts/chapter-to-video.sh - --out=my-video
```

**test 模式**（跳过 audio + record，便于先看视觉）：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /path/to/chapter.md \
  --out=my-video \
  --theme=kraft-paper \
  --test
```

**换主题**：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /path/to/chapter.md \
  --out=my-video \
  --theme=paper-press
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 完整参数

| 参数 | 含义 | 默认 |
|---|---|---|
| `--theme=<id>` | 主题 | `kraft-paper` |
| `--out=<dir>` | 输出目录 | `my-video/` |
| `--lang=<zh\|en>` | 强制语言 | 自动检测 |
| `--provider=<id>` | TTS provider | `minimax` |
| `--image-provider=<id>` | 图片 provider | `minimax` |
| `--test` | 测试模式（跳过 audio + record） | — |
| `--resume` | 复用已存在的 my-video/ | — |
| `--episodes=<n>` | 强制拆 n 集 | 自动判断 |

**看所有主题**：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh --list-themes
```

## 输出示例

```
▸ 检测到主语言: zh
▸ 字数 ~88  /  估时 ~1 分钟（200 字/分）
▸ 集数: 1
✓ brief.md 写到 my-video/.book-video/brief.md
▸ 写 STATE.md（4 步剧本 + 5 步子任务 + 快照）
▸ 写 meta.json
▸ 写 state.json
▸ 快照 P0: phase-P0-xxx.tar.gz
  ✓ 准备完成

📁 my-video/
  ├── .book-video/state.json
  ├── meta.json
  ├── article.md
  ├── BOOK-CHAPTER.md
  └── presentation/

下一步：调 /chapter-to-video-plan 看进度
       或直接调 /chapter-to-video-run 让 agent 写稿
```

## 副作用

| 文件 | 写 |
|---|---|
| `my-video/article.md` | ✓ |
| `my-video/meta.json` | ✓ |
| `my-video/STATE.md` | ✓ |
| `my-video/BOOK-CHAPTER.md` / SCRIPT-STYLE.md / OUTLINE-FORMAT.md / CHAPTER-CRAFT.md | ✓ |
| `my-video/presentation/` (脚手架) | ✓ |
| `my-video/.book-video/state.json` | ✓ |
| `my-video/.book-video/brief.md` | ✓ |
| `my-video/.book-video/snapshots/phase-P0-xxx.tar.gz` | ✓ 自动 |

## 完整 7 步

| 步 | 干啥 | 怎么调 |
|---|---|---|
| **init** | **建 my-video/ 脚手架 + 写 P0 快照** | **`/chapter-to-video-init`** ← 第一次先调这个 |
| plan | read-only 看进度 | `/chapter-to-video-plan` |
| run | state-driven 推进 5 步子任务 | `/chapter-to-video-run` |
| status | 看完整 4+5 步进度 | `/chapter-to-video-status` |
| snapshots | 列快照 | `/chapter-to-video-snapshots` |
| rollback | 回退到任意 phase | `/chapter-to-video-rollback` |
| record | 录屏成片 | `/chapter-to-video-record` |

## 下一步

- 调完 init → 调 `/chapter-to-video-plan` 看进度
- 或直接调 `/chapter-to-video-run` 让 agent 写稿（不先看也 OK）
