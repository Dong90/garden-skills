---
name: chapter-to-video-rollback
description: 从快照回退到任意 phase（P0/P1/P2）。任意步走错都可调。
---

# /chapter-to-video-rollback

把 `my-video/` 恢复到某个 phase 的快照。**写操作**——会覆盖当前内容。

## 什么时候调

- run 跑出来的结果不符合预期
- selftest / judge 失败但不想手动改稿
- pipeline 生成的音频/图片质量不行
- 任何"不如回到上一步重来"的情况

## 行为

1. 调 `bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback <target> --to=P<n> --yes`
2. bash 解压对应 phase 的快照到 `my-video/`
3. 更新 `state.json`：`phase=<目标>`、`phase_status=rolled_back`
4. 在 `STATE.md` 顶部加 "已回退到 P<n>" 警告
5. agent 报告回退结果，提示用户调 `/chapter-to-video-run` 继续

## 跑法

**先列快照**（看能回到哪些 phase）：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots my-video
```

**再回退**（必须带 `--yes`，否则交互式确认会卡住）：
```bash
# 回到 P0（init 之后、写稿之前）
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P0 --yes

# 回到 P1（selftest 之后、pipeline 之前）
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P1 --yes

# 回到 P2（pipeline 之后、录屏之前）
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P2 --yes
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 输出示例

```
⚠ 即将从快照恢复 my-video
  快照: my-video/.book-video/snapshots/phase-P1-xxxxxx.tar.gz
  ⚠ 当前 my-video 的内容会被覆盖
✓ 回退完成 · 当前 phase = P1
  下一步：chapter-to-video.sh run my-video
```

## 注意事项

- **会覆盖**：`presentation/src/`、`public/audio/`、`public/images/`、`script.md`、`outline.md`
- **不会丢**：`.book-video/snapshots/` 自己（每次回退会再写一个新快照，旧的留着）
- **快照可能不存在的 phase**：如果 P2 还没跑过，回退到 P2 会失败。先跑 `/chapter-to-video-snapshots` 看有哪些 phase 可回退
- **回退 ≠ 删**：回退后想重新往前跑，调 `/chapter-to-video-run`，从目标 phase 的下一步继续

## 完整 6 步

| 步 | 干啥 | 怎么调 |
|---|---|---|
| plan | read-only 看进度 | `/chapter-to-video-plan` |
| run | state-driven 推进 5 步子任务 | `/chapter-to-video-run` |
| status | 看完整 4+5 步进度 | `/chapter-to-video-status` |
| **rollback** | **回退到任意 phase** | **`/chapter-to-video-rollback`** ← 走错时调这个 |
| snapshots | 列出所有快照 | `/chapter-to-video-snapshots` |
| record | 录屏成片 | `/chapter-to-video-record` |

## 下一步

- 回退后想继续往前走 → `/chapter-to-video-run`
- 看了快照但不确定回哪 → `/chapter-to-video-status` 看 phase 详情
