# 4 步剧本 · 完整试跑手册

> 适用：Cursor / Codex 桌面 / Claude 三端均已装好。
> 本文档可直接复制命令跑，约 15-30 分钟（其中 agent 写稿部分取决于你）。

---

## 0. 前置检查（1 分钟）

跑这 4 条，全 ✓ 才能继续：

```bash
# A. 仓库最新
git log --oneline -1
# 期望: 0a12356 fix(web-video-presentation): judge.sh 改用 local 变量

# B. 三端 symlink 都在
for p in ~/.claude/skills/web-video-presentation \
         ~/.codex/prompts/chapter-to-video-plan.md \
         ~/.agents/skills/web-video-presentation \
         /Users/shixiaocai/Desktop/chuangye/garden-skills/.cursor/commands/chapter-to-video-{plan,run,status,record}.md; do
  if [[ -e "$p" || -L "$p" ]]; then echo "  ✓ $p"; else echo "  ✗ $p 缺失"; fi
done

# C. bash 脚本能跑
bash skills/web-video-presentation/scripts/chapter-to-video.sh --help 2>&1 | head -3
# 期望: 列出 usage

# D. Node + Python
node -v   # ≥ v18
python3 --version
```

任一 ✗ → 看本文末尾"问题排查"。

---

## 1. 准备输入（30 秒）

```bash
# 准备一段短章节（公版《匆匆》节选）
mkdir -p /tmp/wvp-test
cat > /tmp/wvp-test/chapter.md <<'INPUT'
# 匆匆 · 朱自清

燕子去了，有再来的时候；杨柳枯了，有再青的时候；桃花谢了，有再开的时候。但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？
我不知道他们给了我多少日子，但我的手确乎是渐渐空虚了。在默默里算着，八千多日子已经从我手中溜去；像针尖上一滴水滴在大海里，我的日子滴在时间的流里，没有声音，也没有影子。我不禁头涔涔而泪潸潸了。
INPUT
ls -la /tmp/wvp-test/chapter.md
```

---

## 2. 三种方式启动 init（任选其一）

| IDE | 怎么调 |
|---|---|
| **Cursor** | 打开 `garden-skills/` → Cmd+I → 输入 `/chapter-to-video` → 让 agent 跑 init |
| **Codex 桌面** | 在仓库根的 terminal 跑下面 bash，或在 chat 输入 prompt |
| **Claude Code** | 在仓库根的 terminal 跑下面 bash，或 `/chapter-to-video-run` 让 agent 跑 |

**直接 bash（最稳，三端通用）**：

```bash
cd /Users/shixiaocai/Desktop/chuangye/garden-skills
bash skills/web-video-presentation/scripts/chapter-to-video.sh \
  /tmp/wvp-test/chapter.md \
  --out=/tmp/wvp-test/my-video \
  --theme=kraft-paper
```

**期望输出**：
- `✓ 准备完成`
- `快照 P0: phase-P0-xxxxxxxx.tar.gz`  ← **自动写了 P0 快照**
- `my-video/` 出现，含 article.md / STATE.md / presentation/

**验证**：
```bash
ls /tmp/wvp-test/my-video/
# 期望: article.md  meta.json  STATE.md  BOOK-CHAPTER.md  presentation/  .book-video/

cat /tmp/wvp-test/my-video/.book-video/state.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(f'phase={d[\"phase\"]} status={d[\"phase_status\"]}')"
# 期望: phase=P0 status=done
```

---

## 3. 步 1 · plan（read-only 查进度）

**bash**：
```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status /tmp/wvp-test/my-video
```

**期望输出关键段**：
```
📊 4 步剧本
  [✓] plan   [·] run   [·] status   [·] record

📊 5 步子任务
  ✓ 1. init             (phase=P0, status=done)
  ▱ 2. 写稿             (script.md=False, outline.md=False)
  ▱ 3. 验收
  ▱ 4. 多媒体
  ▱ 5. 录屏

📦 快照: 1 个
    • phase-P0-xxxxxxxx.tar.gz
```

**Cursor 入口**：Cmd+I → `/chapter-to-video-plan` → agent 跑 status
**Codex 入口**：Cmd+I → `/chapter-to-video-plan` → agent 跑 status
**Claude 入口**：Cmd+I → `/chapter-to-video-plan` → agent 跑 status

---

## 4. 步 2 · run（state-driven 推进）

### 4.1 第一次 run：提示写稿

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh run /tmp/wvp-test/my-video
```

**期望**：5 步子任务 #2 写稿 + agent 任务清单（让 agent 写 `script.md` + `outline.md`）。

### 4.2 写稿（手动或让 agent 写）

如果 agent 没自动写，手动：

```bash
# 写 script.md（按 SCRIPT-STYLE.md 风格，≥ 2 个 --- 节拍）
cat > /tmp/wvp-test/my-video/script.md <<'SCRIPT'
# 稿子

燕子去了，有再来的时候；杨柳枯了，有再青的时候。
---
但是，聪明的，你告诉我，我们的日子为什么一去不复返呢？
---
像针尖上一滴水滴在大海里，我的日子滴在时间的流里，没有声音，也没有影子。
---
我不禁头涔涔而泪潸潸了。
---
SCRIPT

# 写 outline.md（按 OUTLINE-FORMAT.md 风格）
cat > /tmp/wvp-test/my-video/outline.md <<'OUTLINE'
# Outline
## 信息池
- 燕子
- 时间
- 日子
## 场景卡
- 主场景：书房
- 物件：燕子
- 在场角色：叙述者
## 摘句池
- "燕子去了"
- "一去不复返"
OUTLINE
```

### 4.3 第二次 run：跑 selftest + judge

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh run /tmp/wvp-test/my-video
```

**期望**：
- `▸ 5 层自检` → `5/5 通过`
- `▸ 8 维度评分` → `总分 ≥ 0.80`
- `✓ 快照: phase-P1-xxxxxxxx.tar.gz`  ← **自动写 P1 快照**
- `state.phase` 自动从 P0 → **P1**

**验证**：
```bash
cat /tmp/wvp-test/my-video/.book-video/state.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(f'phase={d[\"phase\"]} status={d[\"phase_status\"]}')"
# 期望: phase=P1 status=done
```

### 4.4 第三次 run：跑 pipeline

```bash
# 真实跑 pipeline（不是 dry-run）
# 这一步会调真实的 TTS / image API（如未配 key 会失败，先跑 --dry-run 看清单）
bash skills/web-video-presentation/scripts/chapter-to-video.sh pipeline /tmp/wvp-test/my-video --dry-run
# 期望: 列出 4 步（extract-narrations / synthesize-audio / extract-images / synthesize-images）

# 真跑（需要先有 presentation/src/chapters/<id>/narrations.ts + images.ts）
# 测试时可跳过此步，本手册以 mock 收尾
```

**如果跑通**：
- `state.phase` 自动从 P1 → **P2**
- 自动写 `phase-P2-xxxxxxxx.tar.gz` 快照

### 4.5 第四次 run：提示录屏

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh run /tmp/wvp-test/my-video
```

**期望**：
```
✓ 5 步子任务 #4 完成

下一步：跑 /chapter-to-video-record 启动录屏。
  - cd my-video/presentation && npm run dev
  - 浏览器开 http://localhost:5173/?auto=1
  - QuickTime 录屏
```

---

## 5. 步 3 · status（看完整进度）

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh status /tmp/wvp-test/my-video
```

**期望**：
```
📊 4 步剧本
  [✓] plan   [✓] run   [·] status   [·] record

📊 5 步子任务
  ✓ 1. init             (phase=P1/P2, status=done)
  ✓ 2. 写稿
  ✓ 3. 验收
  ✓ 4. 多媒体           (if pipeline ran)
  ▱ 5. 录屏

📦 快照: 2-3 个
    • phase-P2-xxx.tar.gz
    • phase-P1-xxx.tar.gz
    • phase-P0-xxx.tar.gz
```

---

## 6. 步 4 · record（录屏）

**Cursor 入口**：Cmd+I → `/chapter-to-video-record` → agent 给录屏 4 步指引
**bash 等价**：

```bash
cd /tmp/wvp-test/my-video/presentation
npm install        # 首次
npm run dev
# 浏览器新开: http://localhost:5173/?auto=1
# macOS: Cmd+Shift+5 → 选浏览器窗口录制
# 录完: QuickTime → 文件 → 导出为 → 1080p
```

---

## 7. 回退测试（关键！）

回退是核心卖点。跑一遍验证：

### 7.1 列快照

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh snapshots /tmp/wvp-test/my-video
```

**期望**：
```
▸ 快照列表 · /tmp/wvp-test/my-video
  • P0   phase-P0-xxx.tar.gz  (24K)
  • P1   phase-P1-xxx.tar.gz  (25K)  (if pipeline 跑过)
  ...
```

### 7.2 手动造点改动（模拟"走错了"）

```bash
echo "垃圾改动，应该被回退" >> /tmp/wvp-test/my-video/script.md
# 改 state.json 假装"进了 P2"
python3 -c "
import json
p = '/tmp/wvp-test/my-video/.book-video/state.json'
d = json.load(open(p))
d['phase'] = 'P2'
d['phase_status'] = 'junk'
json.dump(d, open(p,'w'), ensure_ascii=False, indent=2)
"
```

### 7.3 回到 P0

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback /tmp/wvp-test/my-video --to=P0 --yes
```

**期望**：
```
⚠ 即将从快照恢复 ...
✓ 回退完成 · 当前 phase = P0
  下一步：chapter-to-video.sh run ...
```

**验证**：
```bash
cat /tmp/wvp-test/my-video/.book-video/state.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(f'phase={d[\"phase\"]} status={d[\"phase_status\"]}')"
# 期望: phase=P0 status=rolled_back
tail -3 /tmp/wvp-test/my-video/script.md
# 期望: 没有"垃圾改动"那一行
```

### 7.4 回到 P1（如果跑过 selftest）

```bash
bash skills/web-video-presentation/scripts/chapter-to-video.sh rollback /tmp/wvp-test/my-video --to=P1 --yes
# 期望: phase=P1 status=rolled_back
```

---

## 8. 三 IDE 切换测试

| 测试 | 命令 | 期望 |
|---|---|---|
| Cursor 打开 garden-skills | Cmd+I → `/chapter-to-video-plan` | agent 跑 status |
| Cursor 打开其他项目 | 同上 | 走 `~/.cursor/commands/chapter-to-video.md` (router)，调 bash 可能因路径失败 |
| Codex 桌面（任何项目） | Cmd+I → `/chapter-to-video-plan` | 走 `~/.codex/prompts/` symlink → 仓库命令 |
| Claude Code（任何项目） | Cmd+I → `/chapter-to-video-plan` | 走 `~/.claude/commands/` symlink → 仓库命令 |

**注意**：非 garden-skills 项目调命令时，相对路径 `skills/web-video-presentation/...` 会失败。需要在仓库根跑，或命令文件改成绝对路径。

---

## 9. 自动化测试（可选）

```bash
# 跑 5 个核心测试
cd /Users/shixiaocai/Desktop/chuangye/garden-skills
for t in test-cursor-4-commands test-cursor-command test-cursor-command-subcommands \
         test-run-subcommand test-snapshot-rollback; do
  echo "── $t ──"
  bash skills/web-video-presentation/tests/${t}.sh 2>&1 | tail -1
done
```

**期望**：5 个测试全 ✓（共 134 个断言）。

---

## 10. 问题排查

| 症状 | 原因 | 修法 |
|---|---|---|
| `mmx CLI not found` | 没装 mmx | `npm install -g mmx-cli && mmx auth login --api-key <key>` |
| `OPENAI_API_KEY not set` | env 没设 | `export OPENAI_API_KEY=sk-...` 或换 minimax provider |
| 4 步命令在 Cursor 不出现 | 项目级 `.cursor/commands/` 没扫 | `Cmd+Shift+P` → Reload Window |
| 4 步命令在 Codex/Claude 不出现 | prompt/command 没建 | 检查 symlink，IDE Reload |
| `✗ target 已存在` | 之前 init 过同名目录 | 加 `--resume` 或换 `--out=` |
| selftest 第 3 层不过 | script.md 节拍不够 | 加 `---` 分隔（≥ 2 个） |
| selftest 第 1 层不过 | 信息保留度 < 60% | 扩写 script.md 覆盖 article.md 内容 |
| pipeline 调真 npm 报错 | PRESENTATION_TTS/IMG 没装/没 key | 跑 `--dry-run` 看清单；或装 mmx + login |

---

## 11. 验收清单

跑完上面 1-7 步后，能 ✓ 所有项 = 4 步剧本 + 回退全工作：

- [ ] init 写 article.md / STATE.md / meta.json / presentation/
- [ ] init 自动写 P0 快照
- [ ] plan 显示 4 步 + 5 步 + 1 快照
- [ ] run #1（无 script）输出"提示写稿"
- [ ] run #2（有 script）跑 selftest+judge，**自动推 P1 + 写 P1 快照**
- [ ] status 显示 2 步剧本 ✓ + 4 步子任务 ✓
- [ ] run #3 跑 pipeline（真跑或 dry-run）→ **推 P2 + 写 P2 快照**
- [ ] run #4 提示录屏
- [ ] snapshots 列出 2-3 个
- [ ] rollback --to=P0 把 state 改回 P0 + phase_status=rolled_back
- [ ] 三 IDE 都识别 4 步命令（reload 后）
- [ ] 5 个测试 134/134 全过

---

## 附：文件位置速查

| 类别 | 路径 |
|---|---|
| 仓库 | `/Users/shixiaocai/Desktop/chuangye/garden-skills/` |
| Skill | `skills/web-video-presentation/` |
| 4 命令文件 | `.cursor/commands/chapter-to-video-{plan,run,status,record}.md` |
| 主脚本 | `skills/web-video-presentation/scripts/chapter-to-video.sh` |
| Sub-scripts | `skills/web-video-presentation/scripts/commands/{run,snapshot,rollback,snapshots,selftest,judge,status,pipeline,continue,memory,brief,profile}.sh` |
| 快照 helper | `skills/web-video-presentation/scripts/commands/_snapshot.sh` |
| 状态文件 | `my-video/.book-video/state.json` |
| 快照目录 | `my-video/.book-video/snapshots/` |
| Claude symlink | `~/.claude/skills/web-video-presentation` + `~/.claude/commands/chapter-to-video-*.md` |
| Codex symlink | `~/.codex/skills/web-video-presentation/` (副本) + `~/.codex/prompts/chapter-to-video-*.md` |
| Cursor symlink | `~/.agents/skills/web-video-presentation` + 项目级 `.cursor/commands/` |
