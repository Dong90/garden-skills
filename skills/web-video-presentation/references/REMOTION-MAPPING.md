# Remotion 出片模式 —— 共享层 .tsx 写法约束

> 适用：web-video-presentation skill v1.3+ 双模式项目
> 目的：保证同一个 `shared/chapters/<id>/<Chapter>.tsx` 既能跑 Vite 互动模式，又能跑 Remotion 出片模式。

---

## 1. 为什么需要这层约束

双模式项目的核心是**章节代码只写一次**：
- Vite 模式：浏览器按 step 推进，组件用 `step` prop 决定渲染哪个 scene
- Remotion 模式：headless Chrome 跑固定帧数，组件用 `frame` / `totalFrames` 推进入场动画

要让一份代码通吃，**共享层 .tsx 必须满足 4 条硬规则**。

---

## 2. 硬规则（违反任意一条 = Remotion 渲染失败）

### 2.1 不允许 useState / useEffect / setTimeout

Remotion 的渲染是**确定性帧推进**——同一帧号必须产出同一像素。`useState` 异步、`useEffect` 副作用时序、setTimeout 漂移——全都不行。

**反例**（会随机闪屏）：
```tsx
// ❌ 错：mount 时用 setTimeout 推进度
function MyScene() {
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    const t = setTimeout(() => setProgress(1), 900);
    return () => clearTimeout(t);
  }, []);
  return <MaskReveal progress={progress}>...</MaskReveal>;
}
```

**正例**：接受 progress prop。
```tsx
// ✓ 对：完全受控
function MyScene({ revealProgress = 0 }: ChapterSharedProps) {
  return <MaskReveal progress={revealProgress}>...</MaskReveal>;
}
```

### 2.2 不允许 import vite/ 或 remotion/ 路径下的东西

共享层只能：
- `import` React 生态（react / react-dom）
- `import` shared 自己的组件（`./FadeIn`、`./MaskReveal`）
- `import` 主题 CSS（`./Example.css`）

**反例**：
```tsx
// ❌ 错：引入 Vite 专属 hook
import { useAudioPlayer } from "../../vite/src/hooks/useAudioPlayer";
```

### 2.3 入场动画统一用 progress prop

`@shared/components/MaskReveal` 和 `@shared/components/FadeIn` 是**受控版**——只读 progress，自己不计时。

**对照**：
| 需求 | Vite 模式传 | Remotion 模式传 |
|---|---|---|
| mount 后立即显示 | `revealProgress={1}` | `revealProgress={1}` |
| 前 30 帧入场 | 需 rAF 推进（Vite 端 App 算） | `revealProgress={frame/30}` |
| 错峰多元素 | 多个 `revealProgress - delay` | 同上 |

**Vite 端 App.tsx 推荐做法**（mount 1s 内推完进度）：
```tsx
import { useEffect, useState } from "react";

function useMountProgress(durationMs = 900): number {
  const [p, setP] = useState(0);
  useEffect(() => {
    const start = performance.now();
    let raf = 0;
    const tick = (t: number) => {
      const elapsed = t - start;
      setP(Math.min(1, elapsed / durationMs));
      if (elapsed < durationMs) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [durationMs]);
  return p;
}

// App 渲染时：
<Cmp step={step} revealProgress={useMountProgress()} />
```

### 2.4 音频通过 props 注入，不在章节里 new Audio()

**反例**（章节里管音频 → Remotion 渲染没声音）：
```tsx
function MyScene() {
  useEffect(() => {
    new Audio("/audio/1.mp3").play();
  }, []);
  return ...;
}
```

**正例**：Vite 端 `App.tsx` 调 `useAudioPlayer({ src: ... })` 播；Remotion 端 `<Audio src={staticFile(...)} />`。**章节不碰音频**。

---

## 3. 常用动画模式对照表

| 模式 | Vite 写法 | Remotion 写法 |
|---|---|---|
| **错峰字符揭示** | `<MaskReveal progress={mountProgress - i*0.1}>` | `<MaskReveal progress={frame/30 - i*0.1}>` |
| **数字跳表** | 用 state + setInterval（❌） | `interpolate(frame, [0, 60], [0, 100])` |
| **弹簧入场** | CSS `transition: transform 0.6s cubic-bezier` | `spring({ frame, fps, config: { damping: 12 } })` |
| **循环微动** | CSS animation（✅） | `interpolate(frame % 60, [0, 30, 60], [0, 1, 0])` |
| **章节切换 fade** | 父组件 key 变化（✅） | `<Sequence>` 边界自带 |

> 完整 Remotion API 见 https://www.remotion.dev/docs/

---

## 4. 数据流总览

```
┌─────────────── 真相源 ───────────────┐
│  shared/chapters/<id>/narrations.ts  │
│  export const narrations: Step[] = [ │
│    { text, durationInFrames, hint? } │
│  ]                                   │
└──────────────┬───────────────────────┘
               │ import
       ┌───────┴────────┐
       ▼                ▼
   Vite 端          Remotion 端
   useStepper       getTotalFrames
   { cursor }       { frame }
       │                │
       ▼                ▼
   <Cmp step revealProgress />    <Cmp step frame totalFrames revealProgress />
                                                  ▲
                                                  │ useCurrentFrame() 在 StepSegment 内部
```

---

## 5. 验收 checklist

写完一章，跑一遍这 5 条：

- [ ] `grep -E "useState|useEffect|setTimeout" <Chapter>.tsx` → 0 命中
- [ ] `grep -E "import .*vite/" <Chapter>.tsx` → 0 命中
- [ ] `grep -E "import .*remotion/" <Chapter>.tsx` → 0 命中
- [ ] Vite 端 `npm run dev` → 浏览器打开，三步画面都显示
- [ ] Remotion 端 `npm run probe && npm run render:ep01` → out/ep01.mp4 能播，节奏对

任一不通过 = 这一章没真正"共享化"，回头改。
