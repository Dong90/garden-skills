---
name: chapter-to-video-plan
description: 看 my-video 当前进度 + 风险点。**read-only**，不调 run、不改文件。
---

# /chapter-to-video-plan

读 `my-video/.book-video/state.json` + `my-video/STATE.md`，输出：
- **4 步剧本进度**（plan / run / status / record 哪一步）
- **5 步子任务进度**（init / 写稿 / 验收 / 多媒体 / 录屏）
- **当前 phase** + **next_action**
- **风险点**（脚本/录音/图片/录屏哪一步可能卡住）

## 行为

1. 不调 run 子命令、不调 init / selftest / pipeline（read-only）
2. 输出结构化进度，方便人 / agent 决策下一步
3. 如果有 `snapshots/`，显示最近 3 个 + 是否能回退

## 跑法

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video
```

或更详细（含快照）：

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video --verbose
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 输出示例

```
📊 4 步剧本 · my-video

[plan] [run] [status] [record]
   ✓
   1/4 done (init ✓)

当前 phase: P1 - 写稿
5 步子任务:
  ✓ 1. init
  ▱ 2. 写稿 (next: 让 agent 写 script.md + outline.md)
  ▱ 3. 验收
  ▱ 4. 多媒体
  ▱ 5. 录屏

快照: 1 个（最新 phase-P0-abc12345.tar.gz）

风险: presentation/ 还没脚手架；跑 pipeline 前会失败
```

## 下一步决策

- 想动手 → 输入 `/chapter-to-video-run`
- 想看详细 → 输入 `/chapter-to-video-status`
- 想看脚本列表 → 输入 `/chapter-to-video-record` 准备录屏
- 觉得走错了 → `bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P0`

