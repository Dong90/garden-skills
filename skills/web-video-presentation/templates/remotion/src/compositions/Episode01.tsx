import { AbsoluteFill, Sequence } from "remotion";
import { SHARED_CHAPTERS } from "../registry/chapters";
import { StepSegment } from "./StepSegment";

export const Episode01: React.FC = () => {
  const chaptersInEp01 = SHARED_CHAPTERS.slice(0, 1);
  let offset = 0;

  return (
    <AbsoluteFill>
      {chaptersInEp01.map((ch) =>
        ch.steps.map((step, stepIdx) => {
          const from = offset;
          const dur = step.durationInFrames || 90;
          offset += dur;
          return (
            <Sequence
              key={`${ch.id}-${stepIdx}`}
              from={from}
              durationInFrames={dur}
            >
              <StepSegment
                Component={ch.Component}
                step={stepIdx}
                totalFrames={dur}
                audioPath={`audio/${ch.id}/${stepIdx + 1}.mp3`}
              />
            </Sequence>
          );
        }),
      )}
    </AbsoluteFill>
  );
};
