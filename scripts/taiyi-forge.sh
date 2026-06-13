#!/usr/bin/env bash
# TAIYI-FORGE:PROJECT-WRAPPER v0.23.0 — exec node_modules/oh-my-taiyiforge/scripts/taiyi-forge.sh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_upstream_wrapper() {
  local pkg="${ROOT_DIR}/node_modules/oh-my-taiyiforge/scripts/taiyi-forge.sh"
  if [[ -f "$pkg" ]]; then
    echo "$pkg"
    return 0
  fi
  if [[ -n "${TAIYI_FORGE_ROOT:-}" && -f "${TAIYI_FORGE_ROOT}/scripts/taiyi-forge.sh" ]]; then
    echo "${TAIYI_FORGE_ROOT}/scripts/taiyi-forge.sh"
    return 0
  fi
  if [[ -f "${ROOT_DIR}/.taiyi/forge-root" ]]; then
    local _fr
    _fr="$(tr -d '[:space:]' < "${ROOT_DIR}/.taiyi/forge-root")"
    if [[ -f "${_fr}/scripts/taiyi-forge.sh" ]]; then
      echo "${_fr}/scripts/taiyi-forge.sh"
      return 0
    fi
  fi
  return 1
}

if target="$(resolve_upstream_wrapper)"; then
  exec bash "$target" "$@"
fi

echo "[taiyi-forge] wrapper shim: 未找到 oh-my-taiyiforge — npm install 后重试" >&2
exit 2
