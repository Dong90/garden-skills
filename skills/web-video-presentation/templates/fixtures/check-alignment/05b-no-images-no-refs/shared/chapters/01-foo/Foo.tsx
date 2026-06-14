import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  if (step === 0) return <div>第一帧纯文字</div>;
  if (step === 1) return <div>第二帧纯文字</div>;
  if (step === 2) return <div>第三帧纯文字</div>;
}
