/**
 * 共享层章节的 Step 元数据。
 *
 * durationInFrames 单位：@30fps 的帧数。
 *   • Vite 互动模式：实际播放靠 <audio>.ended 事件驱动，durationInFrames 不用
 *   • Remotion 出片模式：每步时长 = durationInFrames / 30 秒
 *
 * 0 表示"待 probe 注入"——跑 `npm run probe` 后由 ffprobe 回填。
 */
export interface Step {
  text: string;
  /** @30fps 帧数。0 = 未注入 */
  durationInFrames: number;
  /** 可选视觉提示，给脚本翻译用，不影响运行时 */
  hint?: string;
}

export const narrations: Step[] = [
  { text: "这是第一步的开场白。", durationInFrames: 0, hint: "hook" },
  { text: "接下来讲第二个要点。", durationInFrames: 0, hint: "list" },
];
