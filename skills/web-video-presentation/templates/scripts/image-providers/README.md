# Image Providers

`synthesize-images.sh` 是 provider-agnostic 的 runner —— 它自己不知道
怎么调任何图像生成服务，只知道循环 `image-prompts.json`、跳过已存在
文件、打印进度。

**每个 provider 是这个目录下的一个 `.sh` 文件**，定义一个
`image_generate` 函数（必需），以及 `image_check` 和 `image_install_help`。
runner 根据 `PRESENTATION_IMG` 环境变量加载对应文件。

---

## 怎么用

```bash
# 默认（minimax）
npm run synthesize-images

# 换 provider
PRESENTATION_IMG=openai npm run synthesize-images
npm run synthesize-images -- --provider=stability

# 强制全部重生
npm run synthesize-images -- --force
```

`--provider` 命令行参数会覆盖 env var。

---

## 内置 provider

| 文件 | 后端 | 鉴权 | 备注 |
|---|---|---|---|
| `minimax.sh` | MiniMax `mmx` CLI | `mmx auth login --api-key` | **默认**；与 TTS 同源，音色 / 画风一致性好 |
| （更多可加） | —— | —— | 自己加 provider，参考下方 5 段现成片段 |

只内置 minimax —— 与 audio 侧对齐，不替你做更多技术选型。其它后端的
代码片段在下面，复制到 `image-providers/<name>.sh` 即可启用。

---

## 怎么加你自己的 Image provider

1. 在这个目录建 `<name>.sh`（小写、kebab-case）
2. 实现 `image_generate <prompt_json> <out_path>`（必需）
   - `prompt_json` 形如：`{"prompt":"...","size":"1920x1080","style":"...","negative":"...","seed":N}`
   - `out_path` 是目标 PNG 路径，runner 已建好父目录
   - 函数成功 exit 0，失败非 0
3. 可选实现 `image_check`（前置依赖检查，失败 exit 1）
4. 可选实现 `image_install_help`（安装 / 鉴权提示，打到 stderr）

runner 会在循环每个 prompt 前调 `image_check` 一次。

---

## 5 段现成代码片段（复制 → 改名 → 启用）

### ① OpenAI DALL·E 3（curl + OPENAI_API_KEY）

```bash
image_check() {
  [[ -n "$OPENAI_API_KEY" ]] || { echo "✗ OPENAI_API_KEY 未设置" >&2; return 1; }
}

image_install_help() {
  cat <<'EOF' >&2
export OPENAI_API_KEY=sk-xxxxx
EOF
}

image_generate() {
  local prompt_json="$1" out="$2"
  local prompt size
  read prompt size < <(python3 - "$prompt_json" <<'PY'
import json,sys; p=json.loads(sys.argv[1])
print(p["prompt"], p.get("size","1792x1024"))
PY
)
  curl -sS https://api.openai.com/v1/images/generations \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"dall-e-3\",\"prompt\":$prompt,\"size\":\"$size\",\"n\":1,\"response_format\":\"url\"}" \
    | python3 -c "import json,sys,urllib.request; print(urllib.request.urlretrieve(json.load(sys.stdin)['data'][0]['url'],'$out')[0])"
}
```

### ② Stability AI（curl + STABILITY_API_KEY）

```bash
image_check() { [[ -n "$STABILITY_API_KEY" ]] || { echo "✗ STABILITY_API_KEY 未设置" >&2; return 1; } }
image_install_help() { echo "export STABILITY_API_KEY=sk-xxxxx" >&2; }

image_generate() {
  local prompt_json="$1" out="$2"
  local prompt
  prompt=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['prompt'])" "$prompt_json")
  curl -sS https://api.stability.ai/v2beta/stable-image/generate/core \
    -H "Authorization: Bearer $STABILITY_API_KEY" \
    -F "prompt=$prompt" -F "output_format=png" -o "$out"
}
```

### ③ Replicate（curl + REPLICATE_API_TOKEN）

```bash
image_check() { [[ -n "$REPLICATE_API_TOKEN" ]] || { echo "✗ REPLICATE_API_TOKEN 未设置" >&2; return 1; } }
image_install_help() { echo "export REPLICATE_API_TOKEN=r8_xxxxx" >&2; }

image_generate() {
  local prompt_json="$1" out="$2"
  local prompt
  prompt=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['prompt'])" "$prompt_json")
  curl -sS https://api.replicate.com/v1/predictions \
    -H "Authorization: Token $REPLICATE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"version\":\"...\",\"input\":{\"prompt\":\"$prompt\"}}" \
    | python3 -c "import json,sys,urllib.request; ..."  # 轮询 → 下载
}
```

### ④ 本地 diffusers（python，无需 key）

```bash
image_check() { python3 -c "import diffusers" 2>/dev/null || { echo "✗ pip install diffusers" >&2; return 1; } }
image_install_help() { echo "pip install diffusers torch" >&2; }

image_generate() {
  local prompt_json="$1" out="$2"
  python3 - "$prompt_json" "$out" <<'PY'
import json, sys, torch
from diffusers import StableDiffusionPipeline
p = json.loads(sys.argv[1])
pipe = StableDiffusionPipeline.from_pretrained("runwayml/stable-diffusion-v1-5", torch_dtype=torch.float16)
pipe(p["prompt"]).images[0].save(sys.argv[2])
PY
}
```

### ⑤ mock（开发用，写纯色 PNG）

```bash
image_check() { return 0; }
image_install_help() { echo "(mock provider: no setup needed)" >&2; }

image_generate() {
  local prompt_json="$1" out="$2"
  python3 - "$prompt_json" "$out" <<'PY'
import json, sys
from struct import pack
import zlib
p = json.loads(sys.argv[1])
w, h = map(int, p.get("size","1920x1080").split("x"))
# 纯色 PNG（基于 prompt hash 选个稳定颜色）
seed = sum(ord(c) for c in p["prompt"]) % 0xFFFFFF
r, g, b = (seed >> 16) & 0xFF, (seed >> 8) & 0xFF, seed & 0xFF
raw = b"".join(b"\x00" + bytes([r,g,b]) * w for _ in range(h))
def chunk(t, d):
    return pack(">I", len(d)) + t + d + pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw))
png += chunk(b"IEND", b"")
open(sys.argv[2], "wb").write(png)
PY
}
```

---

## prompt 字段参考（v1.3+ 工程化 schema）

`extract-images.ts` 扫每个章节的 `images.ts`，数组每个元素是：

```ts
{
  step:               number,                                  // 1-indexed，不写按数组下标补
  subject:            string,                                  // 必填，画面主体（不要写风格/颜色/镜头/反向）
  composition?:       string,                                  // 镜头/构图/视角
  style?:             string,                                  // 风格（ink-wash / oil / 3d / anime / ...）
  palette?:           string,                                  // 调色板描述
  negative?:          string,                                  // 反向 prompt
  size?:              "1920x1080" | ...,                       // 默认 1920×1080
  aspect?:            "16:9" | "4:3" | "1:1" | ...,
  seed?:              number,                                  // 固定 seed → 可复现
  imageReference?:    "style-anchors/<name>.png",             // 参考图路径（相对 vite/public/images）
  referenceStrength?: number,                                  // 0~1，参考图权重（建议 0.55~0.75）
  out?:               "01-foo/1.png",                          // 输出路径（默认按 folder+step）
}
```

`extract-images.ts` 把 `subject/composition/style/palette` + 主题的
`visualAnchors.{palette,texture,compositionBias}` 拼成最终 prompt 字符串。
**主题锚点自动注入，无需在每章重复写**——换主题就换风格。

### 主题 visualAnchors 是什么

`themes/<id>/theme.json` 新增字段：

```json
{
  "visualAnchors": {
    "palette":         "ivory cream (#f5f1e8) + deep forest green (#1a2e1f) + moss accent (#4d7a4d)",
    "texture":         "vintage matte paper grain, soft natural daylight, organic ink bleed",
    "compositionBias": "National Geographic framing, off-center subject, generous breathing room"
  }
}
```

`extract-images.ts` 自动读主题并注入每条 prompt。要关掉（用纯手工 prompt）：`npm run extract-images -- --no-anchor`

---

## 锁风格：首章参考图机制（强烈推荐）

**问题**：每次跑 `synthesize-images` 都是"独立抽卡"——同样的 prompt 跑两次出两张完全不同的图；多张图之间没有视觉一致性。

**解法**：把第一章的某张成功图作为**风格锚点**（reference image），所有后续生成都喂回去——`referenceStrength: 0.55~0.75` 时风格基本锁死。

### 流程

1. **首章 4-8 张候选**：写完第一章 `images.ts`，跑 `npm run synthesize-images -- --force`。
2. **挑 1 张参考图**：用户/agent 选一张最贴合主题的图，存到：
   ```
   shared/assets/style-anchors/<theme-id>-hero.png
   ```
3. **回填字段**：把 `imageReference` 字段加到所有章节的 `images.ts`：
   ```ts
   {
     subject: "...",
     imageReference: "style-anchors/midnight-press-hero.png",  // 相对 vite/public/images
     referenceStrength: 0.65,
   }
   ```
4. **Re-run**：`npm run synthesize-images` 即可——所有图都从同一张锚点出发。

### 注意事项

- `referenceStrength` 越高越贴近参考图（颜色 / 笔触 / 构图），越低越自由
  - 0.5-0.65：风格锁，主体变化大（**推荐**）
  - 0.7-0.85：几乎抄构图
  - 0.9+：可能直接复刻参考图
- 每个主题**用不同的 hero.png**——切主题就重选
- 锚点图**要**符合主题 token 配色；不然后续全跑偏

### 出问题怎么办

- **图风格飘** → `referenceStrength` 提到 0.7+
- **图太像参考图** → 降到 0.5，或换锚点
- **图内容死板** → 配合 prompt 调 subject 描述
- **首张图自己就差** → 别往下走，先手调 prompt + 主题 anchor，重新出
