/**
 * check-alignment.ts —— 跨管道对齐校验（I1~I4 + HINT）
 *
 * 用法：
 *   npx tsx check-alignment.ts                 # 默认 WARN=warn
 *   npx tsx check-alignment.ts --strict        # WARN 升级为 ERROR
 *   npx tsx check-alignment.ts --dry-run       # 报错但不 exit 1
 *
 * 不变式：
 *   I1  narrations.length == tsx 中 if (step === N) 最大 N + 1，
 *       且 step 0..narLen-1 连续无缺（ERROR）
 *   I2  images.ts 每项 step ∈ [1..narLen] 且不重复；subject 必填（ERROR）
 *   I3  tsx 中 <img src=".../<N>.png"> 引用的 N ⊆ images.ts 的 step 集合
 *       tsx 有引但 images.ts 不存在也报错（ERROR）
 *   I4  audio-segments.json 的 (chapter, step) 数 == narrations 非空 text 数（ERROR）
 *   HINT  narrations[i].hint 缺失          （WARN / --strict 时 ERROR）
 *
 * 模块拆分（v1.4）：
 *   - paths.ts      项目根 / registry / chapter 解析
 *   - parser.ts     tsx 解析（extractStepBranches / extractImgRefs / sliceBalanced）
 *   - parser-utils.ts  line 工具
 *   - reporter.ts   Issue 类型 + 输出 JSON/stderr（this file 仍含 main）
 */
import { readFile, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join, relative } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { resolveProjectPaths, ROOT } from "./paths";
import { extractStepBranches, extractImgRefs } from "./parser";

// ── types ──────────────────────────────────────────────────────
type Severity = "ERROR" | "WARN";

export interface Issue {
  chapter: string;
  code: "I1" | "I2" | "I3" | "I4" | "HINT";
  msg: string;
  fix: string;
  file?: string;
  line?: number;
  severity: Severity;
}

// ── data loaders ───────────────────────────────────────────────
interface ChapterRef {
  id: string;
  folder: string;
  dir: string;
  className: string;
}

async function readChapterOrder(): Promise<ChapterRef[]> {
  const { registryPath, chaptersDir } = resolveProjectPaths();
  const src = await readFile(registryPath, "utf8");

  const ids: string[] = [];
  for (const m of src.matchAll(/id:\s*["']([^"']+)["']/g)) ids.push(m[1]!);

  const folders: string[] = [];
  const explicitFolders = [...src.matchAll(/folder:\s*["']([^"']+)["']/g)].map((m) => m[1]!);
  if (explicitFolders.length === ids.length && explicitFolders.length > 0) {
    folders.push(...explicitFolders);
  } else {
    for (const m of src.matchAll(
      /from\s+["'](?:@shared|(?:\.\.\/)+\s*(?:shared\/)?chapters)\/([^"'\/]+)\/[^"']+["']/g,
    )) {
      const folder = m[1]!;
      if (!folders.includes(folder)) folders.push(folder);
    }
  }
  if (ids.length !== folders.length) {
    throw new Error(`registry mismatch: ${ids.length} ids vs ${folders.length} folders`);
  }
  if (ids.length === 0) return [];

  const refs: ChapterRef[] = [];
  for (let i = 0; i < ids.length; i++) {
    const id = ids[i]!;
    const folder = folders[i]!;
    const dir = join(chaptersDir, folder);
    if (!existsSync(dir)) throw new Error(`chapter dir missing: ${dir}`);
    // 找 tsx 文件名：优先 import basename，兜底 folder→PascalCase
    const importRe = new RegExp(
      `from\\s+["'][^"']*${escapeReForFile(folder)}/([^"'.]+)["']`,
      "g",
    );
    const candidates: string[] = [];
    for (const m of src.matchAll(importRe)) {
      const name = m[1]!;
      if (existsSync(join(dir, `${name}.tsx`))) candidates.push(`${name}.tsx`);
    }
    const pascalFromFolder = folder
      .replace(/^\d+-/, "")
      .split(/[-_]/)
      .map((p) => p[0]!.toUpperCase() + p.slice(1))
      .join("");
    candidates.push(`${pascalFromFolder}.tsx`, "index.tsx", "Chapter.tsx");
    const tsxName = candidates.find((c) => existsSync(join(dir, c)));
    if (!tsxName) throw new Error(`找不到 chapter tsx in ${folder}`);
    refs.push({ id, folder, dir, className: tsxName.replace(/\.tsx$/, "") });
  }
  return refs;
}

function escapeReForFile(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

interface Narration { text: string; durationInFrames: number; hint?: string; }
interface ImageSpec {
  step?: number; subject: string; composition?: string; style?: string;
  palette?: string; negative?: string; size?: string; aspect?: string;
  seed?: number; imageReference?: string; referenceStrength?: number; out?: string;
}

async function loadNarrations(dir: string): Promise<Narration[]> {
  const file = join(dir, "narrations.ts");
  if (!existsSync(file)) throw new Error(`missing narrations.ts: ${file}`);
  const mod = await import(pathToFileURL(file).href);
  if (!Array.isArray(mod.narrations)) {
    throw new Error(`${file} must export \`narrations: Step[]\``);
  }
  return mod.narrations as Narration[];
}

async function loadImages(dir: string): Promise<ImageSpec[]> {
  const file = join(dir, "images.ts");
  if (!existsSync(file)) return [];
  const mod = await import(pathToFileURL(file).href);
  if (!Array.isArray(mod.images)) throw new Error(`${file} must export \`images: ImageSpec[]\``);
  return mod.images as ImageSpec[];
}

async function loadTsx(dir: string, className: string) {
  const candidates = [join(dir, `${className}.tsx`), join(dir, "index.tsx")];
  const file = candidates.find((p) => existsSync(p));
  if (!file) throw new Error(`${className}: 找不到主 tsx`);
  return { src: await readFile(file, "utf8"), file };
}

interface AudioSegment { chapter: string; step: number; text: string; audio: string; }

async function loadAudioSegments(): Promise<AudioSegment[]> {
  const { audioSegmentsPath } = resolveProjectPaths();
  if (!existsSync(audioSegmentsPath)) return [];
  const raw = await readFile(audioSegmentsPath, "utf8");
  try {
    const data = JSON.parse(raw);
    if (!Array.isArray(data)) return [];
    return data as AudioSegment[];
  } catch (e) {
    throw new Error(`audio-segments.json 不是合法 JSON：${(e as Error).message}`);
  }
}

interface ChapterContext {
  ref: ChapterRef;
  narrations: Narration[];
  images: ImageSpec[];
  tsxSrc: string;
  tsxFile: string;
  imagesFile: string;
  imagesSrc: string;
}

async function buildContext(ref: ChapterRef): Promise<ChapterContext> {
  const narrations = await loadNarrations(ref.dir);
  const images = await loadImages(ref.dir);
  const { src: tsxSrc, file: tsxFile } = await loadTsx(ref.dir, ref.className);
  const imagesFile = join(ref.dir, "images.ts");
  const imagesSrc = existsSync(imagesFile) ? await readFile(imagesFile, "utf8") : "";
  return { ref, narrations, images, tsxSrc, tsxFile, imagesFile, imagesSrc };
}

// ── validator ──────────────────────────────────────────────────
function validateChapter(ctx: ChapterContext, audio: AudioSegment[]): Issue[] {
  const issues: Issue[] = [];
  const { ref, narrations: nars, images, tsxSrc, tsxFile, imagesFile, imagesSrc } = ctx;
  const narLen = nars.length;
  const rel = (p: string) => relative(ROOT, p);
  const push = (code: Issue["code"], msg: string, fix: string, file?: string, line?: number) =>
    issues.push({ chapter: ref.id, code, msg, fix, file: file ? rel(file) : undefined, line, severity: "ERROR" });
  const warn = (code: Issue["code"], msg: string, fix: string, file?: string, line?: number) =>
    issues.push({ chapter: ref.id, code, msg, fix, file: file ? rel(file) : undefined, line, severity: "WARN" });

  // I1: tsx branches 连续 0..narLen-1
  const branches = extractStepBranches(tsxSrc);
  if (narLen === 0) {
    push("I1", `narrations 数组为空，但章节至少要 1 步（封面或首屏）`,
      `→ 在 ${ref.folder}/narrations.ts 加至少 1 个 Step`,
      join(ref.dir, "narrations.ts"), 1);
  } else {
    nars.forEach((n, i) => {
      if (typeof n.durationInFrames !== "number" || Number.isNaN(n.durationInFrames)) {
        push("I1", `narrations[${i}] 缺 durationInFrames 或不是数字`,
          `→ 加 \`durationInFrames: 0\`（让 probe 注入真实值）或直接填数字`,
          join(ref.dir, "narrations.ts"));
      }
    });
    const maxStep = Math.max(...branches.keys(), -1);
    if (maxStep !== narLen - 1) {
      const maxBranchLine = maxStep >= 0 ? branches.get(maxStep)?.line : undefined;
      push("I1", `tsx 分支数 (最大 step === ${maxStep}) + 1 = ${maxStep + 1} ≠ narrations.length (${narLen})`,
        maxStep > narLen - 1
          ? `→ 删 ${ref.className}.tsx 中多余的 step === ${maxStep} 分支，或在 ${ref.folder}/narrations.ts 加到 ${maxStep + 1} 步`
          : `→ 在 ${ref.className}.tsx 补 step === ${narLen - 1} 分支，或删 narrations.ts 里多余的 step`,
        tsxFile, maxBranchLine);
    }
    for (let s = 0; s < narLen; s++) {
      if (!branches.has(s)) {
        push("I1", `缺少 step === ${s} 分支（narrations[${s}] 存在但 tsx 没处理）`,
          `→ 在 ${ref.className}.tsx 加 \`if (step === ${s}) { ... }\` 分支`, tsxFile);
      }
    }
  }

  // I2: images.ts 字段校验
  const imagesFileExists = imagesSrc.length > 0;
  if (imagesFileExists) {
    const seen = new Map<number, number>();
    images.forEach((img, i) => {
      const step = img.step ?? (i + 1);
      const lineInImages = imagesSrc ? findImageLineLocal(imagesSrc, step) : -1;
      const lineRef = lineInImages > 0 ? lineInImages : i + 1;
      if (step < 1 || step > narLen) {
        push("I2", `images[${i}].step = ${step} 越界（narrations.length = ${narLen}，允许 1..${narLen}）`,
          step < 1
            ? `→ 把 step 改成 ≥ 1 的整数`
            : `→ 把 step 改成 ≤ ${narLen}，或在 narrations.ts 补到 ${step} 步`,
          imagesFile, lineRef);
      }
      if (typeof img.subject !== "string" || img.subject.trim() === "") {
        push("I2", `images[${i}]（step ${step}）缺少必填 subject`,
          `→ 在该 ImageSpec 里加 subject: "<画面主体>"`, imagesFile, lineRef);
      }
      if (seen.has(step)) {
        const prev = seen.get(step)!;
        push("I2", `images 中 step ${step} 重复（第 ${prev + 1} 项与第 ${i + 1} 项）`,
          `→ 合并这两项，或把其中一项的 step 改成 ${narLen + 1} 以上后单独处理`,
          imagesFile, lineRef);
      } else {
        seen.set(step, i);
      }
    });
  }

  // I3: tsx img refs ⊆ images.ts step 集合
  const refs = extractImgRefs(tsxSrc);
  if (!imagesFileExists) {
    for (const { step, line } of refs) {
      push("I3", `${ref.className}.tsx line ${line} 引用了 images/${step}.png，但 ${ref.folder}/images.ts 不存在`,
        `→ 在 ${ref.folder}/images.ts 加 step: ${step} 的 ImageSpec；或者删掉那行 <img src=".../${step}.png">`,
        tsxFile, line);
    }
  } else {
    const validSteps = new Set(images.map((img, i) => img.step ?? (i + 1)));
    for (const { step, line } of refs) {
      if (!validSteps.has(step)) {
        push("I3", `${ref.className}.tsx line ${line} 引用了 images/${step}.png，但 images.ts 里没对应 step`,
          `→ 在 ${ref.folder}/images.ts 加 step: ${step} 的 ImageSpec（subject 必填），或把 tsx 里的 N 改成 ${[...validSteps].sort((a, b) => a - b).join(" / ")}`,
          tsxFile, line);
      }
    }
  }

  // I4: audio-segments vs narrations
  const nonEmptyCount = nars.filter((n) => (n.text ?? "").trim() !== "").length;
  const chapterAudio = audio.filter((s) => s.chapter === ref.id);
  if (audio.length > 0) {
    if (chapterAudio.length !== nonEmptyCount) {
      push("I4", `audio-segments.json 里有 ${chapterAudio.length} 条该 chapter 的段落，narrations 非空 text 有 ${nonEmptyCount} 条`,
        chapterAudio.length < nonEmptyCount
          ? `→ 重跑 \`npm run extract-narrations\` 同步；新增的 step 会变成 <chapter>/${nonEmptyCount}.mp3`
          : `→ 检查 narrations.ts 里是否多了空 text 仍被写出，或 audio-segments.json 是旧版本`,
        join(ref.dir, "narrations.ts"), 1);
    } else {
      const audioSteps = new Set(chapterAudio.map((s) => s.step));
      for (let s = 1; s <= narLen; s++) {
        const text = nars[s - 1]?.text ?? "";
        if (text.trim() !== "" && !audioSteps.has(s)) {
          push("I4", `narrations[${s - 1}]（step ${s}）非空，但 audio-segments.json 缺该 step`,
            `→ 重跑 \`npm run extract-narrations\` 让它把 step ${s} 写入 JSON`,
            join(ref.dir, "narrations.ts"));
        }
      }
      for (const s of audioSteps) {
        if (s < 1 || s > narLen || (nars[s - 1]?.text ?? "").trim() === "") {
          push("I4", `audio-segments.json 里有 step ${s}，但 narrations[${s - 1}] 不存在或为空`,
            `→ 在 narrations.ts 给 step ${s} 补非空 text，或重跑 extract-narrations 清掉旧条目`,
            join(ref.dir, "narrations.ts"));
        }
      }
    }
  }

  // HINT
  nars.forEach((n, i) => {
    if (n.hint == null || (typeof n.hint === "string" && n.hint.trim() === "")) {
      warn("HINT", `narrations[${i}] 缺 hint（脚本翻译 / 视觉提示用）`,
        `→ 加 \`hint: "<一句话描述视觉/语义>"\`，例如 hint: "cover" / "list" / "close"`,
        join(ref.dir, "narrations.ts"), i + 1);
    }
  });

  return issues;
}

// 本地包装（避免循环引用 parser.ts）
import { findImageLine as findImageLineLocal } from "./parser";

// ── reporter ───────────────────────────────────────────────────
function reportAndExit(issues: Issue[], refs: ChapterRef[], audio: AudioSegment[], strict: boolean, dryRun: boolean) {
  const { alignmentReportPath } = resolveProjectPaths();

  const effective = strict
    ? issues.map((i) => (i.severity === "WARN" ? { ...i, severity: "ERROR" as Severity } : i))
    : issues;
  const errors = effective.filter((i) => i.severity === "ERROR");
  const warnings = effective.filter((i) => i.severity === "WARN");

  const report = {
    generatedAt: new Date().toISOString(),
    chapters: refs.length,
    errors: errors.map(({ severity: _s, ...rest }) => rest),
    warnings: warnings.map(({ severity: _s, ...rest }) => rest),
    summary: { errors: errors.length, warnings: warnings.length, strict, dryRun },
  };
  // fire-and-forget：sync write 避免 wait
  void writeFile(alignmentReportPath, JSON.stringify(report, null, 2) + "\n", "utf8");

  const total = errors.length + warnings.length;
  if (total === 0) {
    console.error(`✓ alignment OK (${refs.length} chapters, audio ${audio.length} segments)`);
    console.error(`  → ${relative(process.cwd(), alignmentReportPath)}`);
    return;
  }
  const tag = (s: Severity) => (s === "ERROR" ? "ERROR" : "WARN ");
  for (const i of [...errors, ...warnings]) {
    const loc = [i.file, i.line].filter(Boolean).join(":");
    console.error(`[${tag(i.severity)}] ${i.code} (${i.chapter}) ${loc} — ${i.msg}`);
    console.error(`         ${i.fix}`);
  }
  console.error(
    `\n✗ ${errors.length} error(s), ${warnings.length} warning(s)` +
      (strict ? " (--strict: WARNs counted as ERRORs)" : "") +
      (dryRun ? " (--dry-run: exit 0)" : ""),
  );
  console.error(`  → ${relative(process.cwd(), alignmentReportPath)}`);

  if (errors.length > 0 && !dryRun) process.exit(1);
}

// ── main ───────────────────────────────────────────────────────
async function main() {
  const args = new Set(process.argv.slice(2));
  const strict = args.has("--strict");
  const dryRun = args.has("--dry-run");

  const refs = await readChapterOrder();
  const audio = await loadAudioSegments();
  const allIssues: Issue[] = [];

  for (const ref of refs) {
    try {
      const ctx = await buildContext(ref);
      allIssues.push(...validateChapter(ctx, audio));
    } catch (e) {
      allIssues.push({
        chapter: ref.id,
        code: "I1",
        msg: `章节加载失败：${(e as Error).message}`,
        fix: `→ 检查 ${ref.folder}/ 目录结构与文件命名`,
        file: relative(ROOT, ref.dir),
        severity: "ERROR",
      });
    }
  }

  reportAndExit(allIssues, refs, audio, strict, dryRun);
}

main().catch((err) => {
  console.error(`✗ ${(err as Error).message ?? err}`);
  process.exit(1);
});
