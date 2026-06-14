import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  if (step === 0) {
    // I3 违例: images.ts 不存在，tsx 还引图
    return (
      <div>
        <span>第一帧</span>
        <img src="images/01-foo/1.png" alt="" />
      </div>
    );
  }
  if (step === 1) {
    return (
      <div>
        <span>第二帧</span>
        <img src="images/01-foo/2.png" alt="" />
      </div>
    );
  }
  if (step === 2) {
    return (
      <div>
        <span>第三帧</span>
        <img src="images/01-foo/3.png" alt="" />
      </div>
    );
  }
  return null;
}