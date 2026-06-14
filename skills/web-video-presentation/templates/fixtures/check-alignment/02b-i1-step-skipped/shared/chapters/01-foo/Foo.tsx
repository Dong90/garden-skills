import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  // I1 违例: tsx 跳过 step===1，从 0 直接跳到 2
  if (step === 0) {
    return <div>第一帧</div>;
  }
  if (step === 2) {
    return <div>第三帧</div>;
  }
  return null;
}
