---
name: chapter-to-video-status
description: 看 my-video 当前进度——4 步剧本 + 5 步子任务 + phase 详情 + 快照列表。**read-only**。
---

# /chapter-to-video-status

读 `my-video/.book-video/state.json` + `my-video/STATE.md`，输出完整进度。

## 显示内容

- **title / theme / lang / provider**（从 `meta.json`）
- **当前 phase**（P0/P1/P2/P3/P4）+ **phase_status**（done/rolled_back/...）
- **4 步剧本进度**（plan / run / status / record 哪一步做完）
- **5 步子任务进度**（init / 写稿 / 验收 / 多媒体 / 录屏）
- **章节 / 音频 / 图片计数**（从 presentation/）
- **快照列表**（最近 5 个 `phase-P<n>-<hash>.tar.gz`）
- **回退提示**（如果 phase_status = rolled_back）

## 行为

1. **只读**：不调 run / selftest / pipeline
2. 输出人能直接读的进度 + agent 能解析的结构
3. 每次都重新读，不缓存

## 跑法

```bash
# 简洁（默认）
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video

# 含快照 + 完整 4/5 步进度
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video --verbose
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 输出示例

```
📊 4 步剧本 · my-video

[plan ✓] [run · 1/4] [status · ·] [record · ·]

当前 phase: P1 - 内容
5 步子任务:
  ✓ 1. init             (P0 done)
  ▱ 2. 写稿             (P1, 等 agent 写 script.md + outline.md)
  ▱ 3. 验收
  ▱ 4. 多媒体
  ▱ 5. 录屏

📁 章节: 0/3 实现
🎙  音频: 0 段
🖼  图片: 0 张
📦 快照: 1 个 (phase-P0-abc12345.tar.gz, 11 KB)

调 `snapshot` 子命令可看完整快照列表

Token 用了: 4521
```

## 下一步

- 当前 P1 → 写 script.md + outline.md 后再调 `/chapter-to-video-run`
- 进度乱了 → `bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P<n>`

