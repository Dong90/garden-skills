import type { ChapterSharedProps } from "@shared/types";

export default function Foo({ step }: ChapterSharedProps) {
  if (step === 0) {
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
  if (step === 3) {
    return <div>第四帧无图</div>;
  }
  if (step === 4) {
    // I3 违例: 引了 images/01-foo/5.png，但 images.ts 里没 step=5
    return (
      <div>
        <span>第五帧</span>
        <img src="images/01-foo/5.png" alt="" />
      </div>
    );
  }
  return null;
}
