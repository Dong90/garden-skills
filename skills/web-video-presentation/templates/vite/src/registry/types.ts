import type { ComponentType } from "react";
import type { Step } from "../../../shared/chapters/01-example/narrations";

export interface ChapterStepProps {
  step: number; // 0..(narrations.length - 1)
  /** Vite 模式可省；Remotion 模式由 StepSegment 传。详见 references/REMOTION-MAPPING.md */
  frame?: number;
  totalFrames?: number;
  revealProgress?: number;
}

/**
 * Narration entry from the shared truth source. Re-exported here so chapter
 * code can import { type Step } from the local registry/types.
 */
export type Narration = Step;

export interface ChapterDef {
  id: string;
  title: string;
  /**
   * Per-step narration data. **Length === total steps in this chapter.**
   * This is the single source of truth for step count, audio synthesis,
   * and Remotion render duration.
   */
  narrations: Narration[];
  Component: ComponentType<ChapterStepProps>;
}
