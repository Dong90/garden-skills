# 书籍章节 → 口播稿 / outline 专属指南

> 通用 8 条原则 + 去 AI 味五类见 `SCRIPT-STYLE.md`。
> 章节实现十条原则见 `CHAPTER-CRAFT.md`。outline 字段见 `OUTLINE-FORMAT.md`。
> **本文件只补书籍章节独有的规则；与上面冲突时以本文件为准。**

---

## 0. 为什么需要特化

通用 SCRIPT-STYLE 假设输入 ≈ 1500-3000 字的"公众号 / 博客 / 论文"。
书籍章节常 5000-15000 字，且**有四样东西是公众号没有的**：

1. **作者声口** —— 翻译得"太顺"反而把作者磨平
2. **场景 / 角色卡** —— 画面密度全靠它撑
3. **摘句** —— 章节灵魂，需要独占整屏
4. **分集决策** —— 一章到底做 30 分钟还是拆 3 集，**先问后做**

---

## 1. 长度处理：先问"分集还是拉长"，再决定压缩

**通用 60% 留存**在书籍章节是**软上限**，不是硬规则。

### 1.1 第一步：估时

```
估算视频时长 = ceil(章节字数 / 200)  分钟     # 文学用 200 字/分，不是默认 250
```

### 1.2 第二步：分档决策

| 章节字数 | 估时 | 默认动作 | 例外 |
|---|---|---|---|
| < 3000 | < 15 分钟 | 单集直接做 | —— |
| 3000-5000 | 15-25 分钟 | **先问用户**："单集长版 or 拆 2 集？" | 用户没回 → 单集 |
| 5000-8000 | 25-40 分钟 | **先问用户**："单集慢版 or 拆 2-3 集？" | 用户没回 → 拆 2 集（更安全） |
| > 8000 | > 40 分钟 | **强烈建议拆集**，主动给方案 | 散文 / 抒情可拉长单集 |

### 1.3 用户回复模板

> 这章 X 字，按 200 字/分估时 ~Y 分钟。Y 偏长，建议你选一个：
>
> A) **拆 2-3 集**：第 1 集到「<自然断点>」停下，约 8-10 分钟；其余 1-2 集各自独立完整
> B) **单集慢版**：一镜到底 25-30 分钟，每章 30-40 步，每步 35-50 秒
> C) **你来定**（告诉我你想要几分钟）
>
> 默认 A。

### 1.4 绝对禁止

- ❌ 静默压到 30% 交付（信息丢失 = 失败）
- ❌ 把作者写得好的长句硬拆成短句（伤声口，见 §2）
- ❌ 删心理活动 / 内心独白（这是文学章节最重要的画面素材）

---

## 2. 声口保留：通用原则里"短句 ≤ 20 字"降级为参考

### 2.1 三类段落，三种处理

| 段落类型 | 通用 8 条 | 书籍章节特化 |
|---|---|---|
| **作者叙述 / 描写段** | 短句、口语、第二人称 | **保留长句节奏** —— 删修饰词，但保留句式 |
| **人物对白段** | 口语化 | **原样保留**（带引号），不"口播化" —— 对白是声音表演的素材 |
| **心理活动 / 意识流段** | 短句 | **保持原顺序**，可拆短但**不能改意** |

### 2.2 判定标准

**关掉屏幕念一遍脚本，能不能听出是这位作者写的**。
- 听不出 → 改坏了，声口被磨平
- 听得出 → 通过

### 2.3 三组 before/after 范例

**例 ① —— 描写段（保留长句）**

```diff
- 夕阳的余晖洒在古老的青石板路上，把每一块石头都染成了金红色，
  空气中弥漫着桂花的香气，让人感到一种说不出的宁静。
+ 夕阳的余晖洒在古老的青石板路上。
+ 把每一块石头都染成了金红色。
+ 空气里飘着桂花香。
+ 说不出的那种宁静。
```

✓ 拆成 4 步对应 4 个 step，但**每步都保留原文的具象感**。

**例 ② —— 对白段（原样保留）**

```diff
- "你怎么又来了？"她有点生气地说，"我不是告诉过你不要再来找我了吗？"
+ "你怎么又来了？"
+ "我不是告诉过你不要再来找我了吗？"
```

✓ 拆成 2 步，但**完全不改写对白**。

**例 ③ —— 心理活动（保顺序，可短不可改）**

```diff
- 他想，如果当初没有离开家乡，现在可能已经在城里安家了，
  但他又庆幸自己走了出来，因为他知道，只有在外面才能实现自己的梦想。
+ 他想，如果当初没离开家乡，现在可能已经在城里安家了。
+ 但他又庆幸自己走了出来。
+ 因为他知道，只有在外面才能实现自己的梦想。
```

✓ 保留三段心理的**因果顺序**。

---

## 3. 场景 / 角色 / 时间卡：outline 必填新增字段

通用 outline 信息池只列数字 / 引用 / 案例。**书籍章节必须多两层**：

### 3.1 场景卡（每章首段必填）

```markdown
**场景卡**：
- **主场景**：<地点 / 时间 / 季节 / 光线>           ——  article §X
- **次场景**（如有）：<地点 / 时间>                ——  article §X
- **关键物件**（3-5 件有叙事功能的物）：            ——  article §X
- **在场角色**（按首次出场顺序）：                  ——  article §X
- **氛围基线**：<孤独 / 温暖 / 紧张 / 怀旧 / ...>
```

### 3.2 摘句池（每章末尾必填）

```markdown
**摘句池**（chapter agent 优先做成「独立一屏 = 一 step」的卡片）：
- "原句 1"  ——  article §X / Lxx
- "原句 2"  ——  article §X / Lxx
- "原句 3"  ——  article §X / Lxx
```

**判定标准**：这句话去掉上下文还能不能成立？能 → 进摘句池。

**实现细节**：摘句做成「独立 step」时，画面**只有这一句 + 极小出处**（作者 + 章节名）。字体大、留白多、不挂任何装饰。

---

## 4. 主题推荐矩阵（按书的类型）

| 书的类型 | 推荐主题（按优先级） | 避开 |
|---|---|---|
| 文学 / 小说 / 随笔 | kraft-paper · paper-press · vintage-editorial · forest-ink | neon-cyber · blueprint · electric-studio |
| 散文 / 自传 / 慢生活 | chalk-garden · kraft-paper · dark-botanical | bauhaus-bold · bold-signal · electric-studio |
| 历史 / 纪实 / 旅行 | kraft-paper · vintage-editorial · forest-ink | pastel-dream · neon-cyber |
| 哲学 / 思辨 / 社科 | indigo-porcelain · midnight-press · swiss-ikb | pastel-dream · chalk-garden |
| 科幻 / 未来 | neon-cyber · dark-botanical · blueprint | kraft-paper · vintage-editorial |
| 诗 / 短篇集 | pastel-dream · chalk-garden · paper-press | bauhaus-bold · electric-studio |
| 推理 / 悬疑 | midnight-press · indigo-porcelain · neon-cyber | pastel-dream · chalk-garden |
| 儿童 / 童话 | pastel-dream · chalk-garden · paper-press | midnight-press · neon-cyber |

---

## 5. 节奏调整：文学默认 200 字/分

| 书的类型 | 节奏（字/分） | 单句上限 | 单 step 时长 |
|---|---|---|---|
| 文学 / 小说 | 200 | 25 字 | 35-50 秒 |
| 散文 / 诗 | 180 | 30 字 | 40-60 秒 |
| 思辨 / 社科 | 220 | 22 字 | 30-45 秒 |
| 科幻 / 推理 | 240 | 20 字 | 25-40 秒 |
| 历史 / 纪实 | 220 | 22 字 | 30-45 秒 |

> **为什么文学要慢**：观众看视频的时间窗口比看书更窄；文学的"慢"是**主动留白**，让一句金句 / 一处描写能被眼睛和耳朵"接住"。

---

## 7. 图片生成（可选 · 让视频感更强）

> 通用 SCRIPT-STYLE 没要求图片，**但**「整章只有纯文字 = 验收不过」
> 是 CHAPTER-CRAFT.md 的硬红线。本节给书籍章节一个零摩擦的图源。

### 7.1 工作流

1. **在每个章节的 `images.ts`** 里声明要生成的图片（与 `narrations.ts` 同级）：
   ```ts
   export const images = [
     { prompt: "a serene mountain lake at dawn", size: "1920x1080" },
     { prompt: "奥雷里亚诺上校站在行刑队前的剪影", size: "1920x1080", style: "kraft-paper" },
   ];
   ```
2. **跑提取**：`npm run extract-images` → 生成 `image-prompts.json`（步骤真相源）
3. **跑生成**：`npm run synthesize-images` → 输出到 `public/images/<id>/<N>.png`
4. **章节 `.tsx` 引用**：`import bg from "/images/01-opening/1.png"` → 挂到 step 背景

### 7.2 provider：minimax 默认

镜像 TTS 的 provider 架构 —— `scripts/image-providers/<name>.sh` 一个文件 + 3 个函数：

| 函数 | 作用 |
|---|---|
| `image_check` | 前置依赖（mmx CLI / API key） |
| `image_install_help` | 缺依赖时的安装提示 |
| `image_generate <prompt_json> <out_path>` | 真生成 |

**默认 provider = minimax**（与 TTS 同源：mmx CLI 同一套鉴权）。

换 / 加 provider：
```bash
# 换
PRESENTATION_IMG=openai npm run synthesize-images

# 加：见 scripts/image-providers/README.md（5 段现成片段：openai / stability / replicate / 本地 diffusers / mock）
```

### 7.3 prompt 字段

```ts
{
  prompt:   string,              // 必填
  size?:    "1920x1080" | ...,   // 默认 "1920x1080"（16:9 舞台，1920×1080 像素）
  style?:   string,              // 主题气质（kraft-paper / neon-cyber / ...）— minimax 透传给 mmx
  negative?:string,              // 反向提示词
  seed?:    number,              // 固定 seed → 可复现
}
```

### 7.4 书籍章节的图源原则

- **场景卡里的"关键物件"** → 必出图（占独立 step 背景）
- **氛围基线**（孤独 / 温暖 / 怀旧）→ 出 1-2 张氛围图作章节底色
- **摘句独立屏** → 纯文字 step，**禁图**（破坏留白）
- **场景切换**（时间 / 空间 / POV）→ 各出 1 张作新场景建立
- **少于 3 张图就别上** —— placeholder 占位卡更好，硬塞的图比缺图更糟

### 7.5 主题 × 图片风格映射

| 主题 | minimax `--style` 推荐 |
|---|---|
| kraft-paper / paper-press / vintage-editorial | `ink-wash` / `woodcut` / `risograph` |
| forest-ink / dark-botanical | `botanical-illustration` / `muted-pastel` |
| indigo-porcelain / midnight-press | `blueprint` / `ink-line` |
| neon-cyber / blueprint | `synthwave` / `iso-tech` |
| pastel-dream / chalk-garden | `soft-watercolor` / `paper-collage` |

> 风格名是**建议**，minimax 接受任意 string；`style` 字段 = 透传给 mmx 的 `--style` 参数。

---

## 8. 质量门：书籍章节自检（通用 4 层 + 第 5 层）

通用 SCRIPT-STYLE 自检 4 层（形式 / 风骨 / 念出来 / outline 字段）**全部照做**。
**第 5 层**（书籍章节独有）：

- [ ] 章节字数 < 5000 → 单集；5000-8000 → 问过用户；> 8000 → 已拆集
- [ ] 信息保留度 ≥ 60%（按 article 字数算）
- [ ] 描写段：保留长句节奏
- [ ] 对白段：原样保留
- [ ] 心理段：保持原顺序
- [ ] 每章场景卡完整（主场景 / 物件 / 角色 / 氛围）
- [ ] 每章摘句池 3-5 句，**且是 article 原话**
- [ ] 主题选择符合 §4 矩阵
- [ ] 节奏字/分符合 §5 表
- [ ] 多集情况：每集 outline 都有独立 hook

任一未过 → 改完再交付。
