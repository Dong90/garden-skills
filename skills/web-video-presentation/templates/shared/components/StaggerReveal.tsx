import type { CSSProperties, ReactElement } from "react";

/**
 * StaggerReveal — reveals children one by one based on progress.
 * Each child has its own progress window. Child i starts at (i * staggerDelay)
 * and finishes at (i * staggerDelay + childWindow).
 *
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 */
export interface StaggerRevealProps {
  progress: number;
  /** Delay fraction per child (default 0.15). With 3 children: [0-0.33, 0.33-0.67, 0.67-1.0] */
  staggerDelay?: number;
  /** Gap between items */
  gap?: string;
  children: ReactElement[];
  className?: string;
  style?: CSSProperties;
}

export function StaggerReveal({
  progress,
  staggerDelay = 0.15,
  gap = "var(--space-3)",
  children,
  className,
  style,
}: StaggerRevealProps) {
  const count = children.length;
  // Each child gets equal portion: childWindow = 1 / count
  const childWindow = count > 0 ? 1 / count : 1;

  return (
    <div
      className={className}
      style={{
        display: "flex",
        flexDirection: "column",
        gap,
        ...style,
      }}
    >
      {children.map((child, i) => {
        const childStart = i * childWindow;
        const childEnd = (i + 1) * childWindow;
        const childProgress = Math.max(
          0,
          Math.min(1, (progress - childStart) / (childEnd - childStart)),
        );

        return (
          <div
            key={i}
            style={{
              opacity: childProgress,
              transform: `translateY(${(1 - childProgress) * 8}px)`,
              willChange: "opacity, transform",
            }}
          >
            {child}
          </div>
        );
      })}
    </div>
  );
}
