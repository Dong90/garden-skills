/**
 * parser-utils.ts —— line/loc 工具（被 parser.ts 用）
 *
 * 单独拆开避免 parser.ts 单文件含通用 + 业务混杂
 */

export function lineOf(src: string, offset: number): number {
  let line = 1;
  for (let i = 0; i < offset && i < src.length; i++) {
    if (src.charCodeAt(i) === 10) line++;
  }
  return line;
}

export function findImageLine(imagesSrc: string, step: number): number {
  const lines = imagesSrc.split("\n");
  const re = new RegExp(`\\bstep\\s*:\\s*${step}\\b`);
  for (let i = 0; i < lines.length; i++) {
    if (re.test(lines[i]!)) return i + 1;
  }
  return -1;
}

export function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
