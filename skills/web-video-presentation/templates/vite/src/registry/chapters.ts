import type { ChapterDef } from "./types";
import ExampleChapter from "../../../shared/chapters/01-example/Example";
import { narrations as exampleNarrations } from "../../../shared/chapters/01-example/narrations";

export const CHAPTERS: ChapterDef[] = [
  {
    id: "01-example",
    title: "示例章节",
    narrations: exampleNarrations,
    Component: ExampleChapter,
  },
];
