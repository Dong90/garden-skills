---
name: chapter-to-video
description: 书籍章节 → 可录屏视频演示。输入一段章节文字，一键生成 Vite + React + TS 项目（默认主题 kraft-paper，默认 TTS + 图片 provider 均为 minimax）。
---

# /chapter-to-video

把用户给的一段书籍章节，做成"看起来像视频"的可录屏 16:9 网页演示。

## 行为

1. **接住用户消息**：用户在 IDE 里直接贴一整段章节文字 / 拖入 .md 文件 / 给路径
2. **保存到临时文件** `/tmp/chapter-input-$(date +%s).md`
3. **跑入口脚本**（在 garden-skills 仓库根）：

   ```bash
   bash skills/web-video-presentation/scripts/chapter-to-video.sh \
     /tmp/chapter-input-XXXX.md \
     --theme=kraft-paper
   ```

4. **把"准备完成"的输出回显给用户**（含「给 agent 的指令」段）
5. **让用户决定下一步**：直接进入 Phase 1.2（生成 script.md / outline.md），还是先调参数（换主题 / 改集数）

## 必读

执行前**先读** [`skills/web-video-presentation/references/BOOK-CHAPTER.md`](skills/web-video-presentation/references/BOOK-CHAPTER.md) §1-3 再开工。本 skill 的所有约定见 [`SKILL.md`](skills/web-video-presentation/SKILL.md)。

## 子命令

跑完 init 后，可用这些子命令查 / 验 / 跑后续步骤：

```bash
# 查状态（看 title / theme / 章节实现情况 / 音频图片数）
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video

# 5 层自检（验 script.md + outline.md 是否达标）
bash skills/web-video-presentation/scripts/chapter-to-video.sh selftest my-video

# 一键跑音频 + 图片
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video

# 跳过任一段
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video --skip-images
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video --skip-audio

# dry-run（只列步骤不真跑）
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video --dry-run
```

子命令目标目录可指定（默认 my-video）：

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status /path/to/any-my-video
```

`init` 后会自动写一份 `my-video/STATE.md` 跟踪进度（`status` 也会读这份）。

---

## 默认配置

| 维度 | 默认 | 说明 |
|---|---|---|
| 主题 | `kraft-paper` | 文学气质。其它文学类推荐：`paper-press` · `vintage-editorial` · `forest-ink` |
| TTS provider | `minimax` | 与 mmx CLI 同源；中文口播稳。其它内置 `openai` |
| 图片 provider | `minimax` | 与 TTS 同源；`mmx image generate` 默认。其它见 `image-providers/README.md` |
| 节奏 | 200 字/分（文学） | 比通用 250 字/分慢半拍 |
| 章节长度 | 5000-8000 字主动问分集 | 详见 BOOK-CHAPTER.md §1.2 |

## 常用参数

```bash
# 换主题
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --theme=paper-press

# 强制拆集（章节 > 25 分钟时）
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --theme=kraft-paper --episodes=3

# 跳过音频（不准备 TTS）
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --no-audio

# 跳过图片（不准备图像生成）
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --no-images

# 强制英文
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --lang=en

# 看所有可用主题
bash skills/web-video-presentation/scripts/chapter-to-video.sh --list-themes

# 复用已存在的 my-video/ 目录
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --resume
```

## 输出结构

跑完会生成 `my-video/`（默认）：

```
my-video/
├── article.md            # 用户的章节原文（保留为画面细节源）
├── meta.json             # 标题/主题/集数/估时/默认 provider（agent 和 CI 都读）
├── BOOK-CHAPTER.md       # 章节特化规则（agent 必读）
├── SCRIPT-STYLE.md / OUTLINE-FORMAT.md / CHAPTER-CRAFT.md
└── presentation/         # Vite + React + TS 项目（主题 = --theme）
      ├── src/chapters/01-example/    # 演示骨架，开始前删
      ├── scripts/
      │   ├── tts-providers/          # minimax + openai
      │   └── image-providers/        # minimax 默认 + 5 段现成片段
      ├── public/images/              # synthesize-images 输出
      └── public/audio/               # synthesize-audio 输出
```

## 下一步（用户决定）

A) **直接进 Phase 1.2**（让 agent 生成 script.md + outline.md）
B) **先调参数**（换主题 / 拆集 / 跳过音频或图片）
C) **加自定义主题**（参考 `themes/` 里 kraft-paper 的 `theme.json` + `tokens.css`）

## 错误速查

- `✗ 找不到文件`：路径写错 / 文件已被删
- `✗ 主题不存在`：跑 `--list-themes` 看全部
- `✗ node 版本太低`：装 Node >= 18
- `✗ mmx CLI not found`（音频/图片阶段）：装 `npm install -g mmx-cli` 然后 `mmx auth login`
- `✗ 目标目录已存在`：加 `--resume` 复用，或换 `--out=<新路径>`

## 全流程

```
你贴一段书章节
  ↓
跑 chapter-to-video.sh（默认主题 kraft-paper，minimax 同时做 TTS + 图片）
  ↓
看"准备完成"输出 → 决定下一步
  ↓
agent 读 BOOK-CHAPTER.md，生成 script.md（口播稿）+ outline.md（含场景卡 + 摘句池）
  ↓
Checkpoint Plan 精简版（2 问：稿子+outline 改不改？主题确认？）
  ↓
agent 实现第 1 章 → 你验收 → 第 2~N 章（A 逐章确认）
  ↓
跑 extract-narrations / synthesize-audio（可选，minimax）
跑 extract-images / synthesize-images（可选，minimax）
  ↓
npm run dev → 浏览器开 ?auto=1 → 录屏
```

## 测试覆盖

本命令背后的入口脚本有 196 个断言覆盖（`bash skills/web-video-presentation/tests/run.sh`）。
改 skill 后先跑测试再交付。

