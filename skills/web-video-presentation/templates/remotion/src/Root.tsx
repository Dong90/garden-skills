import { Composition } from "remotion";
import "../../shared/styles/tokens.css";
import "../../shared/styles/base.css";
import "../../shared/styles/fonts.css";
import "../../shared/styles/animations.css";
import { Episode01 } from "./compositions/Episode01";
import { Episode02 } from "./compositions/Episode02";
import { getTotalFrames } from "./registry/chapters";

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="Episode01"
      component={Episode01}
      durationInFrames={getTotalFrames(0)}
      fps={30}
      width={1920}
      height={1080}
    />
    <Composition
      id="Episode02"
      component={Episode02}
      durationInFrames={300}
      fps={30}
      width={1920}
      height={1080}
    />
  </>
);
