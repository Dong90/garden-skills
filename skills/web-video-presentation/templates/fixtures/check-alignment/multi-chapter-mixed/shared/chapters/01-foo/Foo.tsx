import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  // 完美：通过所有不变式
  if (step === 0) return <div>第一帧</div>;
  if (step === 1) return <div>第二帧</div>;
  if (step === 2) return <div>第三帧</div>;
}
