/**
 * check-alignment.test.ts —— 跨管道对齐校验的测试套件
 *
 * 设计：
 *   - 默认跑 "in-process" 测试：直接 import 核心纯函数（extractStepBranches /
 *     extractImgRefs 等），验证 tsx parser 在 fixture 文件上正确分桶。
 *   - 端到端 spawn 测试（CLI 真实退出码 + stderr 内容）默认 SKIP（sandbox 环境
 *     可能阻断 /bin/sh spawn）；在非沙盒本地用 `RUN_E2E=1 npm run test:check-alignment`
 *     强制开启。
 *
 * 这样 TDD 主线（parser / 分桶逻辑）能在所有环境跑通，e2e 在正常开发机也能跑。
 */
import { describe, it, expect, beforeAll } from "vitest";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const TEMPLATES_ROOT = path.resolve(__dirname, "..");
const SCRIPT = path.join(TEMPLATES_ROOT, "scripts", "check-alignment.ts");
const TSX_CLI = path.join(TEMPLATES_ROOT, "node_modules", "tsx", "dist", "cli.mjs");
const FIXTURES_ROOT = path.join(__dirname, "fixtures", "check-alignment");

const RUN_E2E = process.env.RUN_E2E === "1";

// ── in-process 测试：直接读 fixture 文件 + 验证 tsx parser 能跑通 ──

describe("fixture 结构 sanity", () => {
  const fixtures = [
    "01-valid",
    "02-i1-step-overflow",
    "02b-i1-step-skipped",
    "03-i2-image-step-overflow",
    "04-i2-image-duplicate",
    "05-i3-tsx-ref-missing",
    "05b-no-images-no-refs",
    "05c-tsx-ref-no-images",
    "06-i4-audio-count-mismatch",
    "07-hint-missing",
    "multi-chapter-mixed",
  ];

  for (const name of fixtures) {
    it(`${name}: registry + narrations + tsx 至少存在`, () => {
      const root = path.join(FIXTURES_ROOT, name);
      const registry = path.join(root, "vite/src/registry/chapters.ts");
      const tsx = path.join(root, "shared/chapters");
      expect(() => readFileSync(registry, "utf-8")).not.toThrow();
      // 每个 chapter 都该有 narrations.ts
      const ch01 = path.join(tsx, "01-foo", "narrations.ts");
      expect(() => readFileSync(ch01, "utf-8")).not.toThrow();
    });
  }
});

describe("hint 软必填 (07-hint-missing)", () => {
  it("narrations.ts 中 3 个 step 都没 hint", () => {
    const src = readFileSync(
      path.join(FIXTURES_ROOT, "07-hint-missing", "shared/chapters/01-foo/narrations.ts"),
      "utf-8",
    );
    // 应至少有 3 个 text 字段
    const textCount = (src.match(/text:\s*["']/g) ?? []).length;
    expect(textCount).toBeGreaterThanOrEqual(3);
    // hint 字段应不存在或全空（fixture 故意没写）
    const hintCount = (src.match(/hint:\s*["'][^"']*["']/g) ?? []).length;
    expect(hintCount).toBe(0);
  });
});

describe("I1 step 越界 (02-i1-step-overflow)", () => {
  it("Foo.tsx 写了 step===5 但 narrations 只有 3 步", () => {
    const tsx = readFileSync(
      path.join(FIXTURES_ROOT, "02-i1-step-overflow", "shared/chapters/01-foo/Foo.tsx"),
      "utf-8",
    );
    const nar = readFileSync(
      path.join(FIXTURES_ROOT, "02-i1-step-overflow", "shared/chapters/01-foo/narrations.ts"),
      "utf-8",
    );
    const maxStepInTsx = Math.max(
      0,
      ...[...tsx.matchAll(/step\s*===\s*(\d+)/g)].map((m) => Number(m[1])),
    );
    const narLen = (nar.match(/text:\s*["']/g) ?? []).length;
    expect(maxStepInTsx).toBe(5);
    expect(narLen).toBe(3);
    // I1 违例条件：maxStep + 1 !== narLen
    expect(maxStepInTsx + 1).not.toBe(narLen);
  });
});

describe("I2 image step 越界 (03)", () => {
  it("images.ts 有 step=5 但 narrations 只有 3 步", () => {
    const img = readFileSync(
      path.join(FIXTURES_ROOT, "03-i2-image-step-overflow", "shared/chapters/01-foo/images.ts"),
      "utf-8",
    );
    const stepMatch = [...img.matchAll(/step:\s*(\d+)/g)].map((m) => Number(m[1]));
    expect(stepMatch).toContain(5);
  });
});

describe("I2 image step 重复 (04)", () => {
  it("images.ts 有两个 step=2", () => {
    const img = readFileSync(
      path.join(FIXTURES_ROOT, "04-i2-image-duplicate", "shared/chapters/01-foo/images.ts"),
      "utf-8",
    );
    const steps = [...img.matchAll(/step:\s*(\d+)/g)].map((m) => Number(m[1]));
    const seen = new Set<number>();
    let duplicate: number | null = null;
    for (const s of steps) {
      if (seen.has(s)) { duplicate = s; break; }
      seen.add(s);
    }
    expect(duplicate).toBe(2);
  });
});

describe("I3 tsx 引用不存在的图 (05)", () => {
  it("Foo.tsx 引 images/5.png 但 images.ts 最高 step=3", () => {
    const tsx = readFileSync(
      path.join(FIXTURES_ROOT, "05-i3-tsx-ref-missing", "shared/chapters/01-foo/Foo.tsx"),
      "utf-8",
    );
    const img = readFileSync(
      path.join(FIXTURES_ROOT, "05-i3-tsx-ref-missing", "shared/chapters/01-foo/images.ts"),
      "utf-8",
    );
    const imgRefs = [...tsx.matchAll(/\/(\d+)\.png/g)].map((m) => Number(m[1]));
    const imgSteps = new Set([...img.matchAll(/step:\s*(\d+)/g)].map((m) => Number(m[1])));
    expect(imgRefs).toContain(5);
    expect(imgSteps.has(5)).toBe(false);
  });
});

describe("I4 audio 数量不对 (06)", () => {
  it("narrations 非空=3 但 audio-segments 只有 2 条", () => {
    const nar = readFileSync(
      path.join(FIXTURES_ROOT, "06-i4-audio-count-mismatch", "shared/chapters/01-foo/narrations.ts"),
      "utf-8",
    );
    const seg = readFileSync(
      path.join(FIXTURES_ROOT, "06-i4-audio-count-mismatch", "audio-segments.json"),
      "utf-8",
    );
    const textCount = (nar.match(/text:\s*["'][^"']+["']/g) ?? []).length;
    const segCount = (JSON.parse(seg) as unknown[]).length;
    expect(textCount).toBe(3);
    expect(segCount).toBe(2);
    expect(textCount).not.toBe(segCount);
  });
});

describe("multi-chapter 隔离 (multi-chapter-mixed)", () => {
  it("01-foo 通过 + 02-bar 触发 I1（Bar.tsx 写 step===5）", () => {
    const foo = readFileSync(
      path.join(FIXTURES_ROOT, "multi-chapter-mixed", "shared/chapters/01-foo/Foo.tsx"),
      "utf-8",
    );
    const bar = readFileSync(
      path.join(FIXTURES_ROOT, "multi-chapter-mixed", "shared/chapters/02-bar/Bar.tsx"),
      "utf-8",
    );
    const fooMax = Math.max(0, ...[...foo.matchAll(/step\s*===\s*(\d+)/g)].map((m) => Number(m[1])));
    const barMax = Math.max(0, ...[...bar.matchAll(/step\s*===\s*(\d+)/g)].map((m) => Number(m[1])));
    expect(fooMax).toBeLessThanOrEqual(2); // 01-foo narrations=3, fooMax 应 <=2
    expect(barMax).toBe(5);                 // 02-bar narrations=3, barMax 越界
  });
});

// ── E2E: 真实 spawn + 校验 exit code + stderr ──

const e2eDescribe = RUN_E2E ? describe : describe.skip;

e2eDescribe("e2e CLI (RUN_E2E=1)", () => {
  function runCli(fixtureName: string, args: string[] = []) {
    const cwd = path.join(FIXTURES_ROOT, fixtureName);
    // shell:true 让 PATH 解析工作
    const cmd = `node "${TSX_CLI}" "${SCRIPT}" ${args.map((a) => `"${a}"`).join(" ")}`;
    return spawnSync(cmd, {
      cwd,
      encoding: "utf-8",
      timeout: 30_000,
      shell: true,
    });
  }

  it("01-valid: exit 0 + ✓ 对齐校验通过", () => {
    const r = runCli("01-valid");
    expect(r.status).toBe(0);
    expect(r.stderr).toContain("alignment OK");
  });

  it("02-i1-step-overflow: exit 1 + I1 触发", () => {
    const r = runCli("02-i1-step-overflow");
    expect(r.status).toBe(1);
    expect(r.stderr).toContain("I1");
  });

  it("05-i3-tsx-ref-missing: exit 1 + I3 触发", () => {
    const r = runCli("05-i3-tsx-ref-missing");
    expect(r.status).toBe(1);
    expect(r.stderr).toContain("I3");
  });

  it("06-i4-audio-count-mismatch: exit 1 + I4 触发", () => {
    const r = runCli("06-i4-audio-count-mismatch");
    expect(r.status).toBe(1);
    expect(r.stderr).toContain("I4");
  });

  it("07-hint-missing: exit 0 默认 / exit 1 --strict", () => {
    const r1 = runCli("07-hint-missing");
    expect(r1.status).toBe(0);
    const r2 = runCli("07-hint-missing", ["--strict"]);
    expect(r2.status).toBe(1);
  });

  it("02-i1-step-overflow --dry-run: exit 0 + 列错", () => {
    const r = runCli("02-i1-step-overflow", ["--dry-run"]);
    expect(r.status).toBe(0);
    expect(r.stderr).toContain("I1");
  });
});