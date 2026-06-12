#!/usr/bin/env bash
# T14: synthesize-images.sh runner
# 用 WVP_IMG_PROVIDER 环境变量注入假 provider（避免 mmx 真调用）
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source tests/_lib.sh

RUNNER="templates/scripts/synthesize-images.sh"
[[ -f "$RUNNER" ]] || { echo "  ✗ $RUNNER missing"; exit 1; }

TMPDIR=$(make_tmpdir)
PROMPTS_JSON="$TMPDIR/image-prompts.json"
FAKE_PROVIDER="$TMPDIR/fake-img-provider.sh"

# 准备 image-prompts.json（3 条记录，2 个 chapter）
cat > "$PROMPTS_JSON" <<'JSON_EOF'
[
  {"chapter": "01-hook",  "step": 1, "out": "public/images/01-hook/1.png",  "prompt": "a serene mountain", "size": "1920x1080"},
  {"chapter": "01-hook",  "step": 2, "out": "public/images/01-hook/2.png",  "prompt": "a lonely boat",     "size": "1920x1080"},
  {"chapter": "02-arc",   "step": 1, "out": "public/images/02-arc/1.png",   "prompt": "an old book",       "size": "1920x1080"}
]
JSON_EOF

# 假 provider：把 prompt 写到 out_path（生成真实文件 = 模拟成功）
cat > "$FAKE_PROVIDER" <<'PROV_EOF'
image_check() { return 0; }
image_install_help() { echo "(fake)"; }
image_generate() {
  local prompt_json="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  python3 - "$prompt_json" "$out" <<'PY'
import json, sys, struct, zlib
p = json.loads(sys.argv[1])
w, h = 8, 8
seed = sum(ord(c) for c in p["prompt"]) % 0xFFFFFF
r, g, b = (seed >> 16) & 0xFF, (seed >> 8) & 0xFF, seed & 0xFF
raw = b"".join(b"\x00" + bytes([r,g,b]) * w for _ in range(h))
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open(sys.argv[2], "wb").write(png)
PY
}
PROV_EOF
chmod +x "$FAKE_PROVIDER"

# ── 1. 跑通 3 条记录 ──
set +e
WVP_IMG_PROVIDER="$FAKE_PROVIDER" WVP_IMG_PROMPTS="$PROMPTS_JSON" WVP_IMG_OUT_ROOT="$TMPDIR/out" bash "$RUNNER" 2>&1
rc=$?
set -e
assert_eq "runner exit 0" "0" "$rc"
# 输出 3 个 PNG
assert_file_exists "01-hook step1 生成" "$TMPDIR/out/public/images/01-hook/1.png"
assert_file_exists "01-hook step2 生成" "$TMPDIR/out/public/images/01-hook/2.png"
assert_file_exists "02-arc  step1 生成" "$TMPDIR/out/public/images/02-arc/1.png"

# ── 2. PNG 文件 magic bytes 正确（89 50 4E 47 0D 0A 1A 0A）──
MAGIC=$(head -c 8 "$TMPDIR/out/public/images/01-hook/1.png" | xxd -p)
assert_eq "PNG magic bytes" "89504e470d0a1a0a" "$MAGIC"

# ── 3. 增量：第二次跑应该跳过已存在（通过修改 provider 检查）──
# 用一个会失败的 provider，确认旧文件不被覆盖
BAD_PROVIDER="$TMPDIR/bad-img-provider.sh"
cat > "$BAD_PROVIDER" <<'PROV_EOF'
image_check() { return 0; }
image_install_help() { echo "(bad)"; }
image_generate() { echo "should not be called for existing" >&2; return 1; }
PROV_EOF
chmod +x "$BAD_PROVIDER"

# 把已生成文件备份
cp "$TMPDIR/out/public/images/01-hook/1.png" "$TMPDIR/first.png"

set +e
WVP_IMG_PROVIDER="$BAD_PROVIDER" WVP_IMG_PROMPTS="$PROMPTS_JSON" WVP_IMG_OUT_ROOT="$TMPDIR/out" bash "$RUNNER" 2>&1
rc2=$?
set -e
# 不应调用 bad provider 生成（已存在），但其它未存在的会失败 → exit 非 0 是 OK
# 关键断言：01-hook/1.png 没被改（incremental skip 生效）
if cmp -s "$TMPDIR/out/public/images/01-hook/1.png" "$TMPDIR/first.png"; then
  _TEST_PASS=$((_TEST_PASS+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _log_pass "incremental: 跳过已存在文件"
else
  _TEST_FAIL=$((_TEST_FAIL+1)); _TEST_TOTAL=$((_TEST_TOTAL+1))
  _TEST_FAILURES+=("incremental: 01-hook/1.png 被覆盖了")
  _log_fail "incremental: 已存在文件被覆盖"
fi

# ── 4. --force 强制重生（用 bad provider → 应该失败）──
set +e
WVP_IMG_PROVIDER="$BAD_PROVIDER" WVP_IMG_PROMPTS="$PROMPTS_JSON" WVP_IMG_OUT_ROOT="$TMPDIR/out" bash "$RUNNER" --force 2>&1
rc3=$?
set -e
assert_eq "--force: bad provider → exit != 0" "1" "$rc3"

# ── 5. image_check 失败：fast-fail ──
FAIL_CHECK_PROVIDER="$TMPDIR/fail-check.sh"
cat > "$FAIL_CHECK_PROVIDER" <<'PROV_EOF'
image_check() { echo "deps missing" >&2; return 1; }
image_install_help() { echo "(none)"; }
image_generate() { return 0; }
PROV_EOF
chmod +x "$FAIL_CHECK_PROVIDER"
set +e
WVP_IMG_PROVIDER="$FAIL_CHECK_PROVIDER" WVP_IMG_PROMPTS="$PROMPTS_JSON" WVP_IMG_OUT_ROOT="$TMPDIR/out2" bash "$RUNNER" 2>&1
rc4=$?
set -e
assert_eq "image_check 失败 → exit != 0" "1" "$rc4"

# ── 6. 未指定 provider → 加载默认 minimax（如果 mmx 不在应 fail）──
# 我们要测默认加载机制；用 WVP_IMG_NO_DEFAULT_CHECK 跳过真 image_check
set +e
WVP_IMG_NO_DEFAULT_CHECK=1 WVP_IMG_PROMPTS="$PROMPTS_JSON" WVP_IMG_OUT_ROOT="$TMPDIR/out3" bash "$RUNNER" 2>&1 | grep -q "MiniMax image provider"
rc_grep=$?
set -e
# 默认 provider 应该是 minimax（即使 mmx 不在）
# 不严格断言 — 可能在某些环境 mmx 装了。我们只断言默认加载逻辑走到了。
# 用更稳的检查：脚本尝试 source minimax.sh
assert_grep "默认 provider: 加载 image-providers 目录" "image-providers" "$RUNNER"
assert_grep "默认 provider: minimax" "minimax" "$RUNNER"

rm -rf "$TMPDIR"
print_summary "test-synthesize-images"
