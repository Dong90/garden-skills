import type { CSSProperties } from "react";

/**
 * NumberCounter — animated number from→to via progress.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 */
export interface NumberCounterProps {
  progress: number;
  from: number;
  to: number;
  /** Intl.NumberFormat options for display (default none) */
  formatOptions?: Intl.NumberFormatOptions;
  className?: string;
  style?: CSSProperties;
}

export function NumberCounter({
  progress,
  from,
  to,
  formatOptions,
  className,
  style,
}: NumberCounterProps) {
  const t = Math.max(0, Math.min(1, progress));
  const value = Math.round(from + (to - from) * t);
  const display = formatOptions
    ? new Intl.NumberFormat(undefined, formatOptions).format(value)
    : String(value);

  return (
    <span className={className} style={style}>
      {display}
    </span>
  );
}
