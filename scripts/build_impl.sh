#!/bin/bash
# 编译实现函数 —— 供 build.sh source 引用
#
# 依赖（由 build.sh 在 source 前保证）：
#   - common.sh 已 source（log_*/run_cmd/check_build_deps）
#   - SCRIPT_DIR / ANDROID_ROOT / BUILD_CLEAN 等全局变量已设置
#   - build/envsetup.sh 已 source + lunch 已完成

# ---------- 编译 U-Boot ----------
# 三步流程确保 SPL 来自本地源码而非 rkbin 预编译版本，详见 README.md
do_build_uboot() {
    if [[ ! -d "$SCRIPT_DIR/u-boot" ]]; then
        log_error "未找到 u-boot 目录: $SCRIPT_DIR/u-boot"
        log_error "请先通过 apply-patches.sh 将 u-boot 复制到 Android 工程根目录"
        exit 1
    fi

    log_banner "编译 U-Boot"
    cd "$SCRIPT_DIR/u-boot"

    if [[ $BUILD_CLEAN -eq 1 ]]; then
        log_step "[0/3] 全量清理旧产物..."
        run_cmd "make clean"     make clean
        run_cmd "make mrproper"  make mrproper
        run_cmd "make distclean" make distclean
    else
        log_info "增量模式，跳过 clean（-C 可全量重编）"
    fi

    log_step "[1/3] 首次编译，生成 spl/u-boot-spl.bin ..."
    # TODO: V-gatron defconfig 补丁在 patches/u-boot/bak/，待迁移后启用
    # run_cmd "./make.sh V-gatron（第 1 次）" ./make.sh V-gatron  # 自定义 defconfig，已注释
    run_cmd "./make.sh rk3588（第 1 次）" ./make.sh rk3588        # 默认 RK3588 defconfig

    log_step "[2/3] 替换 rkbin 预编译 SPL ..."
    if [[ ! -f "spl/u-boot-spl.bin" ]]; then
        log_error "spl/u-boot-spl.bin 不存在，第 1 步编译可能失败"
        exit 1
    fi
    if [[ ! -d "$SCRIPT_DIR/rkbin" ]]; then
        log_error "未找到 rkbin 目录: $SCRIPT_DIR/rkbin"
        log_error "请先通过 apply-patches.sh 将 rkbin 复制到 Android 工程根目录"
        exit 1
    fi
    run_cmd "复制 SPL → rkbin" \
        cp spl/u-boot-spl.bin "$SCRIPT_DIR/rkbin/bin/rk35/rk3588_spl_v1.13.bin"

    log_step "[3/3] 重新编译打包，嵌入自编 SPL ..."
    if [[ $BUILD_CLEAN -eq 1 ]]; then
        run_cmd "make clean"     make clean
        run_cmd "make mrproper"  make mrproper
        run_cmd "make distclean" make distclean
    fi
    # TODO: V-gatron defconfig 补丁在 patches/u-boot/bak/，待迁移后启用
    # run_cmd "./make.sh V-gatron（第 2 次）" ./make.sh V-gatron  # 自定义 defconfig，已注释
    run_cmd "./make.sh rk3588（第 2 次）" ./make.sh rk3588        # 默认 RK3588 defconfig
}

# ---------- 编译内核 ----------
do_build_kernel() {
    # ---- 内核编译参数（从 lunch 后的 BoardConfig 动态读取）----
    KERNEL_VERSION=$(get_build_var PRODUCT_KERNEL_VERSION)
    KERNEL_ARCH=$(get_build_var PRODUCT_KERNEL_ARCH)
    KERNEL_DEFCONFIG=$(get_build_var PRODUCT_KERNEL_CONFIG)
    KERNEL_DTS=$(get_build_var PRODUCT_KERNEL_DTS)

    KERNEL_SRC="$SCRIPT_DIR/kernel-${KERNEL_VERSION}"

    # clang 版本（与 rk-kernel-5.10/build.config.constants: CLANG_VERSION=r450784d 一致）
    KERNEL_CLANG_VER="r450784d"
    KERNEL_CLANG_BIN="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-${KERNEL_CLANG_VER}/bin"

    # LLVM=1 LLVM_IAS=1：使用 clang/lld 替代 gcc/binutils
    ADDON_ARGS="CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 LLVM_IAS=1"

    # 并行编译 job 数（复用 check_build_deps 已探测的 CPU_CORES）
    BUILD_JOBS="${CPU_CORES}"

    log_banner "编译内核 (rk-kernel-${KERNEL_VERSION})"

    if [[ ! -d "$KERNEL_SRC" ]]; then
        log_error "未找到 kernel-${KERNEL_VERSION} 目录: $KERNEL_SRC"
        log_error "请先通过 apply-patches.sh 将 rk-kernel-${KERNEL_VERSION} 复制到 Android 工程根目录"
        exit 1
    fi
    log_ok "kernel 源码目录: $KERNEL_SRC"

    log_info "KERNEL_VERSION   = $KERNEL_VERSION"
    log_info "KERNEL_ARCH      = $KERNEL_ARCH"
    log_info "KERNEL_DEFCONFIG = $KERNEL_DEFCONFIG"
    log_info "KERNEL_DTS       = $KERNEL_DTS"
    log_info "KERNEL_CLANG_VER = $KERNEL_CLANG_VER"
    log_info "ADDON_ARGS       = $ADDON_ARGS"
    log_info "BUILD_JOBS       = $BUILD_JOBS"

    cd "$KERNEL_SRC"

    # ---- 将 clang 加入 PATH（check_build_deps 已验证 clang 存在）----
    export PATH="${KERNEL_CLANG_BIN}:${PATH}"
    log_ok "clang PATH 已设置: $(clang --version 2>/dev/null | head -1)"

    # ---- 全量清理（仅 -C 模式）----
    if [[ $BUILD_CLEAN -eq 1 ]]; then
        log_step "[0/2] 全量清理内核旧产物..."
        run_cmd "make clean" make $ADDON_ARGS ARCH="${KERNEL_ARCH}" clean
    fi

    # ---- 内核编译（defconfig → Image + 主 DTB + resource.img）----
    log_step "[1/2] 内核编译（defconfig → Image）..."
    run_cmd "make defconfig (${KERNEL_DEFCONFIG})" \
        make $ADDON_ARGS ARCH="${KERNEL_ARCH}" ${KERNEL_DEFCONFIG}
    run_cmd "make ${KERNEL_DTS}.img" \
        make $ADDON_ARGS ARCH="${KERNEL_ARCH}" "${KERNEL_DTS}.img" -j"${BUILD_JOBS}"

    # ----  [wifi] 外部 wifi/BT driver 编译（out-of-tree 内核模块 .ko）----
    # external/wifi_driver 顶层是 Kbuild 风格（obj-$(CONFIG_...)），无 Android.mk/bp，
    # 必须用 make -C <kernel> M=<driver> 在内核源码树外单独编译，整编无法自动覆盖。
    EXT_WIFI_PATH="$ANDROID_ROOT/external/wifi_driver"
    if [[ -d "$EXT_WIFI_PATH" ]]; then
        log_step "[wifi] 编译外部 wifi/BT 驱动（out-of-tree 内核模块）..."
        # set_android_version.sh：根据 Android 版本号导出驱动编译宏（如 ANDROID_VERSION）
        if [[ -f "$EXT_WIFI_PATH/set_android_version.sh" ]]; then
            source "$EXT_WIFI_PATH/set_android_version.sh" "$EXT_WIFI_PATH"
            log_info "已加载 wifi driver set_android_version.sh"
        fi
        if [[ $BUILD_CLEAN -eq 1 ]]; then
            run_cmd "wifi driver: make clean" \
                make $ADDON_ARGS ARCH="${KERNEL_ARCH}" \
                    -C "$KERNEL_SRC" M="$EXT_WIFI_PATH" clean
        else
            log_info "增量模式，跳过 wifi driver clean（-C 可全量重编）"
        fi
        run_cmd "wifi driver: make -j${BUILD_JOBS}" \
            make $ADDON_ARGS ARCH="${KERNEL_ARCH}" \
                -C "$KERNEL_SRC" M="$EXT_WIFI_PATH" -j"${BUILD_JOBS}"
        log_ok "外部 wifi/BT 驱动编译完成"
    else
        log_error "external/wifi_driver/ 不存在，跳过外部 wifi 驱动编译"
        exit 1
    fi

    # ---- 复制 kernel Image → $OUT/kernel ----
    # make bootimage 从 $OUT/kernel 取镜像，整编不会重编内核源码，须手动放置
    log_step "[2/2] 复制 kernel Image → $OUT/kernel..."
    if [[ -z "${OUT:-}" ]]; then
        log_error "\$OUT 未设置，跳过（lunch 环境变量丢失，请重新 source build/envsetup.sh && lunch）"
        exit 1
    else
        mkdir -p "$OUT"
        run_cmd "cp Image → $OUT/kernel" \
            cp -f "${KERNEL_SRC}/arch/arm64/boot/Image" "${OUT}/kernel"
        log_info "已放置: ${OUT}/kernel（make bootimage 从此路径取 Image）"
    fi
}

# ---------- 整编 Android ----------
do_build_android() {
    log_banner "整编 Android"

    BUILD_JOBS="${CPU_CORES}"
    log_info "BUILD_JOBS = ${BUILD_JOBS}"

    cd "$ANDROID_ROOT"

    if [[ $BUILD_CLEAN -eq 1 ]]; then
        run_cmd "make clean" make clean
    else
        log_info "增量模式，跳过 clean（-C 可全量重编）"
    fi

    # 确保内核已编译且 Image 就位（do_build_kernel 内含 clean/增量判断 + cp Image）
    do_build_kernel

    cd "$ANDROID_ROOT"
    run_cmd "make -j${BUILD_JOBS}" make -j"${BUILD_JOBS}"
}

# ---------- 整理分区镜像 ----------
# do_mkimage：将各分区镜像整理到 $SCRIPT_DIR/Image/
#   移植自 RK 参考 mkimage.sh，适配 V_gatron_car / RK3588 差异：
#   - RK3588 ATF 已内嵌于 uboot.img，无独立 trust.img（正常跳过）
#   - BOARD_AVB_ENABLE=false → 使用 device/rockchip/common/vbmeta.img 占位
#   - rkst/Image/misc.img 由 apply-patches.sh 从 patches/misc.img 部署（未找到则警告）
#   - parameter.txt 优先 device 目录，回退 $OUT，再回退工厂镜像
#   - boot.img 优先 $OUT（整编产物），回退 kernel-5.10/（-K 临时合成版）
do_mkimage() {
    log_banner "整理分区镜像（mkimage）"
    cd "$ANDROID_ROOT"

    local TARGET_DEVICE_DIR; TARGET_DEVICE_DIR=$(get_build_var TARGET_DEVICE_DIR)
    local BOARD_AVB_ENABLE; BOARD_AVB_ENABLE=$(get_build_var BOARD_AVB_ENABLE)
    local PRODUCT_USE_DYNAMIC_PARTITIONS; PRODUCT_USE_DYNAMIC_PARTITIONS=$(get_build_var PRODUCT_USE_DYNAMIC_PARTITIONS)
    local TARGET_BASE_PARAMETER_IMAGE; TARGET_BASE_PARAMETER_IMAGE=$(get_build_var TARGET_BASE_PARAMETER_IMAGE)
    local KERNEL_PATH; KERNEL_PATH=$(get_build_var PRODUCT_KERNEL_PATH)

    local IMAGE_DIR="$SCRIPT_DIR/Image"
    local UBOOT_PATH="$SCRIPT_DIR/u-boot"

    log_info "TARGET_DEVICE_DIR              = $TARGET_DEVICE_DIR"
    log_info "BOARD_AVB_ENABLE               = $BOARD_AVB_ENABLE"
    log_info "PRODUCT_USE_DYNAMIC_PARTITIONS = $PRODUCT_USE_DYNAMIC_PARTITIONS"
    log_info "KERNEL_PATH                    = $KERNEL_PATH"
    log_info "IMAGE_DIR                      = $IMAGE_DIR"

    if [[ -d "$IMAGE_DIR" ]]; then
        log_info "清空已有目录: $IMAGE_DIR"
        rm -rf "${IMAGE_DIR:?}"/*
    else
        log_info "创建目录: $IMAGE_DIR"
        mkdir -p "$IMAGE_DIR" || { log_error "创建 $IMAGE_DIR 失败"; exit 1; }
    fi

    # ---- uboot.img ----
    if [[ -f "$UBOOT_PATH/uboot.img" ]]; then
        cp -a "$UBOOT_PATH/uboot.img" "$IMAGE_DIR/uboot.img"
        log_ok "uboot.img"
    else
        log_warn "uboot.img 未找到: $UBOOT_PATH/uboot.img（请先编译 U-Boot）"
    fi

    # ---- MiniLoaderAll.bin ----
    local _loader_found=0
    local _loader_pat
    for _loader_pat in "$UBOOT_PATH"/*_loader_*.bin "$UBOOT_PATH"/*loader*.bin; do
        if [[ -f "$_loader_pat" ]]; then
            cp -a "$_loader_pat" "$IMAGE_DIR/MiniLoaderAll.bin"
            log_ok "MiniLoaderAll.bin（from $(basename "$_loader_pat")）"
            _loader_found=1
            break
        fi
    done
    [[ $_loader_found -eq 0 ]] && log_warn "未找到 loader bin（$UBOOT_PATH/*loader*.bin），请先编译 U-Boot"

    # ---- dtbo.img（优先 dtbo.img，回退 rebuild-dtbo.img）----
    if [[ -f "${OUT:-}/dtbo.img" ]]; then
        cp -a "$OUT/dtbo.img" "$IMAGE_DIR/dtbo.img"
        log_ok "dtbo.img"
    elif [[ -f "${OUT:-}/rebuild-dtbo.img" ]]; then
        cp -a "$OUT/rebuild-dtbo.img" "$IMAGE_DIR/dtbo.img"
        log_ok "dtbo.img（from rebuild-dtbo.img）"
    else
        log_warn "dtbo.img / rebuild-dtbo.img 均未找到，跳过"
    fi

    # ---- resource.img（来自内核源码目录，含 logo BMP）----
    if [[ -f "$ANDROID_ROOT/$KERNEL_PATH/resource.img" ]]; then
        cp -a "$ANDROID_ROOT/$KERNEL_PATH/resource.img" "$IMAGE_DIR/resource.img"
        log_ok "resource.img"
    else
        log_warn "resource.img 未找到: $ANDROID_ROOT/$KERNEL_PATH/resource.img"
    fi

    # ---- boot.img ----
    if [[ -f "${OUT:-}/boot.img" ]]; then
        cp -a "$OUT/boot.img" "$IMAGE_DIR/boot.img"
        log_ok "boot.img"
    else
        log_warn "boot.img 未找到: $OUT/boot.img（请先运行 ./build.sh -A 整编）"
    fi

    # ---- recovery.img ----
    if [[ -f "${OUT:-}/recovery.img" ]]; then
        cp -a "$OUT/recovery.img" "$IMAGE_DIR/recovery.img"
        log_ok "recovery.img"
    else
        log_warn "recovery.img 未找到"
    fi

    # ---- super.img（动态分区）----
    if [[ -f "${OUT:-}/super.img" ]]; then
        cp -a "$OUT/super.img" "$IMAGE_DIR/super.img"
        log_ok "super.img"
    else
        log_warn "super.img 未找到"
    fi

    # ---- data.img（来自 userdata.img；AB 模式不收集，但当前非 AB）----
    if [[ -f "${OUT:-}/userdata.img" ]]; then
        cp -a "$OUT/userdata.img" "$IMAGE_DIR/data.img"
        log_ok "data.img（from userdata.img）"
    else
        log_warn "userdata.img 未找到，跳过 data.img"
    fi

    # ---- vbmeta.img ----
    if [[ "$BOARD_AVB_ENABLE" == "true" ]]; then
        if [[ -f "${OUT:-}/vbmeta.img" ]]; then
            cp -a "$OUT/vbmeta.img" "$IMAGE_DIR/vbmeta.img"
            log_ok "vbmeta.img（AVB 签名版）"
        else
            log_warn "AVB 开启但 vbmeta.img 未找到: $OUT/vbmeta.img"
        fi
    else
        if [[ -f "device/rockchip/common/vbmeta.img" ]]; then
            cp -a "device/rockchip/common/vbmeta.img" "$IMAGE_DIR/vbmeta.img"
            log_warn "vbmeta.img（dummy，BOARD_AVB_ENABLE=false）"
        else
            log_warn "device/rockchip/common/vbmeta.img 未找到"
        fi
    fi

    # ---- misc.img（来自 rkst/Image/，由 apply-patches.sh 从 patches/misc.img 部署）----
    # TODO: 后续改为编译生成（dd if=/dev/zero bs=1K count=<size>），与 parameter.txt misc 分区大小对齐
    # misc 分区控制 U-Boot 启动流向（正常 / recovery / fastboot），RK 预编译 blob。
    if [[ -f "rkst/Image/misc.img" ]]; then
        cp -a "rkst/Image/misc.img" "$IMAGE_DIR/misc.img"
        log_ok "misc.img"
    else
        log_error "misc.img 未找到: rkst/Image/misc.img（请重新运行 apply-patches.sh）"
        exit 1
    fi

    # ---- config.cfg（RKDevTool 烧录配置）----
    local _flash_cfg="$TARGET_DEVICE_DIR/config.cfg"
    if [[ -f "$_flash_cfg" ]]; then
        cp -a "$_flash_cfg" "$IMAGE_DIR/config.cfg"
        log_ok "config.cfg"
    else
        log_warn "config.cfg 未找到: $_flash_cfg"
    fi

    # ---- parameter.txt（eMMC 分区表）----
    # 优先 device 目录，回退 $OUT（动态生成），再回退工厂镜像（-K 单独编译时）
    local _param_dev="$TARGET_DEVICE_DIR/parameter.txt"
    if [[ -f "$_param_dev" ]]; then
        cp -a "$_param_dev" "$IMAGE_DIR/parameter.txt"
        log_warn "parameter.txt（来自 device 目录）"
    elif [[ -f "${OUT:-}/parameter.txt" ]]; then
        cp -a "$OUT/parameter.txt" "$IMAGE_DIR/parameter.txt"
        log_ok "parameter.txt（来自 \$OUT，动态生成）"
    else
        log_warn "parameter.txt 未找到（device 目录、\$OUT均无）"
    fi

    # ---- baseparameter.img（可选，TARGET_BASE_PARAMETER_IMAGE 控制）----
    if [[ -n "$TARGET_BASE_PARAMETER_IMAGE" ]]; then
        if [[ -f "$TARGET_BASE_PARAMETER_IMAGE" ]]; then
            cp -a "$TARGET_BASE_PARAMETER_IMAGE" "$IMAGE_DIR/baseparameter.img"
            log_ok "baseparameter.img"
        else
            log_warn "baseparameter.img 未找到: $TARGET_BASE_PARAMETER_IMAGE"
        fi
    fi

    chmod a+r -R "$IMAGE_DIR/"
    cd "$SCRIPT_DIR"

    log_ok "产物目录: $IMAGE_DIR"
    log_info "$(ls -lh "$IMAGE_DIR" 2>/dev/null || echo '（空）')"
    log_banner "镜像整理完成 ✓"
}
