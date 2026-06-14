# check-alignment.ts — 跨管道对齐校验

## 是什么

在 extract 之后、synthesize 之前跑。校验 4 条不变式 + hint 软必填，
确保 narrations / images / 章节 .tsx / audio-segments 不会互相错位。

## 用法

```bash
npm run check-alignment           # 默认：ERROR 阻塞，WARN 不阻塞
npm run check-alignment:strict    # WARN 升级为 ERROR（含 HINT）
npm run check-alignment:dry       # 报错但不 exit 1，一次性看全错
```

> **`--strict` 的副作用**：会强制所有 narrations 必须有 hint 字段（否则 HINT 升级为 ERROR）。
> 老项目第一次开 strict 会大量报错——建议先跑一次 `npm run check-alignment:strict -- --dry-run` 看影响范围。

## 不变式一览

| 代码 | 含义 | 级别 | 失败信号 |
|---|---|---|---|
| I1 | narrations.length == tsx 里最大 step + 1，且 step 连续无缺 | ERROR | 视频少一屏 / 多一黑屏 |
| I2 | images.ts step ∈ [1..narLen] 且不重复，subject 必填 | ERROR | 图片出现在没口播的 step |
| I3 | tsx 引图 ⊆ images.ts step 集合；引图但无 images.ts | ERROR | render 时 404 |
| I4 | audio-segments 数 == narrations 非空 text 数 | ERROR | synthesize 时找不齐 mp3 |
| HINT | narrations[i].hint 缺失 | WARN | 画面没视觉锚点提示 |

## 典型工作流

```bash
# 编辑章节 / 加新章后
npm run extract-narrations
npm run extract-images
npm run check-alignment          # ← 闸门
npm run check-alignment -- --dry-run   # 看全部错一起改
npm run synthesize-audio
npm run synthesize-images
```

## 错误信息解读

每条错误三段：[code] chapter: 描述 / 行号 / → 修复建议。例如：

```
[I2] 01-foo: images[2] step=5 超出 [1..3]
      改 images.ts:7: { step: 5, ... } → { step: 3, ... }
```

## JSON 报告

输出 `alignment-report.json`（项目根），CI / pre-commit hook 可消费：

```json
{
  "generatedAt": "...",
  "chapters": 5,
  "errors": [{ "chapter", "code", "msg", "fix" }],
  "warnings": [...],
  "summary": { "errors": 0, "warnings": 2 }
}
```

## 故障排查

### "找不到 registry/chapters.ts"
你不在项目根。`cd` 到含 `vite/src/registry/chapters.ts` 的目录。

### "registry mismatch: N ids vs M folders"
`vite/src/registry/chapters.ts` 里 `id` 和 `folder`（或 import 路径推出来的 folder）数量对不上。
要么在某项里漏写 `folder:` 字段，要么 import 路径写错。

### "missing narrations.ts: ..."
`shared/chapters/<folder>/narrations.ts` 不存在。每个 chapter 至少要有 `narrations.ts` 和 `<ClassName>.tsx`。

### audio-segments.json 缺失导致 I4 被跳过
I4 需要 `audio-segments.json` 存在（默认在项目根）。
跑 `npm run extract-narrations` 先生成；或暂时挪走 audio-segments.json 让 I4 静默跳过（不推荐）。

## TDD 模式

测试套件在 `tests/check-alignment.test.ts`，11 个 case 覆盖所有不变式 + 边界。
跑：

```bash
npm test
npm run test:check-alignment
```

fixture 在 `fixtures/check-alignment/`，每个 case 是独立项目根。

## 与 extract 的关系

```
extract-narrations  →  audio-segments.json
extract-images      →  image-prompts.json
                            ↓
                    check-alignment   ← 闸门
                            ↓
                    synthesize / probe / render
```

## 不做什么（刻意不做）

- ❌ I5/I6/I7 语义校验（hint 字符串匹配 / 内容词交集 / prompt 质量启发式）——
  上轮对话已确认过度设计，假阳假阴率高
- ❌ 自动修复——脚本不修改业务代码
- ❌ 视觉验证——靠 Phase 2.2 第 1 章人工验收

## 相关

- [SKILL.md §Phase 1.2 内容编写](../../SKILL.md)
- [references/REMOTION-MAPPING.md](../../references/REMOTION-MAPPING.md)
