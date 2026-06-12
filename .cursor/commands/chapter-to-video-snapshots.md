---
name: chapter-to-video-snapshots
description: 列出所有 phase 快照（最近 5 个），看能回退到哪些 phase。**read-only**。
---

# /chapter-to-video-snapshots

列出 `my-video/.book-video/snapshots/` 里所有快照，**read-only**，不动文件。

## 什么时候调

- 准备回退前：先调这个看有哪些快照可回退
- 想确认"刚才那次操作有没自动备份"
- 调试：对比 phase 和快照数

## 行为

1. 调 `bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots <target>`
2. bash 扫 `.book-video/snapshots/`，按 mtime 倒序列出
3. agent 翻译成自然语言 + 提示下一步（rollback / 继续 run）

## 跑法

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots my-video
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 输出示例

```
▸ 快照列表 · my-video
  • P2   phase-P2-a167f92d.tar.gz  (28K)
  • P1   phase-P1-09f46349.tar.gz  (25K)
  • P0   phase-P0-e66139d6.tar.gz  (24K)

回退到某 phase：rollback my-video --to=P<n> --yes
```

## 快照何时自动写

- **init 完工** → `phase-P0-xxx.tar.gz`
- **run 跑过 selftest+judge**（5/5 通过） → `phase-P1-xxx.tar.gz`
- **run 跑过 pipeline**（4/4 完成） → `phase-P2-xxx.tar.gz`

**失败不写快照**——可以放心重跑。

每个 phase 最多保留 5 个（旧快照自动删）。

## 完整 6 步

| 步 | 干啥 | 怎么调 |
|---|---|---|
| plan | read-only 看进度 | `/chapter-to-video-plan` |
| run | state-driven 推进 5 步子任务 | `/chapter-to-video-run` |
| status | 看完整 4+5 步进度 | `/chapter-to-video-status` |
| snapshots | 列快照 | `/chapter-to-video-snapshots` ← 调这个看能回退到哪 |
| rollback | 回退到任意 phase | `/chapter-to-video-rollback` |
| record | 录屏成片 | `/chapter-to-video-record` |

## 下一步

- 想回退 → `/chapter-to-video-rollback --to=P<n>`
- 想继续往前 → `/chapter-to-video-run`
- 想看完整进度 → `/chapter-to-video-status`
