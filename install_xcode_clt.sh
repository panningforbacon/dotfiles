#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# install_xcode_clt.sh
# Force-reinstall Xcode Command Line Tools.
# Must be run with sudo.
# ─────────────────────────────────────────────

CLT_DIR="/Library/Developer/CommandLineTools"
CLANG_BIN="${CLT_DIR}/usr/bin/clang"


# ── Preflight ─────────────────────────────────

sudo -n true 2>/dev/null || { echo "ERROR: This script must be run with sudo."; exit 1; }

echo
echo "═══════════════════════════════════════"
echo " Xcode Command Line Tools — Install"
echo "═══════════════════════════════════════"
echo


# ── Remove existing install ───────────────────

skip_install=false

if [[ -d "${CLT_DIR}" ]]; then
    echo "Found existing installation at: ${CLT_DIR}"
    while true; do
        read -rp "Remove and force a version reset? Enter [Y]es, [N]o, or [C]ancel: " choice
        choice="$(echo "${choice}" | tr '[:upper:]' '[:lower:]')"
        case "${choice}" in
            y|yes|"")
                rm -rf "${CLT_DIR}"
                break
                ;;
            n|no)
                skip_install=true
                break
                ;;
            c|cancel)
                echo "Cancelled."
                exit 0
                ;;
            *)
                echo "  → Enter Y, N, or C."
                ;;
        esac
    done
fi


# ── Install ───────────────────────────────────

if [[ "${skip_install}" == false ]]; then
    echo "→ Complete the GUI dialog to continue ...."
    xcode-select --install 2>/dev/null || true

    echo "→ Waiting for installation to complete ..."
    until [[ -d "${CLT_DIR}" ]]; do
        sleep 5
    done
fi


# ── Verify ────────────────────────────────────

[[ -d "${CLT_DIR}" ]]   || { echo "ERROR: Directory not found: ${CLT_DIR}" >&2; exit 1; }
echo "✓ Directory exists : ${CLT_DIR}"

[[ -x "${CLANG_BIN}" ]] || { echo "ERROR: clang not executable at: ${CLANG_BIN}" >&2; exit 1; }
echo "✓ clang accessible : $(${CLANG_BIN} --version | head -1)"


echo
echo "Installation complete."