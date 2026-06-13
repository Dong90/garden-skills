import type { CSSProperties, ReactNode } from "react";

/**
 * 受控版 MaskReveal —— 同时被 Vite 互动模式 + Remotion 出片模式消费。
 *
 * 调用方负责算 progress（Vite 端：mount 后用 rAF 推进；Remotion 端：
 * 用 useCurrentFrame() / totalFrames），组件不读 useState / useEffect。
 *
 * 进度定义：
 *   progress = 0  → 完全隐藏（mask 100% 覆盖）
 *   progress = 1  → 完全显示（mask 0% 覆盖）
 */
export interface MaskRevealProps {
  /** 0 = 完全隐藏，1 = 完全显示，0~1 之间任意插值 */
  progress: number;
  /** 揭示方向。默认 "up"（从下往上） */
  direction?: "up" | "down" | "left" | "right";
  /** 自定义 easing（可选，默认 easeOutCubic） */
  easing?: (t: number) => number;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}

export const easeOutCubic = (t: number): number => 1 - Math.pow(1 - t, 3);
export const easeInOutCubic = (t: number): number =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
export const easeOutQuart = (t: number): number => 1 - Math.pow(1 - t, 4);

function clipFor(progress: number, direction: "up" | "down" | "left" | "right"): string {
  const t = Math.max(0, Math.min(1, progress));
  const visible = 100 - t * 100;
  switch (direction) {
    case "up":
      return `inset(${visible}% 0 0 0)`;
    case "down":
      return `inset(0 0 ${visible}% 0)`;
    case "left":
      return `inset(0 ${visible}% 0 0)`;
    case "right":
      return `inset(0 0 0 ${visible}%)`;
  }
}

export function MaskReveal({
  progress,
  direction = "up",
  easing = easeOutCubic,
  children,
  className,
  style,
}: MaskRevealProps) {
  const eased = easing(progress);
  const clip = clipFor(eased, direction);
  return (
    <span
      className={className}
      style={{
        display: "inline-block",
        clipPath: clip,
        WebkitClipPath: clip,
        willChange: "clip-path",
        ...style,
      }}
    >
      {children}
    </span>
  );
}
