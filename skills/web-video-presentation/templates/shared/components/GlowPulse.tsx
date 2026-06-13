import type { CSSProperties, ReactNode } from "react";

/**
 * GlowPulse — accent-color pulsing glow shadow wrapper.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 */
export interface GlowPulseProps {
  progress: number;
  /** Glow radius in px (default 20) */
  radius?: number;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}

export function GlowPulse({
  progress,
  radius = 20,
  children,
  className,
  style,
}: GlowPulseProps) {
  const t = Math.max(0, Math.min(1, progress));

  return (
    <div
      className={className}
      style={{
        display: "inline-block",
        opacity: t,
        boxShadow: `0 0 ${radius}px var(--accent-glow)`,
        willChange: "opacity, box-shadow",
        ...style,
      }}
    >
      {children}
    </div>
  );
}
