/**
 * Per-step image spec for this chapter. **Replace with your own.**
 *
 * v1.3+ 工程化 schema —— 详见 references/CHAPTER-CRAFT.md "图像 prompt 工程"
 * 与 templates/scripts/image-providers/README.md
 *
 * 字段：
 *   step               number, 1-indexed（不写则按数组下标补）
 *   subject            必填，画面主体（不要写风格/颜色/镜头/反向——这些走主题）
 *   composition?       镜头/构图/视角
 *   style?             风格（ink-wash / oil / 3d / anime / ...）
 *   palette?           调色板（与主题 tokens 对齐）
 *   negative?          反向 prompt
 *   size?              "1920x1080" 等
 *   aspect?            "16:9" | "4:3" | "1:1" | ...
 *   seed?              数字 seed
 *   imageReference?    "style-anchors/<name>.png"  锁风格
 *   referenceStrength? 0~1，建议 0.55~0.75
 *   out?               输出路径（默认 images/<folder>/<step>.png）
 *
 * 长度 ≤ step 数；不写 = 该步无图。
 *
 * 首章定锚流程：
 *   1. 写完第一章 images.ts → npm run extract:images + synthesize-images
 *   2. 出 4-8 张候选图 → 用户挑 1 张
 *   3. 存到 shared/assets/style-anchors/<theme-id>-hero.png
 *   4. 取消下方 imageReference 注释 + 写其他章节
 *   5. 后续所有图都从锚点出发
 */
export const images = [
  {
    // 1 分钟视频推荐 4~5 张图；3 步示例只配 1 张
    subject: "<画面主体，例如：侏罗纪河床散落 5 颗恐龙蛋化石卵石>",
    composition: "<镜头/构图，例如：俯拍 60°，前景 5 颗蛋形卵石占画面下三分之一，中景薄雾，背景虚化的远古树林剪影>",
    style: "<风格，与主题气质对齐，例如：ink-wash>",
    palette: "<调色板，例如：水墨灰 + 朱砂点 + 米黄留白>",
    negative: "<反向提示，例如：卡通, 紫粉, 高饱和, 文字, 边框, 印章>",
    size: "1920x1080",
    aspect: "16:9",
    referenceStrength: 0.65,
    // imageReference: "style-anchors/<theme-id>-hero.png",  ← 首章手选后打开
    out: "images/01-example/1.png",
  },
];
