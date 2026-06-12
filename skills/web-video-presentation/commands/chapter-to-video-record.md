---
name: chapter-to-video-record
description: 启动 dev server + 浏览器 `?auto=1` 自动播放 + 引导 QuickTime 录屏。**第 5 步：录屏成片**。
---

# /chapter-to-video-record

最后一步：把网页演示录成视频文件。

## 行为

1. **启动 dev server**（`cd my-video/presentation && npm run dev`）
2. **打开浏览器**到 `http://localhost:5173/?auto=1`（自动播放模式）
3. **引导 QuickTime 录屏**（macOS 新建屏幕录制 → 选浏览器窗口）
4. **完整过一遍**：从 step 1 到最后一 step
5. **导出** `.mov` / `.mp4`

## 跑法

```bash
# 1. 启动 dev server（前台，新开 terminal）
cd my-video/presentation && npm run dev
# 看到 "Local: http://localhost:5173/" 即可

# 2. 浏览器开（开新窗口）
open "http://localhost:5173/?auto=1"

# 3. QuickTime → 文件 → 新建屏幕录制 → 点浏览器窗口 → 录 → 停
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## `?auto=1` 是什么

演示页有一个自动播放模式：URL 加 `?auto=1` 后，每 step 停留一段时间（默认按字数 / 200 字/分），自动推进。
录屏时**人不用点**——按 5 步子任务的最后一帧停下，整个视频就完整了。

如果你想**手动控制**（讲解时停停走走）：用 `?auto=0` 或省略参数，按 `→` / 空格推进。

## 录屏前 checklist

- [ ] audio 段数 = step 数（看 `status` 输出 "音频: N 段"）
- [ ] image 至少 1 张（`presentation/public/images/` 有内容）
- [ ] dev server 启动无错（终端无红色报错）
- [ ] 浏览器单独窗口（不与其他 tab 混）
- [ ] 系统静音 / 戴耳机（避免录到系统音）

## 录屏后

- QuickTime → 文件 → 导出为 → 1080p / 4K 视频
- 或用 ffmpeg 转 mp4（更小）
- 输出文件名建议 `<章节名>-recording-YYYY-MM-DD.mp4`

## 出错了

- 浏览器空白 → 跑 `bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video` 看哪步没做完
- 音频没声音 → `?auto=1` 模式下浏览器要"允许自动播放音频"（第一次访问会弹）
- 想从 P0 重新开始 → `bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P0 --yes`

## 完整 5 步流程回顾

| 步 | 干啥 | 怎么调 |
|---|---|---|
| 1. init | 准备 my-video/ 脚手架 | `bash chapter-to-video.sh <chap> --test` |
| 2. 写稿 | agent 写 script.md + outline.md | 在 Cursor chat 让 agent 写 |
| 3. 验收 | 5 层自检 + 8 维度评分 | `chapter-to-video.sh selftest` + `judge` |
| 4. 多媒体 | 音频 + 图片合成 | `chapter-to-video.sh pipeline` |
| 5. 录屏 | 浏览器 + QuickTime | **就是这个命令** |

