import { AbsoluteFill, Audio, Sequence, staticFile, useCurrentFrame } from "remotion";
import { SHARED_CHAPTERS } from "../registry/chapters";
import type { ChapterSharedProps } from "../registry/types";
import {
  DENSITY_SPAN,
  DENSITIES,
  LAYOUTS,
  type Density,
  type EpisodeProps,
  type Layout,
  type Screen,
  type StepInScreen,
} from "./types";

/**
 * 三档密度 + 两种布局策略：
 *
 * 密度 (--density)：一屏合几个 step
 *   - bilibili: 3 步合 1 屏
 *   - wechat:   2 步合 1 屏
 *   - douyin:   1 步 1 屏
 *
 * 布局 (--layout)：屏内 step 怎么排
 *   - stacked: 每步按时间顺序轮换全屏（"同位置轮换"——一前一后）
 *   - split:   多步同时显示，按水平切分（"并排"——多图同屏）
 *
 * 推荐：
 *   - bilibili + stacked  ← 默认（B 站深度解说，节奏稳）
 *   - wechat   + stacked  ← 默认（视频号/小红书）
 *   - douyin   + stacked  ← 默认（抖音，单图快切）
 *   - bilibili + split    ← 可选（B 站长视频想做"三联画"风格）
 */
export { DENSITY_SPAN, DENSITIES, LAYOUTS, type Density, type EpisodeProps, type Layout };

function buildScreens(chapters: typeof SHARED_CHAPTERS, span: number): Screen[] {
  const screens: Screen[] = [];
  for (const ch of chapters) {
    for (let i = 0; i < ch.steps.length; i += span) {
      const slice = ch.steps.slice(i, i + span);
      screens.push({
        chapterId: ch.id,
        stepsInScreen: slice.map((step, offset) => {
          const stepIdx = i + offset;
          return {
            step: stepIdx,
            durationFrames: step.durationInFrames || 90,
            audioPath: `audio/${ch.id}/${stepIdx + 1}.mp3`,
          };
        }),
      });
    }
  }
  return screens;
}

function screenDuration(s: Screen): number {
  return s.stepsInScreen.reduce((sum, x) => sum + x.durationFrames, 0);
}

/** 计算 step 在屏内的水平位置（split 布局用）。 */
function slotRect(slotIndex: number, totalSlots: number) {
  if (totalSlots === 1) {
    return { left: "0%", top: "0%", width: "100%", height: "100%" };
  }
  const widthPct = 100 / totalSlots;
  return {
    left: `${slotIndex * widthPct}%`,
    top: "0%",
    width: `${widthPct}%`,
    height: "100%",
  };
}

/**
 * FullScreenStep：屏内一步。占满全屏，按自己的 durationFrames 显示，
 * 该 step 结束就消失（下一个 step 接管）。stacked 布局使用。
 */
const FullScreenStep: React.FC<{
  Component: React.ComponentType<ChapterSharedProps>;
  step: number;
  durationFrames: number;
  audioPath: string;
  offsetInScreen: number;
}> = ({ Component, step, durationFrames, audioPath, offsetInScreen }) => {
  const localFrame = useCurrentFrame();
  const frameInScreen = localFrame;
  const visible = frameInScreen >= offsetInScreen && frameInScreen < offsetInScreen + durationFrames;
  if (!visible) return null;
  const revealProgress = Math.min(1, Math.max(0, (frameInScreen - offsetInScreen) / Math.max(1, durationFrames)));
  return (
    <>
      <AbsoluteFill>
        <Component
          step={step}
          frame={frameInScreen}
          totalFrames={durationFrames}
          revealProgress={revealProgress}
        />
      </AbsoluteFill>
      <Audio src={staticFile(audioPath)} />
    </>
  );
};

/**
 * SplitStep：屏内多步同时显示，水平切分。
 * 所有 step 同时占据屏幕（不是轮换）。
 */
const SplitStep: React.FC<{
  Component: React.ComponentType<ChapterSharedProps>;
  step: number;
  durationFrames: number;
  audioPath: string;
  slotIndex: number;
  totalSlots: number;
}> = ({ Component, step, durationFrames, audioPath, slotIndex, totalSlots }) => {
  const localFrame = useCurrentFrame();
  const revealProgress = Math.min(1, Math.max(0, localFrame / Math.max(1, durationFrames)));
  const rect = slotRect(slotIndex, totalSlots);

  // 关键：Component 按 1920×1080 设计，slot 只有 1/span 宽。
  // 用内层 1920×1080 + transform: scale 缩放 + transform-origin top-left
  // 让 Component 的"画布"完整缩到 slot 里，字号/装饰按比例缩小。
  // scale 因子 = slot.width / 1920 = 1/span (假设每 slot 等宽)
  const GUTTER_PX = 8; // slot 之间的留白
  const slotWidthPct = 100 / totalSlots;

  return (
    <>
      <div
        style={{
          position: "absolute",
          left: rect.left,
          top: rect.top,
          width: `calc(${rect.width} - ${GUTTER_PX}px)`,
          height: `calc(${rect.height} - ${GUTTER_PX}px)`,
          marginLeft: slotIndex === 0 ? 0 : GUTTER_PX / 2,
          marginRight: slotIndex === totalSlots - 1 ? 0 : GUTTER_PX / 2,
          marginTop: GUTTER_PX / 2,
          marginBottom: GUTTER_PX / 2,
          overflow: "hidden",
        }}
      >
        {/*
          Component 设计在 1920×1080。缩放比 = slot 实际宽 / 1920。
          内层 div 保持 1920×1080 物理尺寸（让 Component 仍按原坐标渲染），
          transform: scale(1/span) 把视觉缩到 slot 大小。
          transformOrigin: top left 确保缩放锚点对。
        */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            width: "1920px",
            height: "1080px",
            transform: `scale(${slotWidthPct / 100})`,
            transformOrigin: "top left",
          }}
        >
          <Component
            step={step}
            frame={localFrame}
            totalFrames={durationFrames}
            revealProgress={revealProgress}
          />
        </div>
      </div>
      <Audio src={staticFile(audioPath)} />
    </>
  );
};

export const Episode: React.FC<EpisodeProps> = ({
  density = "bilibili",
  layout = "stacked",
  episodeStart = 0,
  episodeLength,
}) => {
  const span = DENSITY_SPAN[density];
  const chapters = SHARED_CHAPTERS.slice(
    episodeStart,
    episodeLength ? episodeStart + episodeLength : undefined,
  );
  const screens = buildScreens(chapters, span);

  const offsets: number[] = [];
  let acc = 0;
  for (const s of screens) {
    offsets.push(acc);
    acc += screenDuration(s);
  }

  return (
    <AbsoluteFill>
      {screens.map((screen, screenIdx) => {
        const totalFrames = screenDuration(screen);
        const chapter = chapters.find((c) => c.id === screen.chapterId)!;

        if (layout === "split") {
          // split 模式：所有 step 同时显示在屏内不同 slot
          return (
            <Sequence
              key={`${screen.chapterId}-screen-${screenIdx}`}
              from={offsets[screenIdx]}
              durationInFrames={totalFrames}
            >
              {screen.stepsInScreen.map((s, slotIdx) => (
                <SplitStep
                  key={`${screen.chapterId}-step-${s.step}`}
                  Component={chapter.Component}
                  step={s.step}
                  durationFrames={totalFrames}
                  audioPath={s.audioPath}
                  slotIndex={slotIdx}
                  totalSlots={screen.stepsInScreen.length}
                />
              ))}
            </Sequence>
          );
        }

        // stacked 模式：每步按时间顺序轮换
        let accOffset = 0;
        return (
          <Sequence
            key={`${screen.chapterId}-screen-${screenIdx}`}
            from={offsets[screenIdx]}
            durationInFrames={totalFrames}
          >
            {screen.stepsInScreen.map((s) => {
              const offsetInScreen = accOffset;
              accOffset += s.durationFrames;
              return (
                <FullScreenStep
                  key={`${screen.chapterId}-step-${s.step}`}
                  Component={chapter.Component}
                  step={s.step}
                  durationFrames={s.durationFrames}
                  audioPath={s.audioPath}
                  offsetInScreen={offsetInScreen}
                />
              );
            })}
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};

export const Episode01: React.FC<{ density?: Density; layout?: Layout }> = ({
  density = "bilibili",
  layout = "stacked",
}) => <Episode density={density} layout={layout} episodeStart={0} episodeLength={1} />;

export const Episode02: React.FC<{ density?: Density; layout?: Layout }> = ({
  density = "bilibili",
  layout = "stacked",
}) => <Episode density={density} layout={layout} episodeStart={1} episodeLength={1} />;