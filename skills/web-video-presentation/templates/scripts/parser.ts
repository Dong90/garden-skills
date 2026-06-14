/**
 * parser.ts — tsx 源码解析工具
 *
 * 抽自 check-alignment.ts，让 check-alignment.ts 变薄。
 * 包含 3 个工具：
 *   - sliceBalanced：配平大括号切 body
 *   - extractStepBranches：找 `if (step === N) { ... }` 分支
 *   - extractImgRefs：找 `<img src=".../N.png">` 引用
 *
 * 还有 2 个 line 工具（lineOf / findImageLine / escapeRe）
 */

import { findImageLine as _findImageLine, lineOf as _lineOf, escapeRe as _escapeRe } from "./parser-utils";

/** 配平大括号切 body（跳字符串 / 模板字符串 / 注释） */
export function sliceBalanced(src: string, openIdx: number): string {
  return _sliceBalancedImpl(src, openIdx);
}

function _sliceBalancedImpl(src: string, openIdx: number): string {
  if (src[openIdx] !== "{") throw new Error(`sliceBalanced: expected '{' at ${openIdx}`);
  let depth = 0;
  let i = openIdx;
  let inSingle = false;
  let inDouble = false;
  let inTemplate = false;
  let inLineComment = false;
  let inBlockComment = false;
  while (i < src.length) {
    const ch = src[i]!;
    const next = src[i + 1];
    if (inLineComment) {
      if (ch === "\n") inLineComment = false;
      i++;
      continue;
    }
    if (inBlockComment) {
      if (ch === "*" && next === "/") { inBlockComment = false; i += 2; continue; }
      i++;
      continue;
    }
    if (inSingle) {
      if (ch === "\\") { i += 2; continue; }
      if (ch === "'") inSingle = false;
      i++;
      continue;
    }
    if (inDouble) {
      if (ch === "\\") { i += 2; continue; }
      if (ch === '"') inDouble = false;
      i++;
      continue;
    }
    if (inTemplate) {
      if (ch === "\\") { i += 2; continue; }
      if (ch === "$" && next === "{") {
        i += 2;
        let braceDepth = 1;
        while (i < src.length && braceDepth > 0) {
          const c2 = src[i]!;
          if (c2 === "{") braceDepth++;
          else if (c2 === "}") braceDepth--;
          i++;
        }
        continue;
      }
      if (ch === "`") inTemplate = false;
      i++;
      continue;
    }
    if (ch === "/" && next === "/") { inLineComment = true; i += 2; continue; }
    if (ch === "/" && next === "*") { inBlockComment = true; i += 2; continue; }
    if (ch === "'") { inSingle = true; i++; continue; }
    if (ch === '"') { inDouble = true; i++; continue; }
    if (ch === "`") { inTemplate = true; i++; continue; }
    if (ch === "{") { depth++; i++; continue; }
    if (ch === "}") {
      depth--;
      if (depth === 0) return src.slice(openIdx, i + 1);
      i++;
      continue;
    }
    i++;
  }
  throw new Error(`sliceBalanced: 未闭合 '{' at ${openIdx}`);
}

export interface StepBranch {
  body: string;
  line: number;
}

/** 找 tsx 源里所有 `if (step === N) {...}` 或 `if (step === N) return <...>;` 分支 */
export function extractStepBranches(tsxSrc: string): Map<number, StepBranch> {
  const out = new Map<number, StepBranch>();
  const re = /if\s*\(\s*step\s*===\s*(\d+)\s*\)(?:\s*\{|\s+)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(tsxSrc)) !== null) {
    const n = Number(m[1]!);
    if (n > 10_000) continue;
    const after = tsxSrc.slice(m.index + m[0].length);
    let body: string;
    if (after.startsWith("{")) {
      const openIdx = m.index + m[0].length - 1;
      body = _sliceBalancedImpl(tsxSrc, openIdx);
    } else {
      const ltIdx = tsxSrc.indexOf("<", m.index + m[0].length);
      body = ltIdx >= 0 ? tsxSrc.slice(ltIdx, tsxSrc.indexOf(";", ltIdx) + 1) : "";
    }
    out.set(n, { body, line: _lineOf(tsxSrc, m.index) });
  }
  return out;
}

export interface ImgRef {
  step: number;
  line: number;
}

/** 找 `<img src=".../N.png">` 引用，N 1-based */
export function extractImgRefs(tsxSrc: string): ImgRef[] {
  const out: ImgRef[] = [];
  const re = /<img\b[^>]+src\s*=\s*["'][^"']*\/(\d+)\.png["']/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(tsxSrc)) !== null) {
    out.push({ step: Number(m[1]!), line: _lineOf(tsxSrc, m.index) });
  }
  return out;
}

// Re-export
export const lineOf = _lineOf;
export const findImageLine = _findImageLine;
export const escapeRe = _escapeRe;
