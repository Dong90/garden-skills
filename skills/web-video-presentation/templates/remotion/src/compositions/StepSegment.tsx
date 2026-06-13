import type { ComponentType } from "react";
import { AbsoluteFill, Audio, staticFile, useCurrentFrame } from "remotion";
import type { ChapterSharedProps } from "../registry/types";

interface Props extends ChapterSharedProps {
  Component: ComponentType<ChapterSharedProps>;
  audioPath?: string;
}

export const StepSegment: React.FC<Props> = ({
  audioPath,
  Component,
  step,
  totalFrames = 30,
}) => {
  const localFrame = useCurrentFrame();
  const revealProgress = Math.min(1, localFrame / Math.max(1, totalFrames));

  return (
    <AbsoluteFill>
      <Component
        step={step}
        frame={localFrame}
        totalFrames={totalFrames}
        revealProgress={revealProgress}
      />
      {audioPath && <Audio src={staticFile(audioPath)} />}
    </AbsoluteFill>
  );
};
