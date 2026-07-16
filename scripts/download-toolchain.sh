#!/bin/bash
#
# Download Linaro GCC 6.3.1 toolchains for Rockchip U-Boot compilation.
#
# Usage:
#   ./scripts/download-toolchain.sh              # download both
#   ./scripts/download-toolchain.sh --aarch64    # aarch64 only
#   ./scripts/download-toolchain.sh --arm        # arm32 only
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/prebuilts"

AARCH64_URL="https://developer.arm.com/-/cdn-downloads/permalink/legacy-linaro-gnu-toolchains/6.3-2017.05/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu.tar.xz"
ARM_URL="https://developer.arm.com/-/cdn-downloads/permalink/legacy-linaro-gnu-toolchains/6.3-2017.05/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz"

AARCH64_FILE="gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu.tar.xz"
ARM_FILE="gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz"

# Expected MD5 checksums (verified from downloaded files)
AARCH64_MD5="75fbddfdfe9cd6a38947357ff3a35776"
ARM_MD5="ea9ba26cfc0aaf0a1d307083f64e2fa9"

DOWNLOAD_AARCH64=true
DOWNLOAD_ARM=true

case "${1:-}" in
    --aarch64)
        DOWNLOAD_ARM=false
        ;;
    --arm)
        DOWNLOAD_AARCH64=false
        ;;
esac

verify_md5() {
    local file="$1"
    local expected="$2"

    local actual
    actual=$(md5sum "$ROOT_DIR/$file" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then
        return 0
    else
        log_error "MD5 mismatch for $file"
        log_info "  expected: $expected"
        log_info "  actual:   $actual"
        return 1
    fi
}

download() {
    local url="$1"
    local file="$2"
    local expected_md5="$3"

    # File exists: verify MD5, skip download if matched
    if [ -f "$ROOT_DIR/$file" ]; then
        if verify_md5 "$file" "$expected_md5"; then
            log_ok "$file already exists (MD5 verified), skip download"
            echo
            return
        else
            log_warn "$file exists but MD5 mismatch, re-downloading..."
            rm -f "$ROOT_DIR/$file"
        fi
    fi

    log_step "Downloading $file"
    if wget -c "$url" -O "$ROOT_DIR/$file"; then
        if verify_md5 "$file" "$expected_md5"; then
            log_ok "$file downloaded and verified"
        else
            log_error "Downloaded $file but MD5 verification failed — file may be corrupted"
            exit 1
        fi
    else
        log_error "Failed to download $file"
        exit 1
    fi
    echo
}

log_banner "Download Linaro GCC 6.3.1 Toolchains"
log_info "Target dir: $ROOT_DIR"
echo

mkdir -p "$ROOT_DIR"

if [ "$DOWNLOAD_AARCH64" = true ]; then
    download "$AARCH64_URL" "$AARCH64_FILE" "$AARCH64_MD5"
fi

if [ "$DOWNLOAD_ARM" = true ]; then
    download "$ARM_URL" "$ARM_FILE" "$ARM_MD5"
fi

log_ok "Done."
