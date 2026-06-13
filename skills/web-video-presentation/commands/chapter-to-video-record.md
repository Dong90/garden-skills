---
name: chapter-to-video-record
description: 把网页演示录成视频文件。**第 5 步**：可选 A · 浏览器录屏 或 B · Remotion 离线出片。Remotion 模式不需要录屏，直接出 .mp4。
---

# /chapter-to-video-record

最后一步：把网页演示录成视频文件。**两种模式选一**：

## 选哪个？

| 模式 | 触发 | 适合 | 输出 |
|---|---|---|---|
| **A · 浏览器录屏**（默认） | `?auto=1` + QuickTime | 调样式 / 短片 / 不想装 Remotion | `.mov` / `.mp4` |
| **B · Remotion 离线出片**（v1.3+） | `npm run render` | 平台上传 / 拼多集 / 长时间视频 | `out/<episode>.mp4` |

---

## 模式 A · 浏览器录屏（保留原能力）

1. **启动 dev server**：`cd my-video && npm run dev`
2. **打开浏览器**到 `http://localhost:5173/?auto=1`
3. **QuickTime 录屏**：macOS 新建屏幕录制 → 选浏览器窗口
4. **完整过一遍**：从 step 1 到最后一 step
5. **导出** `.mov` / `.mp4`

## 模式 B · Remotion 离线出片（v1.3+ 新增）

```bash
cd my-video

# 1. 跑过 pipeline 后，durationInFrames 已注入
npm run probe          # 如未跑 pipeline

# 2. 出片
npm run render         # 所有 episode
# 或
npm run render:ep01    # 单集

# 3. 输出在 out/<episode>.mp4
ls -lh out/
```

**优势**：
- 音视频天然对齐（probe 注入了真实时长）
- 不用录屏 / 不用后期
- M 系列芯片 VideoToolbox 硬编，1 分钟视频约 1-3 分钟渲染
- 多集自动拼接（`npx remotion compositions` 看所有）

**前置**（pipeline 应已做）：
- `npm run synthesize` 跑过（mp3 在 `vite/public/audio/`）
- `npm run probe` 跑过（durationInFrames 已注入）
- 装了 ffmpeg / ffprobe

## 跑法

### 模式 A
```bash
# 1. 启动 dev server（前台，新开 terminal）
cd my-video && npm run dev
# 看到 "Local: http://localhost:5173/" 即可

# 2. 浏览器开（开新窗口）
open "http://localhost:5173/?auto=1"

# 3. QuickTime → 文件 → 新建屏幕录制 → 点浏览器窗口 → 录 → 停
```

### 模式 B
```bash
cd my-video && npm run render
# 等渲染完，看 out/<episode>.mp4
```

## 必读

执行前**先读** [`skills/web-video-presentation/references/REMOTION-MAPPING.md`](references/REMOTION-MAPPING.md)（Remotion 模式）或 [`SKILL.md`](SKILL.md)（Vite 模式）。

## `?auto=1` 是什么

演示页有一个自动播放模式：URL 加 `?auto=1` 后，每 step 停留一段时间（默认按字数 / 200 字/分），自动推进。
录屏时**人不用点**——按 5 步子任务的最后一帧停下，整个视频就完整了。

如果你想**手动控制**（讲解时停停走走）：用 `?auto=0` 或省略参数，按 `→` / 空格推进。

## 录屏前 checklist（模式 A）

- [ ] audio 段数 = step 数（看 `status` 输出 "音频: N 段"）
- [ ] image 至少 1 张（`vite/public/images/` 有内容）
- [ ] dev server 启动无错（终端无红色报错）
- [ ] 浏览器单独窗口（不与其他 tab 混）
- [ ] 系统静音 / 戴耳机（避免录到系统音）

## 出片前 checklist（模式 B）

- [ ] `npm run probe` 跑过（`shared/chapters/*/narrations.ts` 的 `durationInFrames` 非 0）
- [ ] `npm run synthesize` 跑过（`vite/public/audio/<id>/<N>.mp3` 都在）
- [ ] ffmpeg / ffprobe 已装（`which ffmpeg`）
- [ ] `npx remotion compositions` 能列出 Episode01 等

## 出错了

- 浏览器空白 → 跑 `bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video` 看哪步没做完
- 音频没声音 → `?auto=1` 模式下浏览器要"允许自动播放音频"（第一次访问会弹）
- Remotion 渲染慢 → macOS 加 `--concurrency=4`（默认即 4）；M 系列确认 VideoToolbox
- Remotion 渲染失败 → 跑 `npm run probe` 看 ffprobe 是否对每段 mp3 成功
- 想从 P0 重新开始 → `bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback my-video --to=P0 --yes`

## 完整 5 步流程回顾

| 步 | 干啥 | 怎么调 |
|---|---|---|
| 1. init | 准备 my-video/ 脚手架 | `bash chapter-to-video.sh <chap> --test` |
| 2. 写稿 | agent 写 script.md + outline.md | 在 Cursor chat 让 agent 写 |
| 3. 验收 | 5 层自检 + 8 维度评分 | `chapter-to-video.sh selftest` + `judge` |
| 4. 多媒体 | 音频 + 图片合成 + probe | `chapter-to-video.sh pipeline` |
| 5. 出片 | 浏览器录屏 A / Remotion 出片 B | **就是这个命令** |

