import type { CSSProperties, ReactNode } from "react";
import { easeOutCubic } from "./MaskReveal";

/**
 * BlurReveal — transitions from blur to clear.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 *
 * progress=0 → max blur + slight scale up; progress=1 → clear + scale 1.
 */
export interface BlurRevealProps {
  progress: number;
  /** Max blur in px (default 12) */
  maxBlur?: number;
  /** Start scale (default 1.04) */
  startScale?: number;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}

export function BlurReveal({
  progress,
  maxBlur = 12,
  startScale = 1.04,
  children,
  className,
  style,
}: BlurRevealProps) {
  const t = Math.max(0, Math.min(1, progress));
  const eased = easeOutCubic(t);
  const blur = maxBlur * (1 - eased);
  const scale = startScale + (1 - startScale) * eased;
  const opacity = eased;

  return (
    <div
      className={className}
      style={{
        display: "inline-block",
        filter: `blur(${blur}px)`,
        WebkitFilter: `blur(${blur}px)`,
        transform: `scale(${scale})`,
        opacity,
        willChange: "filter, transform, opacity",
        ...style,
      }}
    >
      {children}
    </div>
  );
}
