import type { CSSProperties } from "react";

/**
 * BarGrow — horizontal bar that grows from 0% to targetWidth based on progress.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 */
export interface BarGrowProps {
  progress: number;
  /** Target width as CSS value e.g. "80%", "400px" */
  targetWidth: string;
  /** Bar height (default 4px) */
  height?: string;
  /** Bar color (default var(--accent)) */
  color?: string;
  className?: string;
  style?: CSSProperties;
}

export function BarGrow({
  progress,
  targetWidth,
  height = "4px",
  color = "var(--accent)",
  className,
  style,
}: BarGrowProps) {
  const t = Math.max(0, Math.min(1, progress));

  // Parse targetWidth numeric value to compute current width
  const match = targetWidth.match(/^([\d.]+)(%|px)$/);
  const unit = match ? match[2] : "%";
  const val = match ? parseFloat(match[1]) : 100;
  const currentVal = (val * t).toFixed(unit === "%" ? 0 : 1);

  return (
    <div
      className={className}
      style={{
        width: "100%",
        height,
        background: "var(--rule)",
        borderRadius: "2px",
        overflow: "hidden",
        ...style,
      }}
    >
      <div
        style={{
          width: `${currentVal}${unit}`,
          height: "100%",
          background: color,
          borderRadius: "2px",
          willChange: "width",
          transition: "width 50ms linear",
        }}
      />
    </div>
  );
}
