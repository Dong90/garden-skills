import type { ChapterSharedProps } from "@shared/types";

export default function Bar({ step }: ChapterSharedProps) {
  // I1 违例: narrations.length=3，tsx 写 step===5
  if (step === 0) return <div>第一帧</div>;
  if (step === 1) return <div>第二帧</div>;
  if (step === 2) return <div>第三帧</div>;
  if (step === 5) return <div>越界第五帧</div>;
}
