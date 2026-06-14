import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  // I1 违例: narrations.length=3 → step 取值应为 0..2，tsx 写 step===5
  if (step === 0) {
    return <div>第一帧</div>;
  }
  if (step === 1) {
    return <div>第二帧</div>;
  }
  if (step === 2) {
    return <div>第三帧</div>;
  }
  if (step === 5) {
    return <div>越界第五帧</div>;
  }
  return null;
}
