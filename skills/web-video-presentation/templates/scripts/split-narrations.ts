/**
 * split-narrations.ts —— LLM 驱动的口播稿分句器。
 *
 * 把粗粒度口播稿（任意长度）拆成 8-15 字/步 的细粒度 narrations。
 * 视觉锚点 hint 同时生成，与 check-alignment HINT 校验对齐。
 *
 * 用法：
 *   ANTHROPIC_API_KEY=sk-... npx tsx scripts/split-narrations.ts \
 *     --input=script.md \
 *     --output=shared/chapters/01-foo/narrations.ts \
 *     --chapter=01-foo
 *
 * 可选：
 *   --hint-style=visual|keyword|concise  默认 visual（视觉锚点）
 *   --model=claude-haiku-4-5              默认 haiku（便宜够用）
 *   --max-chars=15                        默认 15（单 step 上限）
 *   --min-chars=8                         默认 8（单 step 下限）
 *
 * 不实现：
 *   • 离线规则模式（已迁到 extract-narrations.ts --auto-split 的 deprecated 兜底）
 *   • 多语言混合分句（仅中文）
 */

import { readFile, writeFile } from "node:fs/promises";

interface Step {
  text: string;
  hint: string;
}

const HINT_STYLE_DESC: Record<string, string> = {
  visual: "视觉锚点（这一帧画面必须出现的元素、构图、调性，5-10 字）",
  keyword: "关键词（这步口播里最显眼的实体/数字/术语，1-3 字）",
  concise: "语义摘要（人物/动作/场景/数字/转折，5-10 字）",
};

interface Args {
  input: string;
  output: string;
  chapter: string;
  hintStyle: keyof typeof HINT_STYLE_DESC;
  model: string;
  minChars: number;
  maxChars: number;
  print: boolean;
}

function parseArgs(): Args {
  const get = (key: string) =>
    process.argv.find((a) => a.startsWith(`--${key}=`))?.slice(`--${key}=`.length);

  const input = get("input");
  const output = get("output");
  const chapter = get("chapter");
  if (!input || !output || !chapter) {
    console.error(
      `用法: split-narrations.ts --input=<script.md> --output=<narrations.ts> --chapter=<id>\n` +
        `可选: --hint-style=visual|keyword|concise --model=<id>`,
    );
    process.exit(2);
  }

  const hintStyleRaw = get("hint-style") ?? "visual";
  if (!(hintStyleRaw in HINT_STYLE_DESC)) {
    console.error(`✗ --hint-style 必须是 ${Object.keys(HINT_STYLE_DESC).join(" / ")} 之一`);
    process.exit(2);
  }

  return {
    input,
    output,
    chapter,
    hintStyle: hintStyleRaw as keyof typeof HINT_STYLE_DESC,
    model: get("model") ?? "claude-haiku-4-5",
    minChars: Number(get("min-chars") ?? 8),
    maxChars: Number(get("max-chars") ?? 15),
    print: process.argv.includes("--print"),
  };
}

function buildPrompt(text: string, args: Args): string {
  // 转义原文里的 """ 防破 prompt 包裹
  const safeText = text.replace(/"""/g, '\\"\\"\\"');
  return `你是中文口播稿分句器。把下面这段口播稿拆成 step 数组。

## 规则

- 每 step **${args.minChars}-${args.maxChars} 字**（中文 ${args.minChars / 4}-${args.maxChars / 4} 秒口播速度）
- 强标点（。！？；）**必须**切
- 长段（>${args.maxChars} 字）按**语义短语**切（名词短语、动宾结构、时间地点状语），不机械按标点
- 短段（<${args.minChars} 字）与**前后相邻段合并**形成语义完整的 step
- 每 step 配一个 hint：${HINT_STYLE_DESC[args.hintStyle]}
- hint 长度 3-10 字
- 保留原文标点（切完后每段末尾可保留原标点）

## 输出

仅输出 JSON 数组（不要其他文字、不要 markdown 代码块）：
[
  { "text": "今天讲一本书。", "hint": "书的开场 暖光" },
  { "text": "1920 年代巴黎。", "hint": "时间地点 复古" },
  ...
]

## 原文

"""
${safeText}
"""`;
}

async function callClaude(prompt: string, model: string, apiKey: string): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }],
    }),
  });
  if (!r.ok) {
    const text = await r.text();
    throw new Error(`Claude API ${r.status}: ${text.slice(0, 200)}`);
  }
  const data = (await r.json()) as {
    content: Array<{ type: string; text: string }>;
  };
  return data.content[0]!.text;
}

function parseJsonResponse(raw: string): Step[] {
  // 容错：剥离 markdown 代码块包裹（即使 prompt 说了不要）
  let s = raw.trim();
  if (s.startsWith("```")) {
    s = s.replace(/^```(?:json)?\s*\n?/, "").replace(/\n?```\s*$/, "");
  }
  // 截取第一个 [ 到最后一个 ]
  const start = s.indexOf("[");
  const end = s.lastIndexOf("]");
  if (start < 0 || end < 0) {
    throw new Error(`响应找不到 JSON 数组：\n${raw.slice(0, 200)}`);
  }
  s = s.slice(start, end + 1);
  const parsed = JSON.parse(s);
  if (!Array.isArray(parsed)) throw new Error("响应不是数组");
  return parsed.map((x: unknown, i: number) => {
    if (typeof x !== "object" || x === null) {
      throw new Error(`step ${i + 1} 不是对象`);
    }
    const obj = x as Record<string, unknown>;
    if (typeof obj.text !== "string" || typeof obj.hint !== "string") {
      throw new Error(`step ${i + 1} 缺 text 或 hint`);
    }
    return { text: obj.text, hint: obj.hint };
  });
}

function warnLength(steps: Step[], args: Args): void {
  const HINT_MIN = 3;
  const HINT_MAX = 10;
  for (const [i, s] of steps.entries()) {
    const len = [...s.text.trim()].length;
    if (len < args.minChars || len > args.maxChars) {
      console.warn(`  ⚠ step ${i + 1} text 长度 ${len} 字（建议 ${args.minChars}-${args.maxChars}）：${s.text}`);
    }
    const hintLen = [...s.hint.trim()].length;
    if (hintLen < HINT_MIN || hintLen > HINT_MAX) {
      console.warn(`  ⚠ step ${i + 1} hint 长度 ${hintLen} 字（建议 ${HINT_MIN}-${HINT_MAX}）：${s.hint}`);
    }
  }
}

function renderNarrationsTs(steps: Step[]): string {
  return `/**
 * Auto-generated by split-narrations.ts.
 * 8-15 字/步（2-3 秒中文口播），适合三档密度：
 *   bilibili 3 步合 1 屏 · wechat 2 步合 1 屏 · douyin 1 步 1 屏
 */
export const narrations = [
${steps
  .map(
    (s) =>
      `  { text: ${JSON.stringify(s.text)}, durationInFrames: 0, hint: ${JSON.stringify(s.hint)} },`,
  )
  .join("\n")}
] as const;
`;
}

/** 调 Claude API 拆 step，2 次重试。返回 Step[] 或 throw。 */
async function splitByClaude(text: string, args: Args, apiKey: string): Promise<Step[]> {
  const prompt = buildPrompt(text, args);
  let lastErr: Error | null = null;
  for (let attempt = 1; attempt <= 2; attempt++) {
    try {
      const raw = await callClaude(prompt, args.model, apiKey);
      return parseJsonResponse(raw);
    } catch (e) {
      lastErr = e as Error;
      console.warn(`⚠ 第 ${attempt} 次失败，重试：${lastErr.message}`);
    }
  }
  throw lastErr ?? new Error("split 失败（无具体错误）");
}

async function main() {
  const args = parseArgs();
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error("✗ 缺 ANTHROPIC_API_KEY 环境变量");
    console.error("  export ANTHROPIC_API_KEY=sk-...");
    process.exit(2);
  }

  const script = await readFile(args.input, "utf-8");
  console.error(`▸ 输入：${args.input}（${[...script.trim()].length} 字）`);
  console.error(`▸ 模型：${args.model} · hint: ${args.hintStyle}`);

  const steps = await splitByClaude(script, args, apiKey);
  console.error(`▸ 输出 ${steps.length} 个 step`);
  warnLength(steps, args);

  const code = renderNarrationsTs(steps);
  await writeFile(args.output, code, "utf-8");
  console.error(`✓ → ${args.output}`);

  if (args.print) {
    console.log("\n── narrations.ts ──");
    console.log(code);
  }
}

main().catch((e) => {
  console.error(`✗ ${(e as Error).message ?? e}`);
  process.exit(1);
});