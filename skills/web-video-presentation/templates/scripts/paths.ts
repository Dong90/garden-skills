/**
 * paths.ts — 项目根路径 / registry / chapter 解析的统一入口。
 *
 * 解决 3 个脚本（check-alignment / extract-narrations / split-narrations）
 * 各自用 process.cwd() 算 ROOT 的漂移问题。
 *
 * 用法：
 *   import { resolveProjectPaths, ROOT } from "./paths";
 *   const paths = resolveProjectPaths();
 *   const registry = paths.registryPath;
 */
import { existsSync } from "node:fs";
import { resolve } from "node:path";

/** 项目根 = process.cwd()（npm scripts 跑在项目根） */
export const ROOT = process.cwd();

const REGISTRY_CANDIDATES = [
  resolve(ROOT, "vite/src/registry/chapters.ts"),
  resolve(ROOT, "src/registry/chapters.ts"),
];

const CHAPTERS_DIR_CANDIDATES = [
  resolve(ROOT, "shared/chapters"),
  resolve(ROOT, "src/chapters"),
];

function pickExisting(candidates: string[]): string {
  for (const c of candidates) if (existsSync(c)) return c;
  throw new Error(`找不到候选路径：\n  ${candidates.join("\n  ")}`);
}

export interface ProjectPaths {
  root: string;
  registryPath: string;
  chaptersDir: string;
  audioSegmentsPath: string;
  alignmentReportPath: string;
}

export function resolveProjectPaths(): ProjectPaths {
  return {
    root: ROOT,
    registryPath: pickExisting(REGISTRY_CANDIDATES),
    chaptersDir: pickExisting(CHAPTERS_DIR_CANDIDATES),
    audioSegmentsPath: resolve(ROOT, "audio-segments.json"),
    alignmentReportPath: resolve(ROOT, "alignment-report.json"),
  };
}
