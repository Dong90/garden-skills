import type { CSSProperties } from "react";

/**
 * Scanline — retro CRT scanline overlay.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 */
export interface ScanlineProps {
  progress: number;
  /** Scanline thickness in px (default 2) */
  lineHeight?: number;
  /** Spacing between lines (default 4) */
  gap?: number;
  className?: string;
  style?: CSSProperties;
}

export function Scanline({
  progress,
  lineHeight = 2,
  gap = 4,
  className,
  style,
}: ScanlineProps) {
  const t = Math.max(0, Math.min(1, progress));
  const total = lineHeight + gap;

  return (
    <div
      className={className}
      style={{
        position: "absolute",
        inset: 0,
        pointerEvents: "none",
        opacity: t * 0.15,
        background: `repeating-linear-gradient(
          0deg,
          transparent,
          transparent ${gap}px,
          rgba(0,0,0,0.3) ${gap}px,
          rgba(0,0,0,0.3) ${total}px
        )`,
        willChange: "opacity",
        ...style,
      }}
    />
  );
}
