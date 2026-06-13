/**
 * probe-audio-durations.ts
 *
 * 扫 `shared/chapters/*/narrations.ts`，对每个 Step 找对应 mp3（公共素材目录
 * `shared/assets/audio/<chapter-id>/<step+1>.mp3` 或退到 `vite/public/audio/`），
 * 用 ffprobe 拿时长，按 @30fps 换算成帧数，回写到 `narrations.ts` 的
 * `durationInFrames` 字段。
 *
 * 用法：
 *   npm run probe                 # 回写所有 chapter
 *   npm run probe -- --dry-run    # 只打印，不写
 *
 * 幂等：再跑一次结果一致（值不变）。
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join, resolve, dirname } from "node:path";

const ROOT = resolve(__dirname, "..");
const SHARED_CHAPTERS = join(ROOT, "shared/chapters");
const SHARED_AUDIO = join(ROOT, "shared/assets/audio");
const VITE_PUBLIC_AUDIO = join(ROOT, "vite/public/audio");

const FPS = 30;
const MIN_FRAMES = 30; // 1s 兜底

const dryRun = process.argv.includes("--dry-run");

function findMp3(chapterId: string, step1Indexed: number): string | null {
  const filename = `${step1Indexed}.mp3`;
  const candidates = [join(SHARED_AUDIO, chapterId, filename), join(VITE_PUBLIC_AUDIO, chapterId, filename)];
  for (const c of candidates) if (existsSync(c)) return c;
  return null;
}

function ffprobeSeconds(p: string): number {
  const out = execFileSync(
    "ffprobe",
    ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", p],
    { encoding: "utf8" },
  ).trim();
  const s = Number(out);
  if (!Number.isFinite(s) || s <= 0) {
    throw new Error(`ffprobe returned invalid duration for ${p}: ${out}`);
  }
  return s;
}

/**
 * 把 narrations.ts 里所有 `durationInFrames: <n>` 按 step 顺序替换。
 * 匹配单行内的字段，不破坏注释/格式。
 */
function injectFrames(src: string, frames: number[]): string {
  let idx = 0;
  return src.replace(
    /durationInFrames:\s*\d+/g,
    (m) => {
      const v = frames[idx] ?? 0;
      idx++;
      return `durationInFrames: ${v}`;
    },
  );
}

function processChapter(folderPath: string): { updated: number; total: number } {
  const narFile = join(folderPath, "narrations.ts");
  if (!existsSync(narFile)) return { updated: 0, total: 0 };

  const folder = folderPath.split("/").pop()!;
  // chapter id 去掉 NN- 前缀
  const chapterId = folder.replace(/^\d+-/, "");

  const src = readFileSync(narFile, "utf8");
  const matches = [...src.matchAll(/durationInFrames:\s*(\d+)/g)];
  const total = matches.length;
  if (total === 0) return { updated: 0, total: 0 };

  const frames: number[] = [];
  let updated = 0;
  for (let i = 0; i < total; i++) {
    const step1Indexed = i + 1;
    const mp3 = findMp3(chapterId, step1Indexed);
    if (!mp3) {
      console.warn(`  ⚠ ${folder} step ${step1Indexed}: mp3 not found, keep ${matches[i]![1]}`);
      frames.push(Number(matches[i]![1]));
      continue;
    }
    const seconds = ffprobeSeconds(mp3);
    const f = Math.max(MIN_FRAMES, Math.ceil(seconds * FPS));
    frames.push(f);
    updated++;
    console.log(`  ✓ ${folder} step ${step1Indexed}: ${seconds.toFixed(2)}s → ${f} frames`);
  }

  if (!dryRun) {
    const out = injectFrames(src, frames);
    if (out !== src) {
      writeFileSync(narFile, out, "utf8");
    }
  }
  return { updated, total };
}

function main() {
  if (!existsSync(SHARED_CHAPTERS)) {
    console.error(`✗ 找不到 ${SHARED_CHAPTERS}`);
    process.exit(1);
  }
  try {
    execFileSync("ffprobe", ["-version"], { stdio: "ignore" });
  } catch {
    console.error("✗ ffprobe 不在 PATH 里。装 ffmpeg：brew install ffmpeg");
    process.exit(1);
  }

  console.log(`▸ 扫 ${SHARED_CHAPTERS}`);
  if (dryRun) console.log("  (dry-run 模式：不写文件)");

  let totalUpdated = 0;
  let totalSteps = 0;
  for (const entry of readdirSync(SHARED_CHAPTERS)) {
    const p = join(SHARED_CHAPTERS, entry);
    if (!statSync(p).isDirectory()) continue;
    const r = processChapter(p);
    totalUpdated += r.updated;
    totalSteps += r.total;
  }

  console.log(`\n✓ 完成：${totalUpdated}/${totalSteps} step 注入了 durationInFrames`);
  if (totalUpdated < totalSteps) {
    console.log(`  ⚠ 还有 ${totalSteps - totalUpdated} 个 step 缺 mp3 —— 补音频后再跑`);
  }
}

main();
