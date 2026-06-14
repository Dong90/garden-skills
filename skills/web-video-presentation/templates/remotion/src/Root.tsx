import { Composition } from "remotion";
import "../../shared/styles/tokens.css";
import "../../shared/styles/base.css";
import "../../shared/styles/fonts.css";
import "../../shared/styles/animations.css";
import { Episode01, Episode02, DENSITIES, LAYOUTS, type Density, type Layout } from "./compositions/Episode";
import { getTotalFrames } from "./registry/chapters";

/**
 * 三种模式（v1.4+）：
 *   A. Vite 互动    — npm run dev
 *   B. Remotion 离屏 — npm run render -- --density=...
 *   C. minimax 真生 — npm run render:minimax -- --max=N（10s/段，最多 3 段）
 *
 * Composition 注册：
 *   - 6 个 Remotion 池：每集每档每布局（Episode01-bilibili-stacked 等）
 *   - 18 个 minimax 池：每集每档每段号（minimax-01-bilibili-1 等，10s 固定）
 *
 * 三档密度：bilibili / wechat / douyin
 */

const makeComposition = (
  id: string,
  Episode: React.FC<{
    density?: Density;
    layout?: Layout;
    episodeStart?: number;
    episodeLength?: number;
  }>,
  chapterIdx: number,
  density: Density,
  layout: Layout,
  overrideFrames?: number,
  episodeStart = 0,
  episodeLength = 1,
) => (
  <Composition
    id={id}
    component={Episode}
    durationInFrames={overrideFrames ?? getTotalFrames(chapterIdx)}
    fps={30}
    width={1920}
    height={1080}
    defaultProps={{ density, layout, episodeStart, episodeLength }}
  />
);

const EPISODES = [
  { Component: Episode01, chapterIdx: 0 },
  { Component: Episode02, chapterIdx: 1 },
];

// minimax-cli 段配置
const MINIMAX_SEGMENT_FRAMES = 300; // 10s @ 30fps
const MINIMAX_MAX_SEGMENTS = 3;     // 最多 3 段

export const RemotionRoot: React.FC = () => (
  <>
    {/* B. Remotion 离屏池（12 个：2 集 × 3 密度 × 2 布局） */}
    {EPISODES.flatMap(({ Component, chapterIdx }, i) =>
      DENSITIES.flatMap((d) =>
        LAYOUTS.map((l) =>
          makeComposition(
            `Episode0${i + 1}-${d}-${l}`,
            Component,
            chapterIdx,
            d,
            l,
            undefined,
            i,         // episodeStart
            1,         // episodeLength
          ),
        ),
      ),
    )}

    {/* C. minimax-cli 池（18 个：2 集 × 3 密度 × 3 段） */}
    {EPISODES.flatMap(({ Component, chapterIdx }, i) =>
      DENSITIES.flatMap((d) =>
        Array.from({ length: MINIMAX_MAX_SEGMENTS }, (_, seg) =>
          makeComposition(
            `minimax-0${i + 1}-${d}-${seg + 1}`,
            Component,
            chapterIdx,
            d,
            "stacked",  // minimax 只用 stacked 布局
            MINIMAX_SEGMENT_FRAMES,
            i,
            1,
          ),
        ),
      ),
    )}
  </>
);