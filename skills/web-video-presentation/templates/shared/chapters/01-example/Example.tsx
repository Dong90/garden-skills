import { MaskReveal } from "../../components/MaskReveal";
import { FadeIn } from "../../components/FadeIn";
import "./Example.css";

/**
 * 共享层章节 —— 双渲染器通用。
 *
 * 约束：
 *   1. 不允许 useState / useEffect / setTimeout（Remotion 兼容性）
 *   2. 不允许 import vite/ 下任何文件
 *   3. 入场动画统一通过 progress prop 表达
 *
 * 调用方：
 *   • Vite 端：传 step + revealProgress（Vite 端 App 算）
 *   • Remotion 端：传 step + frame + totalFrames + revealProgress
 */
export interface ChapterSharedProps {
  /** 0-indexed 当前 step */
  step: number;
  /** Remotion 模式：当前 step 内帧偏移 */
  frame?: number;
  /** Remotion 模式：当前 step 总帧数 */
  totalFrames?: number;
  /** 受控的入场动画进度 0~1（Vite 模式 = 0/1 切换；Remotion 模式 = frame/30） */
  revealProgress?: number;
}

export default function ExampleChapter({
  step,
  revealProgress = 0,
}: ChapterSharedProps) {
  /* Step 0 — magazine cover */
  if (step === 0) {
    return (
      <div className="ex-scene scene-pad">
        <header className="masthead">
          <span className="brand">Your Presentation</span>
          <span className="issue">Issue · 01 — Replace this</span>
        </header>
        <hr className="rule" style={{ marginTop: "var(--space-5)" }} />

        <div className="ex-cover-body">
          <div className="kicker">Chapter 01 — Example</div>
          <h1 className="ex-cover-h">
            <MaskReveal progress={Math.max(0, revealProgress - 0)} direction="up">
              <span className="serif-cn">这是&nbsp;</span>
            </MaskReveal>
            <MaskReveal progress={Math.max(0, revealProgress - 0.2)} direction="up">
              <span className="serif-it ex-em">first&nbsp;step</span>
            </MaskReveal>
            <MaskReveal progress={Math.max(0, revealProgress - 0.45)} direction="up">
              <span className="serif-cn">.</span>
            </MaskReveal>
          </h1>
          <div className="ex-cover-foot label-mono">
            <span className="dot-accent" /> &nbsp;Tap anywhere to advance
          </div>
        </div>
      </div>
    );
  }

  /* Step 1 — split layout */
  if (step === 1) {
    return (
      <div className="ex-scene scene-pad">
        <header className="masthead">
          <span className="brand">Your Presentation</span>
          <span className="issue">Issue · 01</span>
        </header>
        <hr className="rule" style={{ marginTop: "var(--space-5)" }} />

        <div className="ex-split">
          <div className="ex-split-num hero-num">02</div>
          <div className="ex-split-body">
            <div className="kicker">每一步</div>
            <h2 className="ex-split-h">
              <MaskReveal progress={Math.max(0, revealProgress - 0)} direction="up">
                <span className="serif-cn">独占&nbsp;</span>
              </MaskReveal>
              <MaskReveal progress={Math.max(0, revealProgress - 0.2)} direction="up">
                <span className="serif-it ex-em">整个屏幕</span>
              </MaskReveal>
              <MaskReveal progress={Math.max(0, revealProgress - 0.45)} direction="up">
                <span className="serif-cn">.</span>
              </MaskReveal>
            </h2>
            <FadeIn progress={revealProgress} fromY={12}>
              <p className="ex-split-p">
                The current theme controls every visual detail — palette,
                fonts, hero-number style, rule weight, decoration, motion.
                The chapter code is theme-agnostic.
              </p>
            </FadeIn>
          </div>
        </div>
      </div>
    );
  }

  /* Step 2 — pull-quote close */
  return (
    <div className="ex-scene scene-pad ex-close">
      <div className="ex-close-inner">
        <div className="kicker">Now</div>
        <div className="pull-quote ex-quote">
          <MaskReveal progress={Math.max(0, revealProgress - 0)} direction="up">
            <span className="serif-cn">Replace this with </span>
          </MaskReveal>
          <MaskReveal progress={Math.max(0, revealProgress - 0.25)} direction="up">
            <span className="serif-it ex-em">your own&nbsp;</span>
          </MaskReveal>
          <MaskReveal progress={Math.max(0, revealProgress - 0.5)} direction="up">
            <span className="serif-cn">chapters.</span>
          </MaskReveal>
        </div>
        <div className="ex-close-foot label-mono">
          See SKILL.md / CHAPTER-CRAFT.md / THEMES.md
        </div>
      </div>
    </div>
  );
}
