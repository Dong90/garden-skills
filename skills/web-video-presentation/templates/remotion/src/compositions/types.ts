/**
 * compositions/types.ts — Episode 组件共享类型
 *
 * 拆自 Episode.tsx 让组件文件只关注实现。
 */

export type Density = "bilibili" | "wechat" | "douyin";
export type Layout = "stacked" | "split";

export const DENSITY_SPAN: Record<Density, number> = {
  bilibili: 3,
  wechat: 2,
  douyin: 1,
};

export const DENSITIES: Density[] = ["bilibili", "wechat", "douyin"];
export const LAYOUTS: Layout[] = ["stacked", "split"];

export interface EpisodeProps {
  density?: Density;
  layout?: Layout;
  episodeStart?: number;
  episodeLength?: number;
}

export interface StepInScreen {
  step: number;
  durationFrames: number;
  audioPath: string;
}

export interface Screen {
  chapterId: string;
  stepsInScreen: StepInScreen[];
}
