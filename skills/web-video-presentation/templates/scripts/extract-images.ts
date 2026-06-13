/**
 * extract-images.ts — collect every chapter's image spec and emit a flat
 * prompt list that the image pipeline can consume.
 *
 * Run via:
 *   npm run extract-images           # writes image-prompts.json
 *   npm run extract-images -- --print # also prints to stdout
 *   npm run extract-images -- --no-anchor # skip theme visualAnchors injection
 *
 * 输入 schema（per chapter, images.ts 导出 `images: ImageSpec[]`）：
 *
 *   {
 *     step:               number,                 // 1-indexed，与 step 对齐
 *     subject:            string,                 // 必填，画面主体
 *     composition?:       string,                 // 镜头 / 构图
 *     style?:             string,                 // 风格（ink-wash / oil / 3d / ...）
 *     palette?:           string,                 // 调色板描述（注入到 prompt）
 *     negative?:          string,                 // 反向 prompt
 *     size?:              "1920x1080" | ...,
 *     aspect?:            "16:9" | "4:3" | ...,
 *     seed?:              number,
 *     imageReference?:    "style-anchors/<name>.png",  // 参考图路径
 *     referenceStrength?: number,                 // 0~1
 *     out?:               "01-foo/1.png",         // 相对 vite/public 的输出
 *   }
 *
 * 主题注入：
 *   从 `shared/styles/tokens.css` 的注释头读 `theme-id`，再到
 *   `themes/<theme-id>/theme.json` 读 `visualAnchors.{palette,texture,compositionBias}`，
 *   自动注入每条 prompt 末尾。
 *
 * 输出：
 *   最终拼好的 `prompt` 字符串（章节 spec + 主题 anchor）+ 原始字段。
 *
 * 输出路径约定：`vite/public/images/<out>`（Remotion 模式由 render-remotion.sh 同步）。
 */
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, "..");
// tokens.css 候选路径：新布局 shared/styles/，旧布局 src/styles/，全找不到 → 主题锚点失效
const SHARED_STYLES_CANDIDATES = [
  resolve(ROOT, "shared/styles"),
  resolve(ROOT, "src/styles"),
];
const SHARED_STYLES = SHARED_STYLES_CANDIDATES.find((p) => existsSync(p)) ?? SHARED_STYLES_CANDIDATES[0]!;
// themes 目录：优先 WVP_THEMES_DIR（指向 skill 仓库），否则项目本地 themes/，最后兜底 ../themes
const THEMES_DIR = process.env.WVP_THEMES_DIR
  ? resolve(process.env.WVP_THEMES_DIR)
  : (existsSync(resolve(ROOT, "themes")) ? resolve(ROOT, "themes") : resolve(ROOT, "../themes"));
const REGISTRY_CANDIDATES = [
  resolve(ROOT, "vite/src/registry/chapters.ts"),
  resolve(ROOT, "src/registry/chapters.ts"),
];
const CHAPTERS_DIR_CANDIDATES = [
  resolve(ROOT, "shared/chapters"),
  resolve(ROOT, "src/chapters"),
];
const OUT_PATH = resolve(ROOT, "image-prompts.json");

// ── 输出 schema ────────────────────────────────────────────────
interface Prompt {
  chapter: string;
  step: number;
  prompt: string;                  // 拼好的最终 prompt
  size?: string;
  style?: string;
  negative?: string;
  seed?: number;
  imageReference?: string;
  referenceStrength?: number;
  out: string;
}

// ── 输入 schema ────────────────────────────────────────────────
interface ImageSpec {
  step?: number;                   // 可省，extract 时按数组下标补
  subject: string;
  composition?: string;
  style?: string;
  palette?: string;
  negative?: string;
  size?: string;
  aspect?: string;
  seed?: number;
  imageReference?: string;
  referenceStrength?: number;
  out?: string;
}

// ── helpers ────────────────────────────────────────────────────
function pickExisting(candidates: string[]): string {
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(
    `找不到 registry/chapters.ts，候选：\n  ${candidates.join("\n  ")}`,
  );
}

async function readThemeId(): Promise<string | null> {
  const tokensFile = join(SHARED_STYLES, "tokens.css");
  if (!existsSync(tokensFile)) return null;
  const src = await readFile(tokensFile, "utf8");
  // 兼容两种风格：`/* theme: <id> */` 和 `* Theme · <id>`（实际风格后一种，主题 tokens.css 第 2-3 行）
  const m = src.match(/[Tt]heme\s*[·:]\s*([a-z0-9-]+)/);
  return m ? m[1]! : null;
}

interface VisualAnchors {
  palette?: string;
  texture?: string;
  compositionBias?: string;
}

async function readVisualAnchors(themeId: string | null): Promise<VisualAnchors> {
  if (!themeId) return {};
  const themeJson = join(THEMES_DIR, themeId, "theme.json");
  if (!existsSync(themeJson)) return {};
  try {
    const data = JSON.parse(await readFile(themeJson, "utf8"));
    return data.visualAnchors ?? {};
  } catch {
    return {};
  }
}

/** 把 ImageSpec 拼成最终 prompt 字符串。 */
function buildPrompt(spec: ImageSpec, anchors: VisualAnchors): string {
  const parts: string[] = [];
  // 风格前缀（最显眼）
  const styleParts: string[] = [];
  if (spec.style) styleParts.push(spec.style);
  if (anchors.texture) styleParts.push(anchors.texture);
  if (styleParts.length) parts.push(styleParts.join(", "));

  // 主体
  parts.push(spec.subject);

  // 构图
  const compParts: string[] = [];
  if (spec.composition) compParts.push(spec.composition);
  if (anchors.compositionBias) compParts.push(anchors.compositionBias);
  if (compParts.length) parts.push(compParts.join("; "));

  // 调色板
  const paletteParts: string[] = [];
  if (spec.palette) paletteParts.push(spec.palette);
  if (anchors.palette) paletteParts.push(`palette: ${anchors.palette}`);
  if (paletteParts.length) parts.push(paletteParts.join("; "));

  return parts.filter(Boolean).join(". ");
}

/** 把 negative 串起来。 */
function buildNegative(spec: ImageSpec, anchors: VisualAnchors): string | undefined {
  const parts: string[] = [];
  if (spec.negative) parts.push(spec.negative);
  // AI 味兜底
  parts.push("purple-pink gradient, HDR, 3d render, photorealistic plastic, low quality, watermark, text, logo, blurry");
  if (anchors.palette) parts.push(`palette that conflicts with ${anchors.palette}`);
  return parts.filter(Boolean).join(", ");
}

// ── registry + chapter 解析（与 extract-narrations.ts 同源）──
async function readChapterOrder(): Promise<{ id: string; folder: string }[]> {
  const REGISTRY_PATH = pickExisting(REGISTRY_CANDIDATES);
  const src = await readFile(REGISTRY_PATH, "utf8");
  const ids: string[] = [];
  const folders: string[] = [];

  for (const m of src.matchAll(/id:\s*["']([^"']+)["']/g)) ids.push(m[1]!);
  for (const m of src.matchAll(
    /from\s+["'](?:@shared|(?:\.\.\/)+\s*(?:shared\/)?chapters)\/([^"'\/]+)\/(?:narrations|images)["']/g,
  )) {
    const folder = m[1]!;
    if (!folders.includes(folder)) folders.push(folder);
  }

  if (ids.length !== folders.length) {
    throw new Error(
      `chapter registry mismatch: ${ids.length} ids vs ${folders.length} folders`,
    );
  }
  return ids.map((id, i) => ({ id, folder: folders[i]! }));
}

async function loadImages(folder: string): Promise<ImageSpec[]> {
  const file = join(pickExisting(CHAPTERS_DIR_CANDIDATES), folder, "images.ts");
  if (!existsSync(file)) return [];
  const url = pathToFileURL(file).href;
  const mod = await import(url);
  if (!Array.isArray(mod.images)) {
    throw new Error(
      `images.ts in ${folder} must export an array named "images"`,
    );
  }
  return mod.images as ImageSpec[];
}

// ── main ───────────────────────────────────────────────────────
async function main() {
  const print = process.argv.includes("--print");
  const noAnchor = process.argv.includes("--no-anchor");
  const order = await readChapterOrder();

  const themeId = await readThemeId();
  const anchors = noAnchor ? {} : await readVisualAnchors(themeId);
  if (themeId) {
    console.error(`▸ 主题: ${themeId}` +
      (Object.keys(anchors).length
        ? ` (palette=${anchors.palette ? "✓" : "✗"} texture=${anchors.texture ? "✓" : "✗"} composition=${anchors.compositionBias ? "✓" : "✗"})`
        : " (无 visualAnchors)"));
  }

  const prompts: Prompt[] = [];
  for (const { id, folder } of order) {
    const arr = await loadImages(folder);
    if (arr.length === 0) {
      console.error(`  (skip) ${folder}/images.ts 不存在或为空`);
      continue;
    }
    arr.forEach((spec, i) => {
      if (typeof spec?.subject !== "string" || spec.subject.trim() === "") {
        throw new Error(
          `${folder} images[${i}].subject 必须是非空字符串`,
        );
      }
      const step = spec.step ?? (i + 1);
      const prompt = buildPrompt(spec, anchors);
      const negative = buildNegative(spec, anchors);
      const out = spec.out ?? `images/${folder}/${step}.png`;

      prompts.push({
        chapter: id,
        step,
        prompt,
        size: spec.size ?? (spec.aspect ? undefined : "1920x1080"),
        style: spec.style,
        negative,
        seed: spec.seed,
        imageReference: spec.imageReference,
        referenceStrength: spec.referenceStrength,
        out,
      });
    });
  }

  await writeFile(OUT_PATH, JSON.stringify(prompts, null, 2) + "\n", "utf8");

  console.error(
    `✓ extracted ${prompts.length} prompts from ${order.length} chapters`,
  );
  console.error(`  → ${OUT_PATH}`);
  if (print) console.log(JSON.stringify(prompts, null, 2));
}

main().catch((err) => {
  console.error(`✗ ${err.message ?? err}`);
  process.exit(1);
});
