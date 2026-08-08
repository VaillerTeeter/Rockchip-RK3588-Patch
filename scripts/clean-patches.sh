#!/bin/bash
# 清理 apply-patches.sh 合入到目标工程的所有文件。
#
# 用法：
#   bash clean-patches.sh <TARGET_ROOT>
#
# 参数：
#   TARGET_ROOT  目标工程根目录（必填），如 U-Boot 或 Android 源码目录
#
# 配套脚本：
#   apply-patches.sh  将补丁合入指定目标工程目录

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PATCHES_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------- 参数检查 ----------
if [[ $# -lt 1 ]]; then
    log_error "未指定目标工程目录"
    echo "        用法: bash clean-patches.sh <TARGET_ROOT>"
    exit 1
fi

TARGET_ROOT="${1%/}"

log_banner "Rockchip-RK3588-Patch 补丁清理脚本"
log_info "目标目录: $TARGET_ROOT"
echo ""

# ---------- 目录校验 ----------
if [[ ! -d "$TARGET_ROOT" ]]; then
    log_error "目标目录不存在: $TARGET_ROOT"
    exit 1
fi

init_steps 16

# ============================================================
# 清理步骤
# 与 apply-patches.sh 的合入步骤一一对应，按正向顺序执行。
# 每个补丁块内部用 clean_resources 完成 remove / revert。
# ============================================================

# ---------- 补丁 1：build.sh / rk_build_common.sh ----------
step "build.sh / rk_build_common.sh / rk_build_impl.sh — 删除"

BUILD_DST="$TARGET_ROOT/build.sh"
COMMON_DST="$TARGET_ROOT/rk_build_common.sh"
BUILD_IMPL_DST="$TARGET_ROOT/rk_build_impl.sh"
FILTER_DST="$TARGET_ROOT/filter-build-log.py"
GEN_MISC_DST="$TARGET_ROOT/gen-misc-img.py"

clean_resources                                 \
    --remove                                    \
        "$BUILD_DST"      "build.sh"            \
        "$COMMON_DST"     "rk_build_common.sh"  \
        "$BUILD_IMPL_DST" "rk_build_impl.sh"    \
        "$FILTER_DST"     "filter-build-log.py" \
        "$GEN_MISC_DST"   "gen-misc-img.py"

# ---------- 补丁 2：u-boot ----------
step "u-boot — 删除"

UBOOT_DST_DIR="$TARGET_ROOT/u-boot"

clean_resources \
    --remove "$UBOOT_DST_DIR" "u-boot"

# ---------- 补丁 3：rkbin ----------
step "rkbin — 删除"

RKBIN_DST_DIR="$TARGET_ROOT/rkbin"

clean_resources \
    --remove "$RKBIN_DST_DIR" "rkbin"

# ---------- 补丁 4：GCC 工具链 ----------
step "GCC 工具链 — 删除"

AARCH64_DIR="$TARGET_ROOT/prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu"
ARM_DIR="$TARGET_ROOT/prebuilts/gcc/linux-x86/arm/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf"

clean_resources                  \
    --remove                     \
        "$AARCH64_DIR" "aarch64" \
        "$ARM_DIR"     "arm32"

# ---------- 补丁 5：rk-kernel-5.10 ----------
step "rk-kernel-5.10 — 删除"

KERNEL_DST_DIR="$TARGET_ROOT/kernel-5.10"

clean_resources \
    --remove "$KERNEL_DST_DIR" "kernel-5.10"

# ---------- 补丁 6：bionic ----------
step "bionic — 回滚补丁"

BIONIC_DST_DIR="$TARGET_ROOT/bionic"
BIONIC_PATCH_DIR="$PATCHES_ROOT/patches/bionic"

clean_resources \
    --revert "$BIONIC_PATCH_DIR" "$BIONIC_DST_DIR" "bionic"

# ---------- 补丁 7：bootable/recovery ----------
step "bootable/recovery — 回滚补丁 + 删除 RK 专有目录"

BOOTABLE_DST_DIR="$TARGET_ROOT/bootable/recovery"
BOOTABLE_PATCH_DIR="$PATCHES_ROOT/patches/bootable/recovery"

clean_resources                                                       \
    --revert                                                          \
        "$BOOTABLE_PATCH_DIR" "$BOOTABLE_DST_DIR" "bootable/recovery" \
    --remove                                                          \
        "$BOOTABLE_DST_DIR/mtdutils"  "bootable/recovery/mtdutils"    \
        "$BOOTABLE_DST_DIR/pcba_core" "bootable/recovery/pcba_core"   \
        "$BOOTABLE_DST_DIR/rkupdate"  "bootable/recovery/rkupdate"    \
        "$BOOTABLE_DST_DIR/rkutility" "bootable/recovery/rkutility"

# ---------- 补丁 8：build ----------
step "build/make, build/soong — 回滚补丁"

BUILD_MAKE_DIR="$TARGET_ROOT/build/make"
BUILD_SOONG_DIR="$TARGET_ROOT/build/soong"
BUILD_PATCH_DIR="$PATCHES_ROOT/patches/build"

clean_resources                                                  \
    --revert                                                     \
        "$BUILD_PATCH_DIR/make"  "$BUILD_MAKE_DIR"  "build/make" \
        "$BUILD_PATCH_DIR/soong" "$BUILD_SOONG_DIR" "build/soong"

# ---------- 补丁 9：external ----------
step "external — 回滚补丁 + 删除 RK 专有目录"

EXT_PATCH_DIR="$PATCHES_ROOT/patches/external"
EXT_DST="$TARGET_ROOT/external"

clean_resources                                                                                   \
    --revert                                                                                      \
        "$EXT_PATCH_DIR/e2fsprogs"        "$EXT_DST/e2fsprogs"        "external/e2fsprogs"        \
        "$EXT_PATCH_DIR/iperf3"           "$EXT_DST/iperf3"           "external/iperf3"           \
        "$EXT_PATCH_DIR/libdrm"           "$EXT_DST/libdrm"           "external/libdrm"           \
        "$EXT_PATCH_DIR/skia"             "$EXT_DST/skia"             "external/skia"             \
        "$EXT_PATCH_DIR/speex"            "$EXT_DST/speex"            "external/speex"            \
        "$EXT_PATCH_DIR/tinyalsa"         "$EXT_DST/tinyalsa"         "external/tinyalsa"         \
        "$EXT_PATCH_DIR/wpa_supplicant_8" "$EXT_DST/wpa_supplicant_8" "external/wpa_supplicant_8" \
    --remove                                                                                      \
        "$EXT_DST/camera_engine_rkaiq"          "external/camera_engine_rkaiq"                    \
        "$EXT_DST/can-utils"                    "external/can-utils"                              \
        "$EXT_DST/e2fsprogs/lib/blkid/libiconv" "external/e2fsprogs/lib/blkid/libiconv"           \
        "$EXT_DST/io"                           "external/io"                                     \
        "$EXT_DST/libdrm/rockchip"              "external/libdrm/rockchip"                        \
        "$EXT_DST/ntfs-3g"                      "external/ntfs-3g"                                \
        "$EXT_DST/rk_tee_user"                  "external/rk_tee_user"                            \
        "$EXT_DST/wifi_driver"                  "external/wifi_driver"

# ---------- 补丁 10：device/rockchip ----------
step "device/rockchip — 删除"

clean_resources \
    --remove "$TARGET_ROOT/device/rockchip" "device/rockchip"

# ---------- 补丁 11：frameworks ----------
step "frameworks — 回滚补丁 + 删除 RK 专有文件"

FW_PATCH_DIR="$PATCHES_ROOT/patches/frameworks"
FW_DST="$TARGET_ROOT/frameworks"
FW_AV_SF="$FW_DST/av/media/libstagefright"
FW_BASE_JNI="$FW_DST/base/services/core/jni"
FW_BASE_SVR="$FW_DST/base/services/core/java/com/android/server"
FW_BASE_OS="$FW_DST/base/core/java/android/os"
FW_BASE_ETC="$FW_DST/base/data/etc"
FW_BASE_MEDIA="$FW_DST/base/media/java/android/media"
FW_NATIVE_SF="$FW_DST/native/services/surfaceflinger"
FW_NATIVE_MAPPER="$FW_DST/native/services/inputflinger/reader/mapper"
FW_NATIVE_RENDER="$FW_DST/native/libs/renderengine"
FW_OPT_WIFI="$FW_DST/opt/net/wifi/libwifi_hal"
FW_OPT_WIFI_INC="$FW_OPT_WIFI/include/hardware_legacy"

clean_resources                                                                                                      \
    --revert                                                                                                         \
        "$FW_PATCH_DIR/av"            "$FW_DST/av"            "frameworks/av"                                      \
        "$FW_PATCH_DIR/base"          "$FW_DST/base"          "frameworks/base"                                    \
        "$FW_PATCH_DIR/ex"            "$FW_DST/ex"            "frameworks/ex"                                      \
        "$FW_PATCH_DIR/native"        "$FW_DST/native"        "frameworks/native"                                  \
        "$FW_PATCH_DIR/opt/net/wifi"  "$FW_DST/opt/net/wifi"  "frameworks/opt/net/wifi"                            \
        "$FW_PATCH_DIR/opt/telephony" "$FW_DST/opt/telephony" "frameworks/opt/telephony"                           \
    --remove                                                                                                         \
        "$FW_AV_SF/wifi-display"                                       "av/wifi-display"                             \
        "$FW_BASE_JNI/com_android_server_rkdisplay_RkDisplayModes.cpp" "base/RkDisplayModes.cpp"                     \
        "$FW_BASE_JNI/com_android_server_audio_RkAudioSetting.cpp"     "base/RkAudioSetting.cpp"                     \
        "$FW_BASE_JNI/com_android_server_RKBoxService.cpp"             "base/RKBoxService.cpp"                       \
        "$FW_BASE_JNI/rkbox"                                           "base/rkbox"                                  \
        "$FW_BASE_SVR/RKBoxManagementService.java"                     "base/RKBoxManagementService.java"            \
        "$FW_BASE_SVR/RkDisplayDeviceManagementService.java"           "base/RkDisplayDeviceManagementService.java"  \
        "$FW_BASE_SVR/rkdisplay"                                       "base/rkdisplay"                              \
        "$FW_BASE_SVR/audio/RkAudioSettingService.java"                "base/RkAudioSettingService.java"             \
        "$FW_BASE_SVR/audio/RkAudioSetting.java"                       "base/RkAudioSetting.java"                    \
        "$FW_BASE_SVR/pm/PackagePerformanceSetting.java"               "base/PackagePerformanceSetting.java"         \
        "$FW_BASE_ETC/wakeup-alarmalign-whitelist.xml"                 "base/wakeup-alarmalign-whitelist.xml"        \
        "$FW_BASE_MEDIA/AudioStream.java"                              "base/AudioStream.java"                       \
        "$FW_BASE_OS/RkDisplayOutputManager.java"                      "base/RkDisplayOutputManager.java"            \
        "$FW_BASE_OS/IRKBoxManagementService.aidl"                     "base/IRKBoxManagementService.aidl"           \
        "$FW_BASE_OS/IRkDisplayDeviceManagementService.aidl"           "base/IRkDisplayDeviceManagementService.aidl" \
        "$FW_BASE_OS/audio"                                            "base/audio"                                  \
        "$FW_NATIVE_MAPPER/KeyMouseInputMapper.h"                      "native/KeyMouseInputMapper.h"                \
        "$FW_NATIVE_MAPPER/KeyMouseInputMapper.cpp"                    "native/KeyMouseInputMapper.cpp"              \
        "$FW_NATIVE_SF/CompositionEngine/Android.go"                   "native/CompositionEngine/Android.go"         \
        "$FW_NATIVE_SF/Android.go"                                     "native/surfaceflinger/Android.go"            \
        "$FW_NATIVE_RENDER/Android.go"                                 "native/renderengine/Android.go"              \
        "$FW_OPT_WIFI_INC/rk_wifi.h"                                   "opt/rk_wifi.h"                               \
        "$FW_OPT_WIFI/rk_wifi_ctrl.cpp"                                "opt/rk_wifi_ctrl.cpp"

# ---------- 补丁 12：hardware ----------
step "hardware — 回滚补丁 + 删除 RK 专有目录"

HW_PATCH_DIR="$PATCHES_ROOT/patches/hardware"
HW_DST="$TARGET_ROOT/hardware"
HW_RIL_LIB="$HW_DST/ril/libril"
HW_BT_INC="$HW_DST/broadcom/libbt/include"
HW_IF="$HW_DST/interfaces"
HW_IF_CAM_PROV="$HW_IF/camera/provider/2.4/default"
HW_IF_CAM_DEV="$HW_IF/camera/device/3.4/default"
HW_IF_CAM_DEV_INC="$HW_IF_CAM_DEV/include"
HW_IF_CAM_DEV_IMPL="$HW_IF_CAM_DEV_INC/ext_device_v3_4_impl"
HW_IF_AUDIO_DEF="$HW_IF/audio/core/all-versions/default"

clean_resources                                                                                                        \
    --revert                                                                                                           \
        "$HW_PATCH_DIR/ril"            "$HW_DST/ril"            "hardware/ril"                                         \
        "$HW_PATCH_DIR/broadcom/libbt" "$HW_DST/broadcom/libbt" "hardware/broadcom/libbt"                              \
        "$HW_PATCH_DIR/broadcom/wlan"  "$HW_DST/broadcom/wlan"  "hardware/broadcom/wlan"                               \
        "$HW_PATCH_DIR/libhardware"    "$HW_DST/libhardware"    "hardware/libhardware"                                 \
        "$HW_PATCH_DIR/interfaces"     "$HW_DST/interfaces"     "hardware/interfaces"                                  \
    --remove                                                                                                           \
        "$HW_RIL_LIB/lib64"                                         "ril/lib64"                                        \
        "$HW_RIL_LIB/lib32"                                         "ril/lib32"                                        \
        "$HW_IF_CAM_PROV/DeviceV4L2Event.h"                         "interfaces/DeviceV4L2Event.h"                     \
        "$HW_IF_CAM_PROV/DeviceV4L2Event.cpp"                       "interfaces/DeviceV4L2Event.cpp"                   \
        "$HW_IF_CAM_DEV/subvideo.cpp"                               "interfaces/subvideo.cpp"                          \
        "$HW_IF_CAM_DEV/rkvpu_dec_api.cpp"                          "interfaces/rkvpu_dec_api.cpp"                     \
        "$HW_IF_CAM_DEV/osd.cpp"                                    "interfaces/osd.cpp"                               \
        "$HW_IF_CAM_DEV_INC/vpu_inc"                                "interfaces/vpu_inc"                               \
        "$HW_IF_CAM_DEV_IMPL/subvideo.h"                            "interfaces/subvideo.h"                            \
        "$HW_IF_CAM_DEV_IMPL/rkvpu_dec_api.h"                       "interfaces/rkvpu_dec_api.h"                       \
        "$HW_IF_CAM_DEV_IMPL/osd.h"                                 "interfaces/osd.h"                                 \
        "$HW_IF_CAM_DEV_IMPL/RgaCropScale.h"                        "interfaces/RgaCropScale.h"                        \
        "$HW_IF_CAM_DEV_IMPL/ExternalFakeCameraDevice_3_4.h"        "interfaces/ExternalFakeCameraDevice_3_4.h"        \
        "$HW_IF_CAM_DEV_IMPL/ExternalFakeCameraDeviceSession_3.4.h" "interfaces/ExternalFakeCameraDeviceSession_3.4.h" \
        "$HW_IF_CAM_DEV_IMPL/ExternalCameraUtils_3.4.h"             "interfaces/ExternalCameraUtils_3.4.h"             \
        "$HW_IF_CAM_DEV_IMPL/ExternalCameraMemManager.h"            "interfaces/ExternalCameraMemManager.h"            \
        "$HW_IF_CAM_DEV_IMPL/ExternalCameraGralloc4.h"              "interfaces/ExternalCameraGralloc4.h"              \
        "$HW_IF_CAM_DEV_IMPL/ExternalCameraGralloc.h"               "interfaces/ExternalCameraGralloc.h"               \
        "$HW_IF_CAM_DEV_IMPL/ExternalCameraDeviceSession_3.4.h"     "interfaces/ExternalCameraDeviceSession_3.4.h"     \
        "$HW_IF_CAM_DEV/RgaCropScale.cpp"                           "interfaces/RgaCropScale.cpp"                      \
        "$HW_IF_CAM_DEV/ExternalFakeCameraDeviceSession.cpp"        "interfaces/ExternalFakeCameraDeviceSession.cpp"   \
        "$HW_IF_CAM_DEV/ExternalFakeCameraDevice.cpp"               "interfaces/ExternalFakeCameraDevice.cpp"          \
        "$HW_IF_CAM_DEV/ExternalCameraMemManager.cpp"               "interfaces/ExternalCameraMemManager.cpp"          \
        "$HW_IF_CAM_DEV/ExternalCameraGralloc4.cpp"                 "interfaces/ExternalCameraGralloc4.cpp"            \
        "$HW_IF_CAM_DEV/ExternalCameraGralloc.cpp"                  "interfaces/ExternalCameraGralloc.cpp"             \
        "$HW_IF_AUDIO_DEF/Android.go"                               "interfaces/audio/Android.go"                      \
        "$HW_BT_INC/vnd_rksdk.txt"                                  "broadcom/vnd_rksdk.txt"                           \
        "$HW_DST/rockchip"                                          "rockchip"                                         \
        "$HW_DST/realtek"                                           "realtek"                                          \
        "$HW_DST/bes"                                               "bes"                                              \
        "$HW_DST/aic"                                               "aic"

# ---------- 补丁 13：system ----------
step "system — 回滚补丁 + 删除 RK 专有文件"

SYS_PATCH_DIR="$PATCHES_ROOT/patches/system"
SYS_DST="$TARGET_ROOT/system"
SYS_VOLD_FS="$SYS_DST/vold/fs"

clean_resources \
    --revert \
        "$SYS_PATCH_DIR/core"   "$SYS_DST/core"   "system/core"   \
        "$SYS_PATCH_DIR/extras" "$SYS_DST/extras" "system/extras" \
        "$SYS_PATCH_DIR/media"  "$SYS_DST/media"  "system/media"  \
        "$SYS_PATCH_DIR/vold"   "$SYS_DST/vold"   "system/vold"   \
    --remove \
        "$SYS_VOLD_FS/Ntfs.cpp" "vold/Ntfs.cpp" \
        "$SYS_VOLD_FS/Ntfs.h"   "vold/Ntfs.h"

# ---------- 补丁 14：packages ----------
step "packages — 回滚补丁 + 删除 RK 专有 APP + 清理散落文件"

PKG_PATCH_DIR="$PATCHES_ROOT/patches/packages"
PKG_DST="$TARGET_ROOT/packages"
PKG_APPS="$PKG_DST/apps"

clean_resources                                                                                                          \
    --revert                                                                                                             \
        "$PKG_PATCH_DIR/apps/Calendar"            "$PKG_DST/apps/Calendar"            "packages/apps/Calendar"           \
        "$PKG_PATCH_DIR/apps/Camera2"             "$PKG_DST/apps/Camera2"             "packages/apps/Camera2"            \
        "$PKG_PATCH_DIR/apps/Gallery2"            "$PKG_DST/apps/Gallery2"            "packages/apps/Gallery2"           \
        "$PKG_PATCH_DIR/apps/KeyChain"            "$PKG_DST/apps/KeyChain"            "packages/apps/KeyChain"           \
        "$PKG_PATCH_DIR/apps/Music"               "$PKG_DST/apps/Music"               "packages/apps/Music"              \
        "$PKG_PATCH_DIR/apps/Settings"            "$PKG_DST/apps/Settings"            "packages/apps/Settings"           \
        "$PKG_PATCH_DIR/apps/TV"                  "$PKG_DST/apps/TV"                  "packages/apps/TV"                 \
        "$PKG_PATCH_DIR/apps/TvSettings"          "$PKG_DST/apps/TvSettings"          "packages/apps/TvSettings"         \
        "$PKG_PATCH_DIR/providers/MediaProvider"  "$PKG_DST/providers/MediaProvider"  "packages/providers/MediaProvider" \
        "$PKG_PATCH_DIR/services/Telecomm"        "$PKG_DST/services/Telecomm"        "packages/services/Telecomm"       \
        "$PKG_PATCH_DIR/modules/Bluetooth"        "$PKG_DST/modules/Bluetooth"        "packages/modules/Bluetooth"       \
        "$PKG_PATCH_DIR/modules/Connectivity"     "$PKG_DST/modules/Connectivity"     "packages/modules/Connectivity"    \
        "$PKG_PATCH_DIR/modules/Wifi"             "$PKG_DST/modules/Wifi"             "packages/modules/Wifi"            \
    --remove                                                                                                             \
        "$PKG_APPS/DisplayAdjust"   "apps/DisplayAdjust"                                                                 \
        "$PKG_APPS/ExactCalculator" "apps/ExactCalculator"                                                               \
        "$PKG_APPS/SoundRecorder"   "apps/SoundRecorder"                                                                 \
        "$PKG_APPS/rkCamera2"       "apps/rkCamera2"

# 清理 tarball 注入到 7 个 AOSP 仓库内的散落文件（git untracked）
for _repo in                   \
    "$PKG_DST/apps/Camera2"    \
    "$PKG_DST/apps/Gallery2"   \
    "$PKG_DST/apps/Settings"   \
    "$PKG_DST/apps/TV"         \
    "$PKG_DST/apps/Music"      \
    "$PKG_DST/apps/TvSettings" \
    "$PKG_DST/modules/Bluetooth"; do
    if [[ -d "$_repo/.git" ]]; then
        (cd "$_repo" && git clean -fd -q)
        log_ok "    git clean: packages/$(echo "$_repo" | sed 's|.*/packages/||')"
    fi
done

# ---------- 补丁 15：vendor ----------
step "vendor — 删除"

clean_resources \
    --remove "$TARGET_ROOT/vendor" "vendor"

# ---------- 补丁 16：Launcher ----------
step "CarHeadunitLauncher — 删除"

LAUNCHER_DST_DIR="$TARGET_ROOT/packages/apps/CarHeadunitLauncher"

clean_resources \
    --remove "$LAUNCHER_DST_DIR" "CarHeadunitLaunchert"

echo ""
log_banner "清理完成"
