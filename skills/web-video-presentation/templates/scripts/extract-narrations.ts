/**
 * extract-narrations.ts — collect every chapter's narration array and emit
 * a flat segment list that the TTS pipeline can consume.
 *
 * Run via:
 *   npm run extract-narrations           # writes audio-segments.json
 *   npm run extract-narrations -- --print # also prints to stdout
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
import { resolve, dirname, join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, "..");
// 双模式项目：registry 在 vite/，但章节代码在 shared/。先看 vite 的，没就兜底。
const REGISTRY_CANDIDATES = [
  resolve(ROOT, "vite/src/registry/chapters.ts"),
  resolve(ROOT, "src/registry/chapters.ts"),
];
const CHAPTERS_DIR_CANDIDATES = [
  resolve(ROOT, "shared/chapters"),
  resolve(ROOT, "src/chapters"),
];
const OUT_PATH = resolve(ROOT, "audio-segments.json");

function pickExisting(candidates: string[]): string {
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(
    `找不到 registry/chapters.ts，候选：\n  ${candidates.join("\n  ")}`,
  );
}
const REGISTRY_PATH = pickExisting(REGISTRY_CANDIDATES);
const CHAPTERS_DIR = pickExisting(CHAPTERS_DIR_CANDIDATES);

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
  const order = await readChapterOrder();

  const segments: Segment[] = [];
  let silentSteps = 0;
  for (const { id, folder } of order) {
    const arr = await loadNarrations(folder);
    arr.forEach((entry, i) => {
      const step = i + 1;
      // 双模式 narrations 元素是 { text, durationInFrames, hint? } 或 string
      const text = typeof entry === "string" ? entry : (entry as { text: string }).text;
      if (text == null) {
        throw new Error(
          `chapter "${id}" step ${step}: missing text field. ` +
            `Expected string or { text, durationInFrames, hint? }`,
        );
      }
      if (text.trim() === "") {
        silentSteps++;
        return;
      }
      segments.push({
        chapter: id,
        step,
        text,
        audio: `${id}/${step}.mp3`,
      });
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
