import type { ComponentType } from "react";

export interface ChapterSharedProps {
  step: number;
  frame?: number;
  totalFrames?: number;
  revealProgress?: number;
}

export interface ChapterDefShared {
  id: string;
  title: string;
  Component: ComponentType<ChapterSharedProps>;
  steps: Array<{
    text: string;
    durationInFrames: number;
  }>;
}
