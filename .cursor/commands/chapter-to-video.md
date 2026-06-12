---
name: chapter-to-video
description: 书籍章节 → 可录屏视频演示。**本命令已拆成 4 个子命令** —— plan / run / status / record，按需调用。
---

# /chapter-to-video (router)

本命令已**拆成 4 个独立命令**。在 Cursor chat 里输入 `/`，你会看到：

| 命令 | 干啥 | 何时用 |
|---|---|---|
| **`/chapter-to-video-plan`** | 看当前进度 + 风险点（read-only） | 想动手前先看一眼 |
| **`/chapter-to-video-run`** | 按 phase 自动跑下一个子任务 | 推进一格 |
| **`/chapter-to-video-status`** | 看 4 步剧本 + 5 步子任务 + 快照 | 想知道到哪了 |
| **`/chapter-to-video-snapshots`** | 列快照（看能回退到哪些 phase） | 准备回退前 |
| **`/chapter-to-video-rollback`** | 回退到任意 phase 快照 | 走错时 |
| **`/chapter-to-video-record`** | 启动 dev server + 浏览器 ?auto=1 + 录屏 | 最后一步 |

## 4 步剧本（用户视角）

```
plan → run → status → snapshots → rollback
   ↑      │      │           ↑         ↑
   │      │      │           │         └ 走错时回退
   │      │      │           └ 看快照决定回哪
   │      │      └ 看完整进度
   │      └ 反复调自动推进 5 步子任务
   └ read-only
                ↓
             record (录屏，最后一步)
```

## 5 步子任务（agent 视角，藏在 `run` 里）

1. **init** — `chapter-to-video.sh <chap> --test`
2. **写稿** — Cursor agent 写 `script.md` + `outline.md`
3. **验收** — `chapter-to-video.sh selftest` + `judge`
4. **多媒体** — `chapter-to-video.sh pipeline`（audio + image）
5. **录屏** — dev server + QuickTime（单独命令 `/chapter-to-video-record`）


## 默认配置（适用于 `run` 调起的 init）

| 维度 | 默认 | 覆盖 |
|---|---|---|
| 主题 | `kraft-paper`（文学气质） | `--theme=paper-press` 等 |
| TTS provider | `minimax` | `--provider=openai` |
| 图片 provider | `minimax` | `--image-provider=openai` |

完整参数：`chapter-to-video.sh --help`

## 回退

任意 phase 可回退到 P0/P1/P2/P3：

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots my-video        # 看快照
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback  my-video --to=P0 --yes   # 回 P0
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 完整 6 命令文件

- [`chapter-to-video-plan.md`](chapter-to-video-plan.md)
- [`chapter-to-video-run.md`](chapter-to-video-run.md)
- [`chapter-to-video-status.md`](chapter-to-video-status.md)
- [`chapter-to-video-snapshots.md`](chapter-to-video-snapshots.md)
- [`chapter-to-video-rollback.md`](chapter-to-video-rollback.md)
- [`chapter-to-video-record.md`](chapter-to-video-record.md)

