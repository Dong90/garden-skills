# tests/_lib.sh —— 极简 bash test runner
# 用法：source tests/_lib.sh
#   assert_eq "label" "expected" "actual"
#   assert_true "label" "command"
#   assert_contains "label" "needle" "haystack"
#   assert_exit "label" "expected_code" command...
#   assert_file_exists "label" "/path"
#   assert_grep "label" "regex" "/path/to/file"

set -u

# ── 颜色 ──
if [[ -t 1 ]]; then
  _R='\033[0;31m' _G='\033[0;32m' _Y='\033[0;33m' _D='\033[0;90m' _N='\033[0m'
else
  _R='' _G='' _Y='' _D='' _N=''
fi

# ── 计数 ──
_TEST_TOTAL=0
_TEST_PASS=0
_TEST_FAIL=0
_TEST_FAILURES=()

_log_pass() { printf "  \033[0;32m✓\033[0m %s\n" "$1"; }
_log_fail() { printf "  \033[0;31m✗\033[0m %s\n" "$1"; [ -n "${2:-}" ] && printf "      \033[0;90m%s\033[0m\n" "$2"; }
_log_info() { printf "  \033[0;33m…\033[0m %s\n" "$1"; }

# ── 断言 ──
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: expected=[$expected] actual=[$actual]")
    _log_fail "$label" "expected=[$expected] actual=[$actual]"
  fi
}

assert_true() {
  local label="$1"; shift
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: command failed: $*")
    _log_fail "$label" "command failed: $*"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: needle=[$needle] not in haystack")
    _log_fail "$label" "needle=[$needle] not in haystack"
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: needle=[$needle] SHOULD NOT be in haystack")
    _log_fail "$label" "needle=[$needle] SHOULD NOT be in haystack"
  fi
}

assert_exit() {
  local label="$1" expected="$2"; shift 2
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  if [[ "$actual" == "$expected" ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: expected exit=$expected got=$actual")
    _log_fail "$label" "expected exit=$expected got=$actual"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ -f "$path" ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: file not found: $path")
    _log_fail "$label" "file not found: $path"
  fi
}

assert_grep() {
  local label="$1" pattern="$2" path="$3"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ -f "$path" ]] && grep -qE "$pattern" "$path"; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: pattern [$pattern] not found in $path")
    _log_fail "$label" "pattern [$pattern] not found in $path"
  fi
}

# ── 摘要 ──
print_summary() {
  local file="${1:-test}"
  echo
  if [[ $_TEST_FAIL -eq 0 ]]; then
    printf "\033[0;32m✓ %s: %d/%d passed\033[0m\n" "$file" "$_TEST_PASS" "$_TEST_TOTAL"
  else
    printf "\033[0;31m✗ %s: %d/%d passed (%d failed)\033[0m\n" "$file" "$_TEST_PASS" "$_TEST_TOTAL" "$_TEST_FAIL"
    echo "  Failures:"
    for f in "${_TEST_FAILURES[@]}"; do
      printf "    \033[0;31m·\033[0m %s\n" "$f"
    done
  fi
  return "$_TEST_FAIL"
}

# ── 工具：临时目录 ──
make_tmpdir() {
  mktemp -d -t "wvp-test-XXXXXX"
}

# ── 工具：捕获 stdout / stderr / exit code ──
#   run_capture cmd... → sets RUN_OUT RUN_EXIT
run_capture() {
  set +e
  RUN_OUT=$("$@" 2>/dev/null)
  RUN_EXIT=$?
  set -e
}

assert_dir_exists() {
  local label="$1" path="$2"
  _TEST_TOTAL=$((_TEST_TOTAL + 1))
  if [[ -d "$path" ]]; then
    _TEST_PASS=$((_TEST_PASS + 1))
    _log_pass "$label"
  else
    _TEST_FAIL=$((_TEST_FAIL + 1))
    _TEST_FAILURES+=("$label :: dir not found: $path")
    _log_fail "$label" "dir not found: $path"
  fi
}
