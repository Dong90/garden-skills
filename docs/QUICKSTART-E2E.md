# 5 步走完整流程：书籍章节 → 视频（Cursor 内）

> 在 Cursor 里跑，每步都是 IDE 里的一个动作。

## 前置

- 已打开 `garden-skills` 仓库
- 已装 Node >= 18 + npm
- 已装 MiniMax CLI（音频/图片需要）: `npm install -g mmx-cli && mmx auth login --api-key <key>`
- 装了 ffmpeg（可选，后期）

## Step 0 · 单元测试（1 分钟）

```bash
cd skills/web-video-presentation
bash tests/run.sh          # → 18+ files / 240+ assertions / 0 failed
```

或单跑 e2e 冒烟：

```bash
bash tests/test-e2e-smoke.sh   # → 25/25 passed
```

## Step 1 · 一键初始化（5 分钟）

### 1a. 准备章节

把书章节存成 .md（建议 1000-3000 字，太多会拆集）：

```bash
cat > /tmp/test-chapter.md <<'EOF'
# 匆匆 · 朱自清

燕子去了，有再来的时候；杨柳枯了，有再青的时候；桃花谢了，有再开的时候。
但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？
我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。
EOF
```

### 1b. 跑入口

```bash
cd /path/to/garden-skills
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/test-chapter.md --theme=kraft-paper
```

输出（`my-video/`）：
- `article.md` — 落盘原文
- `meta.json` — 自动生成（含 `title` / `theme` / `lang` / `image_provider`）
- `STATE.md` — 自动生成（Phase 0-4 进度跟踪）
- `BOOK-CHAPTER.md` / `SCRIPT-STYLE.md` / 等
- `presentation/` — Vite + React + TS 脚手架

末尾打印「给 agent 的指令」段。

### 1c. 验证

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video
# → 应看到 title / theme / chapters: 1 个 / ✓ article.md / ✓ STATE.md
```

## Step 2 · 让 agent 写内容（10-30 分钟 · Cursor 内）

### 2a. 打开 Cursor

```bash
code my-video
```

### 2b. 在 Cursor 对话框输入 `/chapter-to-video`

agent 会自动加载命令文件，**自动知道**要读 BOOK-CHAPTER.md。

### 2c. 跑子命令

```bash
# 等 agent 写完 script.md + outline.md 后，验 5 层
bash skills/web-video-presentation/scripts/chapter-to-video.sh selftest my-video
# → 应输出 "5/5 通过"
```

不通过？修完再 selftest。

## Step 3 · Checkpoint Plan（2 问 · Cursor 内）

跟 agent 对齐：
1. **稿子 + outline** 改不改？
2. **主题确认**？Agent 已按 BOOK-CHAPTER.md §4 矩阵推荐了 2 个。

## Step 4 · agent 实现第 1 章（30-60 分钟 · Cursor 内）

让 agent 按 BOOK-CHAPTER.md + CHAPTER-CRAFT.md 写：
- `my-video/presentation/src/chapters/01-<id>/<Chapter>.tsx`
- `my-video/presentation/src/chapters/01-<id>/<Chapter>.css`
- `my-video/presentation/src/chapters/01-<id>/narrations.ts`

要图片：在同目录加 `images.ts`：
```ts
export const images = [
  { prompt: "春天庭院里燕子在飞", size: "1920x1080" },
];
```

然后在 `src/registry/chapters.ts` 注册。

**验收**：

```bash
cd my-video/presentation
npm run dev
# 浏览器开 http://localhost:5173/，点几次 step 推进，看画面
```

## Step 5 · 音频 + 图片（一键）

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video
```

会跑 4 步：
1. `extract-narrations` → audio-segments.json
2. `synthesize-audio` (minimax TTS) → mp3
3. `extract-images` → image-prompts.json
4. `synthesize-images` (minimax image) → png

跳过任一段：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline my-video --skip-images
```

跑完看状态：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status my-video
# → audio: 7 个 mp3 段 / images: 3 张
```

## Step 6 · 录屏

```bash
cd my-video/presentation
npm run dev
```

浏览器开 **http://localhost:5173/?auto=1**

按 **SPACE** → 整片自动播 + 推进。

打开 macOS QuickTime Player：文件 → 新建屏幕录制 → 选浏览器窗口 → 录制 → 浏览器自动播完 → 停录。

音视频天然同步（auto 模式按音频长度推进），无需后期对音轨。

裁头尾 → 成片。

## 故障排查

| 症状 | 解法 |
|---|---|
| `✗ node 版本太低` | `brew install node@18` |
| `✗ mmx CLI not found` | `npm install -g mmx-cli && mmx auth login --api-key <key>` |
| `✗ 目标目录已存在` | 加 `--resume` 复用，或换 `--out=<新路径>` |
| `selftest` 5/5 不通过 | 修稿子（最常见：信息保留度 < 60% 需展开；AI 高频词需替换） |
| `pipeline` 失败 | 看 stderr；通常是 `images.ts` 没写，加 `--skip-images` |
| `npm run dev` 起来 404 | `cd my-video/presentation && ls src/chapters/` 确认有内容 |
| 录屏无音频 | macOS 屏幕录制需授权；系统设置 → 隐私与安全 → 屏幕录制 → 加 QuickTime |

## 验收清单（12 项）

- [ ] Step 0 单测全绿
- [ ] Step 1 `my-video/meta.json` 含 `image_provider: "minimax"`
- [ ] Step 1 `my-video/STATE.md` 存在
- [ ] Step 2 `script.md` + `outline.md` 写完
- [ ] Step 2 `selftest` 5/5 通过
- [ ] Step 3 Checkpoint Plan 2 问对齐
- [ ] Step 4 第 1 章 .tsx 实现完
- [ ] Step 4 浏览器 `npm run dev` 能看见画面
- [ ] Step 5 `pipeline` 跑通（audio 段数 = step 数）
- [ ] Step 5 `status` 显示 audio: N 段 / images: N 张
- [ ] Step 6 `?auto=1` 整片自动播完
- [ ] Step 6 录屏成片在 5-15 分钟之间

## 子命令速查

| 子命令 | 何时用 | 例子 |
|---|---|---|
| `chapter-to-video.sh <chapter.md>` | 第一次 | `--theme=kraft-paper` |
| `chapter-to-video.sh status [target]` | 想看现在到哪了 | `status my-video` |
| `chapter-to-video.sh selftest [target]` | 验稿子质量（5 层自检） | `selftest my-video` |
| `chapter-to-video.sh pipeline [target]` | 一键 audio + image | `pipeline my-video --skip-images` |
| `chapter-to-video.sh --list-themes` | 看所有主题 | — |
| `chapter-to-video.sh --help` | 看完整用法 | — |
