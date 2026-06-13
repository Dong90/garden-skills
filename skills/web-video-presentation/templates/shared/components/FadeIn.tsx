/**
 * 受控的"内容驱动动画"基元 —— 接受 progress: 0~1 推进入场。
 * 双渲染器（Vite / Remotion）通用。
 */
import type { CSSProperties, ReactNode } from "react";
import { easeOutCubic } from "./MaskReveal";

export interface FadeInProps {
  progress: number;
  /** 起始透明度（默认 0） */
  from?: number;
  /** 起始 Y 偏移（默认 8） */
  fromY?: number;
  duration?: number;
  easing?: (t: number) => number;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}

export function FadeIn({
  progress,
  from = 0,
  fromY = 8,
  duration = 1,
  easing = easeOutCubic,
  children,
  className,
  style,
}: FadeInProps) {
  const t = Math.max(0, Math.min(progress / duration, 1));
  const eased = easing(t);
  return (
    <span
      className={className}
      style={{
        display: "inline-block",
        opacity: from + (1 - from) * eased,
        transform: `translateY(${(1 - eased) * fromY}px)`,
        willChange: "opacity, transform",
        ...style,
      }}
    >
      {children}
    </span>
  );
}
