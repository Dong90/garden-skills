---
name: chapter-to-video-run
description: 按当前 phase 自动跑下一个 5 步子任务（init / 写稿 / 验收 / 多媒体 / 录屏）。**state-driven**：跑一次自动推进一格。
---

# /chapter-to-video-run

按 `my-video/.book-video/state.json` 里的 phase，**自动跑下一个 5 步子任务**。
反复调用会一格格往前推；想看进度用 `/chapter-to-video-status`。

## 4 步剧本 ↔ 5 步子任务 映射

| 4 步剧本（用户视角） | 5 步子任务（agent 视角） | 哪个跑 |
|---|---|---|
| `run` #1 | **1. init** | `chapter-to-video.sh <chap> --test` |
| `run` #2 | **2. 写稿** | Cursor agent 写 `script.md` + `outline.md`（bash 不会自动写，会输出 prompt） |
| `run` #3 | **3. 验收** | `chapter-to-video.sh selftest` + `judge` |
| `run` #4 | **4. 多媒体** | `chapter-to-video.sh pipeline`（audio + image） |
| `record` | **5. 录屏** | `npm run dev` + `?auto=1` + QuickTime（单独命令） |

## state-driven dispatch

`run` 读 `state.json` + 实际文件，决定下一步：

| state | 实际文件 | `run` 干啥 |
|---|---|---|
| 无 `my-video/` | — | **调 `/chapter-to-video-init`** 建脚手架 |
| `phase=P0` | 无 `script.md` | 输出"请让 Cursor agent 写 script.md + outline.md" prompt |
| `phase=P0` | 有 `script.md` + `outline.md` | 跑 selftest（自动跳 P1） |
| `phase=P1` | selftest 通过 | 跑 pipeline（如 presentation/ 在；自动跳 P2） |
| `phase=P2` | pipeline 完成 | 提示跑 `/chapter-to-video-record` |

每个子任务**成功完成时自动写快照**到 `my-video/.book-video/snapshots/phase-P<n>-<hash>.tar.gz`。
失败不写快照，可放心重跑。

## 行为

1. 调 `bash skills/web-video-presentation/scripts/chapter-to-video.sh run <target>`
2. bash 输出当前 phase + 实际动作
3. agent 把 bash 输出翻译成自然语言给用户
4. 如果 bash 提示"让 agent 写 script.md"，agent 写完后用户再调一次 `run` 继续

## 跑法

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh run my-video
```

可指定目标目录：

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh run /path/to/any-my-video
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 回退

跑错了？回到任何 phase：

```bash
# 看快照
bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots my-video

# 回到 P0（init 后，写稿前）
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P0 --yes
```

## 下一步

- 想看进度 → `/chapter-to-video-status`
- 4 步全跑完 → `/chapter-to-video-record`

