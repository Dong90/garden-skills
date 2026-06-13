import type { ChapterDefShared } from "./types";
import ExampleChapter from "../../../shared/chapters/01-example/Example";
import { narrations as exampleSteps } from "../../../shared/chapters/01-example/narrations";

export const SHARED_CHAPTERS: ChapterDefShared[] = [
  {
    id: "01-example",
    title: "示例章节",
    Component: ExampleChapter,
    steps: exampleSteps,
  },
];

export const getTotalFrames = (chapterIdx: number): number =>
  SHARED_CHAPTERS[chapterIdx]!.steps.reduce(
    (s, n) => s + (n.durationInFrames || 90),
    0,
  );
