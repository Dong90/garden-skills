import type { CSSProperties, ReactNode } from "react";

/**
 * Ken Burns — slow zoom/pan on a container.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 *
 * Avoid CSStransition-flicker in Remotion by routing through opacity/filter
 * that derive from `progress` directly (no transition JS delay).
 */
export interface KenBurnsProps {
  progress: number;
  /** Scale range: from startScale → 1.0 */
  startScale?: number;
  /** Pan direction in degrees (0=center zoom, 45=top-left→bottom-right) */
  panAngle?: number;
  /** Pan distance in px */
  panDistance?: number;
  children: ReactNode;
  className?: string;
  style?: CSSProperties;
}

export function KenBurns({
  progress,
  startScale = 1.06,
  panAngle = 0,
  panDistance = 12,
  children,
  className,
  style,
}: KenBurnsProps) {
  const t = Math.max(0, Math.min(1, progress));
  const scale = startScale + (1 - startScale) * t;
  const radians = (panAngle * Math.PI) / 180;
  const dx = Math.cos(radians) * panDistance * (1 - t);
  const dy = Math.sin(radians) * panDistance * (1 - t);

  return (
    <div
      className={className}
      style={{
        position: "relative",
        overflow: "hidden",
        width: "100%",
        height: "100%",
        ...style,
      }}
    >
      <div
        style={{
          width: "100%",
          height: "100%",
          transform: `scale(${scale}) translate(${dx}px, ${dy}px)`,
          willChange: "transform",
        }}
      >
        {children}
      </div>
    </div>
  );
}
