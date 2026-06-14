/**
 * extract-narrations.ts — collect every chapter's narration array and emit
 * a flat segment list that the TTS pipeline can consume.
 *
 * Run via:
 *   npm run extract-narrations           # writes audio-segments.json
 *   npm run extract-narrations -- --print # also prints to stdout
 *   npm run extract-narrations -- --auto-split  # DEPRECATED: 中文规则引擎拆句不准确
 *
 * 推荐：作者直接写细粒度 narrations.ts（每 step 8-15 字）；
 *       或先用 npm run split-narrations（LLM）拆好再 extract。
 *
 * Reads chapter order from src/registry/chapters.ts via a simple regex
 * (no React/CSS evaluation needed). For each chapter it dynamically
 * imports `src/chapters/<NN>-<id>/narrations.ts` (which is React-free)
 * and flattens to:
 *
 *   [
 *     { chapter, step, text, audio: "<chapter>/<step>.mp3" },
 *     ...
 *   ]
 *
 * Step indices in the JSON are 1-indexed, matching the audio file naming
 * convention (`public/audio/<chapter>/<N>.mp3`).
 *
 * Empty narration strings are skipped (silent steps don't need a TTS file).
 */
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { resolveProjectPaths } from "./paths";

const { registryPath: REGISTRY_PATH, chaptersDir: CHAPTERS_DIR, audioSegmentsPath: OUT_PATH } = resolveProjectPaths();

/**
 * 按中英文标点把长口播拆成多个 step。
 * 写稿铁律：每步 8-15 字（2-3 秒中文口播）。
 * 拆分规则：
 *   1. 先按强标点（句号/问号/感叹号/分号）切
 *   2. 切完后 > 15 字的段落再用逗号切
 *   3. < 8 字的相邻段向前合并（直到 ≥ 8）
 *   4. 仍 > 20 字：硬切到 15 字（兜底，不保证语义）
 *
 * Bug 修复：
 *   - `RegExp.test()` 是有状态的，连续用 .test() 第二次会假阳性 → 改用 .match()
 *   - 合并时用「无空格真实长度」判断（trim 后），避免把分隔空格算进去
 */
export function splitByPunctuation(text: string): string[] {
  const STEP_MIN = 8;
  const STEP_MAX = 15;
  const HARD_MAX = 20;
  const charLen = (s: string) => [...s.trim()].length;

  // 1. 强标点切（保留标点在上段末尾）
  const parts: string[] = [];
  let buf = "";
  for (const ch of text) {
    buf += ch;
    if (ch.match(/[。！？；]/)) {
      parts.push(buf.trim());
      buf = "";
    }
  }
  if (buf.trim()) parts.push(buf.trim());

  // 2. > 15 字用逗号切（保留逗号在上一段末尾）
  const split: string[] = [];
  for (const p of parts) {
    if (charLen(p) <= STEP_MAX) {
      split.push(p);
      continue;
    }
    const commaParts = p.split(/(,|，)/);
    let cur = "";
    for (const cp of commaParts) {
      const candidate = cur + cp;
      if (charLen(candidate) > STEP_MAX && cur.trim() !== "") {
        split.push(cur.trim());
        cur = cp;
      } else {
        cur = candidate;
      }
    }
    if (cur.trim()) split.push(cur.trim());
  }

  // 3. 合并 < 8 字的相邻段（向后吃）
  const merged: string[] = [];
  for (const s of split) {
    if (!merged.length || charLen(merged[merged.length - 1]!) >= STEP_MIN) {
      merged.push(s);
    } else {
      // 直接拼接（不加空格），避免把分隔字符算进长度
      merged[merged.length - 1] = (merged[merged.length - 1]! + s).trim();
    }
  }

  // 4. 兜底硬切 > HARD_MAX
  const final: string[] = [];
  for (const s of merged) {
    if (charLen(s) <= HARD_MAX) {
      final.push(s);
      continue;
    }
    const chars = [...s];
    for (let i = 0; i < chars.length; i += STEP_MAX) {
      final.push(chars.slice(i, i + STEP_MAX).join(""));
    }
  }
  return final;
}

interface Segment {
  chapter: string;
  step: number;
  text: string;
  audio: string;
}

/** Parse `src/registry/chapters.ts` to learn chapter id order. */
async function readChapterOrder(): Promise<{ id: string; folder: string }[]> {
  const src = await readFile(REGISTRY_PATH, "utf8");
  // 双模式项目匹配：@shared（vite 别名）| ../../../shared/chapters | ../chapters（旧 fallback）
  const ids: string[] = [];
  const folders: string[] = [];

  for (const m of src.matchAll(/id:\s*["']([^"']+)["']/g)) ids.push(m[1]!);

  // 优先 folder: 字段，否则从 import 推导
  const explicitFolders = [...src.matchAll(/folder:\s*["']([^"']+)["']/g)].map((m) => m[1]!);
  if (explicitFolders.length === ids.length && explicitFolders.length > 0) {
    folders.push(...explicitFolders);
  } else {
    for (const m of src.matchAll(
      /from\s+["'](?:@shared|(?:\.\.\/)+\s*(?:shared\/)?chapters)\/([^"'\/]+)\/(?:narrations|images)["']/g,
    )) {
      const folder = m[1]!;
      if (!folders.includes(folder)) folders.push(folder);
    }
  }

  if (ids.length !== folders.length) {
    throw new Error(
      `chapter registry mismatch: ${ids.length} ids vs ${folders.length} folders`,
    );
  }
  return ids.map((id, i) => ({ id, folder: folders[i]! }));
}

async function loadNarrations(folder: string): Promise<unknown[]> {
  const file = join(CHAPTERS_DIR, folder, "narrations.ts");
  if (!existsSync(file)) {
    throw new Error(`missing narrations.ts: ${file}`);
  }
  const url = pathToFileURL(file).href;
  const mod = await import(url);
  if (!Array.isArray(mod.narrations)) {
    throw new Error(
      `narrations.ts in ${folder} must export an array named "narrations"`,
    );
  }
  return mod.narrations as unknown[];
}

async function main() {
  const print = process.argv.includes("--print");
  const autoSplit = process.argv.includes("--auto-split");
  if (autoSplit) {
    // 直接退出，强制用户用 split-narrations
    console.error(
      "✗ --auto-split 已废弃（与 audio 文件名协议冲突，会破坏 I4 校验）。\n" +
        "改用: npm run split-narrations -- --input=<script.md> --output=<narrations.ts>",
    );
    process.exit(1);
  }
  const order = await readChapterOrder();

  const segments: Segment[] = [];
  let silentSteps = 0;
  for (const { id, folder } of order) {
    const arr = await loadNarrations(folder);
    arr.forEach((entry, i) => {
      const step = i + 1;
      // 双模式 narrations 元素是 { text, durationInFrames, hint? } 或 string
      const rawText = typeof entry === "string" ? entry : (entry as { text: string }).text;
      if (rawText == null) {
        throw new Error(
          `chapter "${id}" step ${step}: missing text field. ` +
            `Expected string or { text, durationInFrames, hint? }`,
        );
      }
      // --auto-split 已在 main 顶部 throw，此处不会再走到
      if (rawText.trim() === "") {
        silentSteps++;
      } else {
        segments.push({
          chapter: id,
          step,
          text: rawText,
          audio: `${id}/${step}.mp3`,
        });
      }
    });
  }

  await writeFile(OUT_PATH, JSON.stringify(segments, null, 2) + "\n", "utf8");

  console.error(
    `✓ extracted ${segments.length} segments from ${order.length} chapters` +
      (silentSteps > 0 ? ` (skipped ${silentSteps} silent steps)` : ""),
  );
  console.error(`  → ${OUT_PATH}`);
  if (print) console.log(JSON.stringify(segments, null, 2));
}

main().catch((err) => {
  console.error(`✗ ${err.message ?? err}`);
  process.exit(1);
});
