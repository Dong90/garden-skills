import type { CSSProperties } from "react";

/**
 * Typewriter — character-by-character text reveal.
 * Dual-mode: Vite (progress 0→1 toggle) + Remotion (progress continuous).
 *
 * progress=0 shows nothing, progress=1 shows full text.
 * Each character reveals at progress = (index / totalChars).
 */
export interface TypewriterProps {
  progress: number;
  text: string;
  /** Cursor character (default "|") */
  cursor?: string;
  /** Show blinking cursor after full reveal */
  showCursor?: boolean;
  className?: string;
  style?: CSSProperties;
}

export function Typewriter({
  progress,
  text,
  cursor = "|",
  showCursor = false,
  className,
  style,
}: TypewriterProps) {
  const chars = [...text];
  const total = chars.length;
  const revealedCount = Math.floor(progress * total);

  return (
    <span className={className} style={style}>
      {chars.map((char, i) => (
        <span
          key={i}
          style={{
            opacity: i < revealedCount ? 1 : 0,
            display: "inline",
          }}
        >
          {char}
        </span>
      ))}
      {showCursor && progress >= 1 && (
        <span
          style={{
            animation: "caret-blink 1s step-end infinite",
            opacity: 0.6,
            marginLeft: 2,
          }}
        >
          {cursor}
        </span>
      )}
    </span>
  );
}
