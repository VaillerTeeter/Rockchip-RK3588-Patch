#!/bin/bash
# 将 Rockchip-RK3588-Patch 仓库中的补丁合入目标工程。
#
# 用法：
#   bash apply-patches.sh <TARGET_ROOT>
#
# 参数：
#   TARGET_ROOT  目标工程根目录（必填），如 U-Boot 或 Android 源码目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PATCHES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------- 参数检查 ----------
if [[ $# -lt 1 ]]; then
    log_error "未指定目标工程目录"
    echo "        用法: bash apply-patches.sh <TARGET_ROOT>"
    exit 1
fi

TARGET_ROOT="${1%/}"

log_banner "Rockchip-RK3588-Patch 补丁合入脚本"
log_info "仓库目录: $PATCHES_ROOT"
log_info "目标目录: $TARGET_ROOT"
echo ""

# ---------- 目录校验 ----------
if [[ ! -d "$TARGET_ROOT" ]]; then
    log_error "目标目录不存在: $TARGET_ROOT"
    exit 1
fi

init_steps 15

# ============================================================
# 补丁合入步骤
# 使用 step "描述" 输出统一的 "[序号/TOTAL] 描述" 日志。
# 每个补丁块内部用 apply_resources 完成 copy / patch / extract。
# ============================================================

# ---------- 补丁 1：build.sh / rk_build_common.sh ----------
step "build.sh / rk_build_common.sh — 复制"

BUILD_SRC="$PATCHES_ROOT/scripts/build.sh"
BUILD_DST="$TARGET_ROOT/build.sh"
COMMON_SRC="$PATCHES_ROOT/scripts/common.sh"
COMMON_DST="$TARGET_ROOT/rk_build_common.sh"

apply_resources \
    --copy \
        "$BUILD_SRC"  "$BUILD_DST"  "build.sh" \
        "$COMMON_SRC" "$COMMON_DST" "rk_build_common.sh"

# ---------- 补丁 2：u-boot ----------
step "u-boot — 复制 + 打补丁"

UBOOT_SRC_DIR="$PATCHES_ROOT/u-boot"
UBOOT_DST_DIR="$TARGET_ROOT/u-boot"
UBOOT_PATCH_DIR="$PATCHES_ROOT/patches/u-boot"

apply_resources \
    --copy  "$UBOOT_SRC_DIR"   "$UBOOT_DST_DIR" "u-boot" \
    --patch "$UBOOT_PATCH_DIR" "$UBOOT_DST_DIR" "u-boot" "$UBOOT_SRC_DIR"

# ---------- 补丁 3：rkbin ----------
step "rkbin — 复制"

RKBIN_SRC_DIR="$PATCHES_ROOT/rkbin"
RKBIN_DST_DIR="$TARGET_ROOT/rkbin"

apply_resources \
    --copy "$RKBIN_SRC_DIR" "$RKBIN_DST_DIR" "rkbin"

# ---------- 补丁 4：GCC 工具链 ----------
step "GCC 工具链 — 解压"

AARCH64_TAR="$PATCHES_ROOT/prebuilts/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu.tar.xz"
ARM_TAR="$PATCHES_ROOT/prebuilts/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz"
AARCH64_PARENT_DIR="$TARGET_ROOT/prebuilts/gcc/linux-x86/aarch64"
ARM_PARENT_DIR="$TARGET_ROOT/prebuilts/gcc/linux-x86/arm"

# 确保 tarball 已下载
if [ ! -f "$AARCH64_TAR" ] || [ ! -f "$ARM_TAR" ]; then
    log_info "工具链 tarball 未就绪，执行 ./scripts/download-toolchain.sh ..."
    "$PATCHES_ROOT/scripts/download-toolchain.sh"
fi

# 创建父目录
mkdir -p "$AARCH64_PARENT_DIR" "$ARM_PARENT_DIR"

# 幂等检查：工具链解压后目录名与 tarball 同名（去后缀）
AARCH64_TAR_DIR="${AARCH64_TAR%.tar.xz}"
AARCH64_TAR_DIR="${AARCH64_TAR_DIR##*/}"
ARM_TAR_DIR="${ARM_TAR%.tar.xz}"
ARM_TAR_DIR="${ARM_TAR_DIR##*/}"

if [[ -d "$AARCH64_PARENT_DIR/$AARCH64_TAR_DIR" ]] && [[ -d "$ARM_PARENT_DIR/$ARM_TAR_DIR" ]]; then
    log_warn "GCC 工具链 已解压，跳过"
elif [[ -d "$AARCH64_PARENT_DIR/$AARCH64_TAR_DIR" ]]; then
    log_warn "aarch64 工具链 已解压，跳过"
    apply_resources --extract "$ARM_TAR" "$ARM_PARENT_DIR" "arm32 工具链"
elif [[ -d "$ARM_PARENT_DIR/$ARM_TAR_DIR" ]]; then
    apply_resources --extract "$AARCH64_TAR" "$AARCH64_PARENT_DIR" "aarch64 工具链"
    log_warn "arm32 工具链 已解压，跳过"
else
    apply_resources \
        --extract \
            "$AARCH64_TAR" "$AARCH64_PARENT_DIR" "aarch64 工具链" \
            "$ARM_TAR"     "$ARM_PARENT_DIR"     "arm32 工具链"
fi

# ---------- 补丁 5：rk-kernel-5.10 ----------
step "rk-kernel-5.10 — 复制 + 打补丁"

KERNEL_SRC_DIR="$PATCHES_ROOT/rk-kernel-5.10"
KERNEL_DST_DIR="$TARGET_ROOT/rk-kernel-5.10"
KERNEL_PATCH_DIR="$PATCHES_ROOT/patches/kernel"

apply_resources \
    --copy  "$KERNEL_SRC_DIR"   "$KERNEL_DST_DIR" "rk-kernel-5.10" \
    --patch "$KERNEL_PATCH_DIR" "$KERNEL_DST_DIR" "kernel" "$KERNEL_SRC_DIR"

# ---------- 补丁 6：bionic ----------
step "bionic — 打补丁"

BIONIC_DST_DIR="$TARGET_ROOT/bionic"
BIONIC_PATCH_DIR="$PATCHES_ROOT/patches/bionic"

apply_resources \
    --patch "$BIONIC_PATCH_DIR" "$BIONIC_DST_DIR" "bionic"

# ---------- 补丁 7：bootable/recovery ----------
step "bootable/recovery — 打补丁 + 解压"

BOOTABLE_DST_DIR="$TARGET_ROOT/bootable/recovery"
BOOTABLE_PATCH_DIR="$PATCHES_ROOT/patches/bootable/recovery"
BOOTABLE_RK_TAR="$PATCHES_ROOT/patches/bootable/rk3588-recovery-rk-dirs.tar.gz"

apply_resources \
    --patch   "$BOOTABLE_PATCH_DIR" "$BOOTABLE_DST_DIR" "bootable/recovery" \
    --extract "$BOOTABLE_RK_TAR"    "$BOOTABLE_DST_DIR" "bootable/recovery RK 专有目录"

# ---------- 补丁 8：build ----------
step "build/make, build/soong — 打补丁"

BUILD_MAKE_DIR="$TARGET_ROOT/build/make"
BUILD_SOONG_DIR="$TARGET_ROOT/build/soong"
BUILD_PATCH_DIR="$PATCHES_ROOT/patches/build"

apply_resources \
    --patch \
        "$BUILD_PATCH_DIR/make"  "$BUILD_MAKE_DIR"  "build/make" \
        "$BUILD_PATCH_DIR/soong" "$BUILD_SOONG_DIR" "build/soong"

# ---------- 补丁 9：external ----------
step "external — 打补丁 + 解压"

EXT_PATCH_DIR="$PATCHES_ROOT/patches/external"
EXT_DST="$TARGET_ROOT/external"
EXT_RK_TAR="$EXT_PATCH_DIR/rk3588-external-rk-dirs.tar.gz"

apply_resources \
    --patch \
        "$EXT_PATCH_DIR/e2fsprogs"        "$EXT_DST/e2fsprogs"        "external/e2fsprogs" \
        "$EXT_PATCH_DIR/iperf3"           "$EXT_DST/iperf3"           "external/iperf3" \
        "$EXT_PATCH_DIR/libdrm"           "$EXT_DST/libdrm"           "external/libdrm" \
        "$EXT_PATCH_DIR/skia"             "$EXT_DST/skia"             "external/skia" \
        "$EXT_PATCH_DIR/speex"            "$EXT_DST/speex"            "external/speex" \
        "$EXT_PATCH_DIR/tinyalsa"         "$EXT_DST/tinyalsa"         "external/tinyalsa" \
        "$EXT_PATCH_DIR/wpa_supplicant_8" "$EXT_DST/wpa_supplicant_8" "external/wpa_supplicant_8" \
    --extract \
        "$EXT_RK_TAR"                     "$TARGET_ROOT"              "external RK 专有目录"

# ---------- 补丁 10：device/rockchip ----------
step "device/rockchip — 解压"

DEV_RK_TAR="$PATCHES_ROOT/patches/device/rk3588-device-rk-dirs.tar.gz"

apply_resources \
    --extract "$DEV_RK_TAR" "$TARGET_ROOT" "device/rockchip"

# ---------- 补丁 11：frameworks ----------
step "frameworks — 打补丁 + 解压"

FW_PATCH_DIR="$PATCHES_ROOT/patches/frameworks"
FW_DST="$TARGET_ROOT/frameworks"
FW_RK_TAR="$FW_PATCH_DIR/rk3588-frameworks-rk-files.tar.gz"

apply_resources \
    --patch \
        "$FW_PATCH_DIR/av"            "$FW_DST/av"            "frameworks/av" \
        "$FW_PATCH_DIR/base"          "$FW_DST/base"          "frameworks/base" \
        "$FW_PATCH_DIR/ex"            "$FW_DST/ex"            "frameworks/ex" \
        "$FW_PATCH_DIR/native"        "$FW_DST/native"        "frameworks/native" \
        "$FW_PATCH_DIR/opt/net/wifi"  "$FW_DST/opt/net/wifi"  "frameworks/opt/net/wifi" \
        "$FW_PATCH_DIR/opt/telephony" "$FW_DST/opt/telephony" "frameworks/opt/telephony" \
    --extract \
        "$FW_RK_TAR"                  "$FW_DST"               "frameworks RK 专有文件"

# ---------- 补丁 12：hardware ----------
step "hardware — 打补丁 + 解压"

HW_PATCH_DIR="$PATCHES_ROOT/patches/hardware"
HW_DST="$TARGET_ROOT/hardware"
HW_RK_TAR="$HW_PATCH_DIR/rk3588-hardware-rk-files.tar.gz"

apply_resources \
    --patch \
        "$HW_PATCH_DIR/ril"            "$HW_DST/ril"            "hardware/ril" \
        "$HW_PATCH_DIR/broadcom/libbt" "$HW_DST/broadcom/libbt" "hardware/broadcom/libbt" \
        "$HW_PATCH_DIR/broadcom/wlan"  "$HW_DST/broadcom/wlan"  "hardware/broadcom/wlan" \
        "$HW_PATCH_DIR/libhardware"    "$HW_DST/libhardware"    "hardware/libhardware" \
        "$HW_PATCH_DIR/interfaces"     "$HW_DST/interfaces"     "hardware/interfaces" \
    --extract \
        "$HW_RK_TAR"                   "$HW_DST"                "hardware RK 专有目录"

# ---------- 补丁 13：system ----------
step "system — 打补丁 + 解压"

SYS_PATCH_DIR="$PATCHES_ROOT/patches/system"
SYS_DST="$TARGET_ROOT/system"
SYS_RK_TAR="$SYS_PATCH_DIR/rk3588-system-rk-files.tar.gz"

apply_resources \
    --patch \
        "$SYS_PATCH_DIR/core"   "$SYS_DST/core"   "system/core" \
        "$SYS_PATCH_DIR/extras" "$SYS_DST/extras" "system/extras" \
        "$SYS_PATCH_DIR/media"  "$SYS_DST/media"  "system/media" \
        "$SYS_PATCH_DIR/vold"   "$SYS_DST/vold"   "system/vold" \
    --extract \
        "$SYS_RK_TAR"           "$TARGET_ROOT"    "system RK 专有文件"

# ---------- 补丁 14：packages ----------
step "packages — 打补丁 + 解压"

PKG_PATCH_DIR="$PATCHES_ROOT/patches/packages"
PKG_DST="$TARGET_ROOT/packages"
PKG_RK_TAR="$PKG_PATCH_DIR/rk3588-packages-rk-files.tar.gz"

apply_resources \
    --patch \
        "$PKG_PATCH_DIR/apps/Calendar"           "$PKG_DST/apps/Calendar"           "packages/apps/Calendar" \
        "$PKG_PATCH_DIR/apps/Camera2"            "$PKG_DST/apps/Camera2"            "packages/apps/Camera2" \
        "$PKG_PATCH_DIR/apps/Gallery2"           "$PKG_DST/apps/Gallery2"           "packages/apps/Gallery2" \
        "$PKG_PATCH_DIR/apps/KeyChain"           "$PKG_DST/apps/KeyChain"           "packages/apps/KeyChain" \
        "$PKG_PATCH_DIR/apps/Music"              "$PKG_DST/apps/Music"              "packages/apps/Music" \
        "$PKG_PATCH_DIR/apps/Settings"           "$PKG_DST/apps/Settings"           "packages/apps/Settings" \
        "$PKG_PATCH_DIR/apps/TV"                 "$PKG_DST/apps/TV"                 "packages/apps/TV" \
        "$PKG_PATCH_DIR/apps/TvSettings"         "$PKG_DST/apps/TvSettings"         "packages/apps/TvSettings" \
        "$PKG_PATCH_DIR/providers/MediaProvider" "$PKG_DST/providers/MediaProvider" "packages/providers/MediaProvider" \
        "$PKG_PATCH_DIR/services/Telecomm"       "$PKG_DST/services/Telecomm"       "packages/services/Telecomm" \
        "$PKG_PATCH_DIR/modules/Bluetooth"       "$PKG_DST/modules/Bluetooth"       "packages/modules/Bluetooth" \
        "$PKG_PATCH_DIR/modules/Connectivity"    "$PKG_DST/modules/Connectivity"    "packages/modules/Connectivity" \
        "$PKG_PATCH_DIR/modules/Wifi"            "$PKG_DST/modules/Wifi"            "packages/modules/Wifi" \
    --extract \
        "$PKG_RK_TAR"                            "$TARGET_ROOT"                     "packages RK 专有文件"

# ---------- 补丁 15：vendor ----------
step "vendor — 解压"

VENDOR_PATCH_DIR="$PATCHES_ROOT/patches/vendor"
VENDOR_TAR="$VENDOR_PATCH_DIR/rk3588-vendor.tar.gz"

apply_resources \
    --extract "$VENDOR_TAR" "$TARGET_ROOT" "vendor"

echo ""
log_banner "所有补丁已处理完成"
