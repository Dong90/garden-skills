# 5 层自检 checklist

`chapter-to-video.sh selftest` 自动跑这 5 项。任一不通过 → 修完再 selftest。

## 第 1 层 · 信息保留度 ≥ 60%

```
script.md CJK 字符数 / article.md CJK 字符数 ≥ 60%
```

**判定**：低于 60% = 重要信息丢失 = 重写。

**修法**：把 article 里的关键事实/案例/数据**展开**到 script 里（不是"换说法"，是"换说法 + 保留"）。

## 第 2 层 · 去 AI 味 5 类

扫描 AI 高频词：
- 说白了 / 本质上 / 底层逻辑
- 恰恰 / 正是因为
- 归根结底 / 换句话说
- 在某种程度上

**判定**：任意一处出现 = 立即改掉（5 类都是 AI 写稿的指纹，念出来一听就腻）。

**修法**：删掉这些词，意思不变 → 说明本来就在用修辞凑数；变了 → 用具体例子 / 事实替代。

## 第 3 层 · 念出来节奏

```
script.md 用 --- 切分节拍 ≥ 2
```

**判定**：整段一坨 = 没节奏 = 录屏时一口气念完观众跟不上。

**修法**：按"一个想法 = 一个 step = 一段独立段落"切，段间用 `---` 分隔。

## 第 4 层 · outline 字段完整性

每章 outline 必须含：
- 信息池
- 场景卡
- 摘句池

**判定**：缺任一 = 章节 agent 实现时画面无素材 = 必出"整章只有纯文字"的红线问题。

## 第 5 层 · 书籍章节特化（仅当 article 是书籍章节时）

| 检查项 | 必填 |
|---|---|
| 场景卡含：主场景 | ✓ |
| 场景卡含：关键物件 | ✓ |
| 场景卡含：在场角色 | ✓ |
| 摘句池 ≥ 2 句原话 | ✓ |

**判定**：场景卡 = 画面的物质基础；摘句 = 章节灵魂，缺一不可。

---

## 跑法

```bash
# 1. 先 init
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/chapter.md --theme=kraft-paper

# 2. 让 agent 生成 script.md + outline.md
# （在 Cursor 里 /chapter-to-video）

# 3. 跑 selftest
bash skills/web-video-presentation/scripts/chapter-to-video.sh selftest my-video

# 4. 失败就修，5/5 通过才进 Phase 2
```

## 与 SCRIPT-STYLE.md 自检的关系

SCRIPT-STYLE.md §「形式 / 风骨 / 念出来」3 层（对应本文件第 1-3 层）
+ SCRIPT-STYLE.md §「念出来测试」= 第 3 层强化版
+ BOOK-CHAPTER.md §8 第 5 层（场景卡 / 摘句池）= 本文件第 5 层
