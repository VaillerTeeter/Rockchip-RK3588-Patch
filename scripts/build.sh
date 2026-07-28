#!/bin/bash
# Build script for Rockchip-RK3588-Patch
#
# Usage:
#   ./scripts/build.sh <targets> [-C] [-I] [-L] [-h]
#
# Targets (one or more required):
#   -U    Build U-Boot (with SPL 3-step packaging)
#   -K    Build kernel (rk-kernel-5.10)
#   -A    Build Android (make -j)
#
# Options:
#   -L    Save full build log to build.log (via tee, terminal output preserved)
#   -C    Clean rebuild (distclean/clean before build)
#   -I    Collect partition images to Image/ (mkimage)
#   -h    Show help

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/rk_build_common.sh"
source "$SCRIPT_DIR/rk_build_impl.sh"

usage() {
    cat <<EOF
用法: $(basename "$0") <targets> [-C] [-I] [-L] [-h]

编译目标（至少指定一个）:
  -U    编译 U-Boot（含 SPL 三步打包流程）
  -K    编译内核 (rk-kernel-5.10)
  -A    整编 Android（make -j）

选项:
  -L    将完整编译日志保存到 build.log（终端同步输出）
  -C    全量重编（编译前先 make distclean / make clean）
  -I    收集分区镜像到 Image/ 目录（可独立运行，仅执行 mkimage）
  -h    显示此帮助信息
EOF
}

BUILD_UBOOT=0
BUILD_KERNEL=0
BUILD_ANDROID=0
BUILD_MKIMAGE=0
BUILD_CLEAN=0
BUILD_LOG=0

while getopts ":UKAILCh" opt; do
    case $opt in
        U) BUILD_UBOOT=1 ;;
        K) BUILD_KERNEL=1 ;;
        A) BUILD_ANDROID=1 ;;
        I) BUILD_MKIMAGE=1 ;;
        L) BUILD_LOG=1 ;;
        C) BUILD_CLEAN=1 ;;
        h) usage; exit 0 ;;
        \?) log_error "未知选项 -${OPTARG}"; usage; exit 1 ;;
    esac
done

if [[ $BUILD_UBOOT -eq 0 && $BUILD_KERNEL -eq 0 && $BUILD_ANDROID -eq 0 && $BUILD_MKIMAGE -eq 0 ]]; then
    log_error "请指定 -U、-K、-A 编译目标，或 -I 收集镜像"
    usage
    exit 1
fi

# build.sh 由 apply-patches.sh 复制到 Android 工程根目录，SCRIPT_DIR 即为工程根。
ANDROID_ROOT="$SCRIPT_DIR"
LOG_DIR="$ANDROID_ROOT/logs"

# ---------- 日志过滤规则列表（build.log 不显示命中的行）----------
# 每行一个 grep -E 正则，可自行增减
BUILD_LOG_FILTERS=(
    # 通用
    '^\s*✓'
    '^═{10,}'
    '^={10,}'
    '^\s*检查编译环境依赖'
    '^\s*环境检查完成'
    '^\s*加载 Android 编译工具链'
    '^\s*整编 Android'
    # clean
    '^\s*(CLEAN)'
    '^\s*(rm -f)'
    # Kernel
    '^\s*(WRAP|pwd:|MODINFO|MODPOST|UPD|EXTRACT_CERTS|VDSOSYM|MKELF|CC|AS|HOSTCC|CC32|LD|SHIPPED|CR|AR|LDS|OBJCOPY|MUNGE|LD32|KSYMS|CHK|GEN|GZIP|ASN|LZ4C|SYSMAP|SORTTAB|SYNC|LEX|DTC|YACC|HOSTLD|CALL)'
    # Android
    '^\[.*% [0-9]+/[0-9]+\]'
    '^\s*clang: warning: argument unused during compilation:'
    '^\s*In file included from'
    'Should not run fetchAllInformation on host'
    '^\s*no declaration found for ELF symbol with id'
    '^\s*conflicting definitions found for type'
)

# ---------- 日志重定向（-L 选项：终端同步全量输出，logs/build_raw.log 完整日志，logs/build.log 过滤编译进度行）----------
if [[ $BUILD_LOG -eq 1 ]]; then
    mkdir -p "$LOG_DIR"
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' | tee "$LOG_DIR/build_raw.log" | grep --line-buffered -v -E "$(IFS='|'; echo "${BUILD_LOG_FILTERS[*]}")" > "$LOG_DIR/build.log")) 2>&1
fi

# ---------- 环境检查（统一入口，所有依赖检查集中在此）----------
check_build_deps

# 验证当前目录是否为 Android 工程根
if [[ ! -f "$ANDROID_ROOT/build/envsetup.sh" ]]; then
    log_error "未找到 build/envsetup.sh，请确认 build.sh 已由 apply-patches.sh 放置在 Android 13 工程根目录"
    log_error "当前路径: $ANDROID_ROOT"
    exit 1
fi
log_ok "Android 工程根目录: $ANDROID_ROOT"

# ---------- 加载 Android 编译工具链（envsetup + lunch）----------
log_banner "加载 Android 编译工具链"
source build/envsetup.sh
lunch ATK_DLRK3588-userdebug || { log_error "lunch ATK_DLRK3588-userdebug 失败"; exit 1; }
log_ok "lunch 环境已就绪（ATK_DLRK3588-userdebug）"

# ---------- 编译 U-Boot ----------
if [[ $BUILD_UBOOT -eq 1 ]]; then
    do_build_uboot
    log_info "U-Boot 编译产物:"
    ls -lh *.img *_loader_*.bin 2>/dev/null || true
    cd "$SCRIPT_DIR"
    log_banner "U-Boot 编译完成 ✓"
fi

# ---------- 编译内核 ----------
if [[ $BUILD_KERNEL -eq 1 ]]; then
    do_build_kernel

    # ---- [boot] 合成 boot.img ----
    log_step "[boot] make bootimage..."
    cd "$ANDROID_ROOT"
    run_cmd "make bootimage"     make bootimage
    run_cmd "make recoveryimage" make recoveryimage
    log_info "boot/recovery 产物:"
    ls -lh "${OUT}"/boot.img "${OUT}"/recovery.img "${OUT}"/dtbo.img "${OUT}"/rebuild-dtbo.img 2>/dev/null || true

    cd "$SCRIPT_DIR"
    log_banner "内核编译完成 ✓"
fi

# ---------- 整编 Android ----------
if [[ $BUILD_ANDROID -eq 1 ]]; then
    do_build_android
    # TODO: 镜像列表可能不准，需后续整编实验确认
    log_info "Android 编译产物:"
    ls -lh "${OUT}"/system.img "${OUT}"/vendor.img "${OUT}"/product.img "${OUT}"/system_ext.img "${OUT}"/super.img "${OUT}"/userdata.img 2>/dev/null || true
    cd "$SCRIPT_DIR"
    log_banner "Android 整编完成 ✓"
fi

# ---------- 整理产物到 Image 目录 ----------
if [[ $BUILD_MKIMAGE -eq 1 ]]; then
    do_mkimage
fi

# ---------- 提取 warning/error 日志（-L 模式：按模块分类输出到 logs/）----------
if [[ $BUILD_LOG -eq 1 ]]; then
    FILTER_BIN="$ANDROID_ROOT/filter-build-log.py"
    if [[ -f "$FILTER_BIN" && -f "$LOG_DIR/build.log" ]]; then
        log_banner "提取 warning/error 日志"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "external/can-utils"                                 --cut > "$LOG_DIR/01-warnings-can-utils1.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "external/ntfs-3g"                                   --cut > "$LOG_DIR/02-warnings-ntfs-3g.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "dalvik/tools/hprof-conv"                            --cut > "$LOG_DIR/03-warnings-hprof-conv.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/tools/aapt"                         --cut > "$LOG_DIR/04-warnings-aapt.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "external/camera_engine_rkaiq"                       --cut > "$LOG_DIR/05-warnings-camera_engine_rkaiq.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/audio/tinyalsa_hal"               --cut > "$LOG_DIR/06-warnings-tinyalsa_hal.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/drmservice"                       --cut > "$LOG_DIR/07-warnings-drmservice.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "packages/modules/Bluetooth"                         --cut > "$LOG_DIR/08-warnings-Bluetooth.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/realtek/rtkbt"                             --cut > "$LOG_DIR/09-warnings-rtkbt.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "external/e2fsprogs/lib/blkid"                       --cut > "$LOG_DIR/10-warnings-blkid.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "packages/apps/Gallery2"                             --cut > "$LOG_DIR/11-warnings-Gallery2.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "packages/inputmethods/LatinIME"                     --cut > "$LOG_DIR/12-warnings-LatinIME.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/media/mtp"                            --cut > "$LOG_DIR/13-warnings-mtp.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "bootable/recovery/rkutility"                        --cut > "$LOG_DIR/14-warnings-rkutility.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "bootable/recovery/rkupdate"                         --cut > "$LOG_DIR/15-warnings-rkupdate.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/media/libstagefright"                 --cut > "$LOG_DIR/16-warnings-libstagefright.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/compile/libbcc/bcinfo"                   --cut > "$LOG_DIR/17-warnings-bcinfo.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/drm"                                  --cut > "$LOG_DIR/18-warnings-drm.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/tools/incident_report"              --cut > "$LOG_DIR/19-warnings-incident_report.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/compile/slang"                           --cut > "$LOG_DIR/20-warnings-slang.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/power_aidl"                       --cut > "$LOG_DIR/21-warnings-power_aidl.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "system/gsid"                                        --cut > "$LOG_DIR/22-warnings-gsid.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/native/cmds"                             --cut > "$LOG_DIR/23-warnings-cmds.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/camera_vir"                       --cut > "$LOG_DIR/24-warnings-camera_vir.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/media"                                --cut > "$LOG_DIR/25-warnings-media.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "external/tensorflow"                                --cut > "$LOG_DIR/26-warnings-tensorflow.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/librga"                           --cut > "$LOG_DIR/27-warnings-librga.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/interfaces/camera"                         --cut > "$LOG_DIR/28-warnings-interfaces-camera.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "vendor/rockchip/hardware/interfaces/neuralnetworks" --cut > "$LOG_DIR/29-warnings-neuralnetworks.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/libhardware/modules/audio_remote_submix"   --cut > "$LOG_DIR/30-warnings-audio_remote_submix.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "art/libartbase"                                     --cut > "$LOG_DIR/31-warnings-libartbase.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/services/audioflinger"                --cut > "$LOG_DIR/32-warnings-audioflinger.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/cmds/bootanimation"                 --cut > "$LOG_DIR/33-warnings-bootanimation.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/core/jni"                           --cut > "$LOG_DIR/34-warnings-core-jni.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/av/camera"                               --cut > "$LOG_DIR/35-warnings-av-camera.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/native/services/inputflinger"            --cut > "$LOG_DIR/36-warnings-inputflinger.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/media/jni"                          --cut > "$LOG_DIR/37-warnings-media-jni.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/opt/net"                                 --cut > "$LOG_DIR/38-warnings-net.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/wilhelm"                                 --cut > "$LOG_DIR/39-warnings-wilhelm.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "bootable/recovery/pcba_core"                        --cut > "$LOG_DIR/40-warnings-pcba_core.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "bootable/recovery"                                  --cut > "$LOG_DIR/41-warnings-recovery.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/cmds/incidentd"                     --cut > "$LOG_DIR/42-warnings-incidentd.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "hardware/rockchip/camera"                           --cut > "$LOG_DIR/43-warnings-rockchip-camera.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "system/nfc"                                         --cut > "$LOG_DIR/44-warnings-nfc.txt"
        python3 "$FILTER_BIN" "$LOG_DIR/build.log" "frameworks/base/services/core/jni"                  --cut > "$LOG_DIR/45-warnings-core-jni.txt"
        sed -n "\|^${ANDROID_ROOT}/out/soong/\.temp|,+2p"                     "$LOG_DIR/build.log"            > "$LOG_DIR/46-warnings-soong-temp.txt"
        sed -i "\|^${ANDROID_ROOT}/out/soong/\.temp|,+2d"                     "$LOG_DIR/build.log"
        sed -n '/applying IT instruction to more than one/,+2p'               "$LOG_DIR/build.log"            > "$LOG_DIR/47-warnings-applying-IT.txt"
        sed -i '/applying IT instruction to more than one/,+2d'               "$LOG_DIR/build.log"
        sed -n '/declared with a const-qualified typedef/,+5p'                "$LOG_DIR/build.log"            > "$LOG_DIR/48-warnings-const-qualified-typedef.txt"
        sed -i '/declared with a const-qualified typedef/,+5d'                "$LOG_DIR/build.log"
        sed -n '/do not use namespace/,+2p'                                   "$LOG_DIR/build.log"            > "$LOG_DIR/49-warnings-donot-use-namespace.txt"
        sed -i '/do not use namespace/,+2d'                                   "$LOG_DIR/build.log"
        sed -n '/comparing object representation of type/,+2p'                "$LOG_DIR/build.log"            > "$LOG_DIR/50-warnings-bugprone-suspicious-memory-comparison.txt"
        sed -i '/comparing object representation of type/,+2d'                "$LOG_DIR/build.log"
        sed -n '/does not handle self-assignment properly/,+2p'               "$LOG_DIR/build.log"            > "$LOG_DIR/51-warnings-doesnot-handle-self-assignment-properly.txt"
        sed -i '/does not handle self-assignment properly/,+2d'               "$LOG_DIR/build.log"
        awk -v root="${ANDROID_ROOT}" '
        $0 ~ ("^" root "/frameworks/base/cmds") {
            if (in_block) { print saved; saved = "" }
            in_block = 1; saved = $0; next
        }
        in_block {
            if ($0 ~ ("^" root "/")) {
                print saved; saved = ""; in_block = 0
                print $0; next
            }
            saved = saved "\n" $0; next
        }
        END { if (in_block) print saved }
        ' "$LOG_DIR/build.log" > "$LOG_DIR/52-warnings-frameworks-base-cmds.txt"
        awk -v root="${ANDROID_ROOT}" -i inplace '
        $0 ~ ("^" root "/frameworks/base/cmds") {
            in_block = 1; next
        }
        in_block {
            if ($0 ~ ("^" root "/")) { in_block = 0 }
            else                     { next }
        }
        { print }
        ' "$LOG_DIR/build.log"
        sed -n "\|^frameworks/base/cmds|,+2p"                                 "$LOG_DIR/build.log"            > "$LOG_DIR/53-warnings-frameworks-base-cmds-2.txt"
        sed -i "\|^frameworks/base/cmds|,+2d"                                 "$LOG_DIR/build.log"
        awk -v root="${ANDROID_ROOT}" '
        $0 ~ ("^" root "/out/soong/\\.intermediates") {
            if (in_block) { print saved; saved = "" }
            in_block = 1; saved = $0; next
        }
        in_block {
            if ($0 ~ ("^" root "/")) {
                print saved; saved = ""; in_block = 0
                print $0; next
            }
            saved = saved "\n" $0; next
        }
        END { if (in_block) print saved }
        ' "$LOG_DIR/build.log" > "$LOG_DIR/54-warnings-soong-intermediates.txt"
        awk -v root="${ANDROID_ROOT}" -i inplace '
        $0 ~ ("^" root "/out/soong/\\.intermediates") {
            in_block = 1; next
        }
        in_block {
            if ($0 ~ ("^" root "/")) { in_block = 0 }
            else                     { next }
        }
        { print }
        ' "$LOG_DIR/build.log"
        sed -n "\|^${ANDROID_ROOT}/frameworks/base/services/incremental|,+2p" "$LOG_DIR/build.log"            > "$LOG_DIR/55-warnings-incremental.txt"
        sed -i "\|^${ANDROID_ROOT}/frameworks/base/services/incremental|,+2d" "$LOG_DIR/build.log"
        sed -n "\|^${ANDROID_ROOT}/system/incremental_delivery|,+2p"          "$LOG_DIR/build.log"            > "$LOG_DIR/56-warnings-incremental_delivery.txt"
        sed -i "\|^${ANDROID_ROOT}/system/incremental_delivery|,+2d"          "$LOG_DIR/build.log"
        sed -n "\|^${ANDROID_ROOT}/system/vold/BenchmarkGen|,+3p"             "$LOG_DIR/build.log"            > "$LOG_DIR/57-warnings-BenchmarkGen.txt"
        sed -i "\|^${ANDROID_ROOT}/system/vold/BenchmarkGen|,+3d"             "$LOG_DIR/build.log"
        sed -n '/without required default value/,+0p'                         "$LOG_DIR/build.log"            > "$LOG_DIR/58-warnings-without-required-default-value.txt"
        sed -i '/without required default value/,+0d'                         "$LOG_DIR/build.log"
        sed -n '/parsing started/,+0p'                                        "$LOG_DIR/build.log"            > "$LOG_DIR/59-warnings-parsing-started.txt"
        sed -i '/parsing started/,+0d'                                        "$LOG_DIR/build.log"
        sed -n '/parsing completed/,+0p'                                      "$LOG_DIR/build.log"            > "$LOG_DIR/60-warnings-parsing-completed.txt"
        sed -i '/parsing completed/,+0d'                                      "$LOG_DIR/build.log"
        sed -n '/loading \/modules/,+0p'                                      "$LOG_DIR/build.log"            > "$LOG_DIR/61-warnings-loading-modules.txt"
        sed -i '/loading \/modules/,+0d'                                      "$LOG_DIR/build.log"
        sed -n '/loading \/home/,+0p'                                         "$LOG_DIR/build.log"            > "$LOG_DIR/62-warnings-loading-home.txt"
        sed -i '/loading \/home/,+0d'                                         "$LOG_DIR/build.log"
        sed -n '/checking com/,+0p'                                           "$LOG_DIR/build.log"            > "$LOG_DIR/63-warnings-checking-com.txt"
        sed -i '/checking com/,+0d'                                           "$LOG_DIR/build.log"
        sed -n '/wrote out/,+0p'                                              "$LOG_DIR/build.log"            > "$LOG_DIR/64-warnings-wrote-out.txt"
        sed -i '/wrote out/,+0d'                                              "$LOG_DIR/build.log"
        sed -n '/external\/kotlinx\.coroutines/,+2p'                          "$LOG_DIR/build.log"            > "$LOG_DIR/65-warnings-kotlinx.coroutines.txt"
        sed -i '/external\/kotlinx\.coroutines/,+2d'                          "$LOG_DIR/build.log"
        sed -n '/frameworks\/base\/tools\/processors/,+2p'                    "$LOG_DIR/build.log"            > "$LOG_DIR/66-warnings-processors.txt"
        sed -i '/frameworks\/base\/tools\/processors/,+2d'                    "$LOG_DIR/build.log"
        sed -n "\|^${ANDROID_ROOT}/packages/providers/MediaProvider|,+2p"     "$LOG_DIR/build.log"            > "$LOG_DIR/67-warnings-MediaProvider.txt"
        sed -i "\|^${ANDROID_ROOT}/packages/providers/MediaProvider|,+2d"     "$LOG_DIR/build.log"
        sed -n '/frameworks\/base\/tools\/protologtool/,+2p'                  "$LOG_DIR/build.log"            > "$LOG_DIR/68-warnings-protologtool.txt"
        sed -i '/frameworks\/base\/tools\/protologtool/,+2d'                  "$LOG_DIR/build.log"
        sed -i '/[0-9]\+ warnings\?/,+0d'                                     "$LOG_DIR/build.log"
        sed -n '/Supported source version/,+0p'                               "$LOG_DIR/build.log"            > "$LOG_DIR/69-warnings-Supported-source-version.txt"
        sed -i '/Supported source version/,+0d'                               "$LOG_DIR/build.log"
        sed -n '/packages\/apps\/Calendar/,+2p'                               "$LOG_DIR/build.log"            > "$LOG_DIR/70-warnings-Calendar.txt"
        sed -i '/packages\/apps\/Calendar/,+2d'                               "$LOG_DIR/build.log"
        sed -n '/external\/okio/,+2p'                                         "$LOG_DIR/build.log"            > "$LOG_DIR/71-warnings-okio.txt"
        sed -i '/external\/okio/,+2d'                                         "$LOG_DIR/build.log"
        sed -n '/packages\/apps\/DeskClock/,+2p'                              "$LOG_DIR/build.log"            > "$LOG_DIR/72-warnings-DeskClock.txt"
        sed -i '/packages\/apps\/DeskClock/,+2d'                              "$LOG_DIR/build.log"
        sed -n '/macro replacement list should be enclosed/,+0p'              "$LOG_DIR/build.log"            > "$LOG_DIR/73-warnings-macro-replacement.txt"
        sed -i '/macro replacement list should be enclosed/,+0d'              "$LOG_DIR/build.log"
        sed -n '/unknown enum constant/,+0p'                                  "$LOG_DIR/build.log"            > "$LOG_DIR/74-warnings-unknown-enum-constant.txt"
        sed -i '/unknown enum constant/,+0d'                                  "$LOG_DIR/build.log"
        sed -i '/reason: class file for/,+0d'                                 "$LOG_DIR/build.log"
        sed -n '/external\/libtextclassifier/,+2p'                            "$LOG_DIR/build.log"            > "$LOG_DIR/75-warnings-libtextclassifier.txt"
        sed -i '/external\/libtextclassifier/,+2d'                            "$LOG_DIR/build.log"
        sed -n '/packages\/modules\/Bluetooth/,+2p'                           "$LOG_DIR/build.log"            > "$LOG_DIR/76-warnings-Bluetooth.txt"
        sed -i '/packages\/modules\/Bluetooth/,+2d'                           "$LOG_DIR/build.log"
        sed -n '/frameworks\/base\/packages\/SystemUI/,+2p'                   "$LOG_DIR/build.log"            > "$LOG_DIR/77-warnings-SystemUI.txt"
        sed -i '/frameworks\/base\/packages\/SystemUI/,+2d'                   "$LOG_DIR/build.log"
        sed -n '/^frameworks\/base\/packages\/EasterEgg/,+2p'                 "$LOG_DIR/build.log"            > "$LOG_DIR/78-warnings-EasterEgg.txt"
        sed -i '/^frameworks\/base\/packages\/EasterEgg/,+2d'                 "$LOG_DIR/build.log"
        sed -n '/frameworks\/base\/packages\/StatementService/,+2p'           "$LOG_DIR/build.log"            > "$LOG_DIR/79-warnings-StatementService.txt"
        sed -i '/frameworks\/base\/packages\/StatementService/,+2d'           "$LOG_DIR/build.log"
        sed -n '/Missing class/,+0p'                                          "$LOG_DIR/build.log"            > "$LOG_DIR/80-warnings-Missing-class.txt"
        sed -i '/Missing class/,+0d'                                          "$LOG_DIR/build.log"
        sed -n '/packages\/modules\/IntentResolver/,+2p'                      "$LOG_DIR/build.log"            > "$LOG_DIR/81-warnings-IntentResolver.txt"
        sed -i '/packages\/modules\/IntentResolver/,+2d'                      "$LOG_DIR/build.log"
        sed -n '/frameworks\/libs\/systemui/,+2p'                             "$LOG_DIR/build.log"            > "$LOG_DIR/82-warnings-systemui.txt"
        sed -i '/frameworks\/libs\/systemui/,+2d'                             "$LOG_DIR/build.log"
        sed -n '/packages\/modules\/Permission/,+2p'                          "$LOG_DIR/build.log"            > "$LOG_DIR/83-warnings-Permission.txt"
        sed -i '/packages\/modules\/Permission/,+2d'                          "$LOG_DIR/build.log"
        sed -n '/packages\/apps\/Launcher3/,+2p'                              "$LOG_DIR/build.log"            > "$LOG_DIR/84-warnings-Launcher3.txt"
        sed -i '/packages\/apps\/Launcher3/,+2d'                              "$LOG_DIR/build.log"
        sed -n '/frameworks\/base\/libs\/WindowManager/,+2p'                  "$LOG_DIR/build.log"            > "$LOG_DIR/85-warnings-WindowManager.txt"
        sed -i '/frameworks\/base\/libs\/WindowManager/,+2d'                  "$LOG_DIR/build.log"
        log_ok "warning/error 日志已提取到 $LOG_DIR/"
    fi
fi
