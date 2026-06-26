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

# ============================================================
# 补丁合入步骤
# 每个模块一个步骤，按编号顺序执行。
# 当前仅保留示例，后续按此模式添加更多模块。
# ============================================================

# ---------- 补丁 1：U-Boot ----------
# 将 u-boot/ 子模块完整复制到目标工程根目录
log_step "[1/N] 复制 u-boot 到目标目录 ..."
UBOOT_SRC_DIR="$PATCHES_ROOT/u-boot"
if [[ ! -d "$UBOOT_SRC_DIR" ]]; then
    log_warn "u-boot/ 子模块目录不存在，跳过（请先执行 git submodule update --init）"
elif [[ -d "$TARGET_ROOT/u-boot" ]]; then
    log_warn "$TARGET_ROOT/u-boot 已存在，跳过（如需重新合入请先执行 clean-patches.sh）"
else
    cp -r "$UBOOT_SRC_DIR" "$TARGET_ROOT/u-boot"
    # u-boot 是子模块，内含指向父仓库的 .git 文件（gitdir 相对路径）。
    # cp 后路径失效会导致 git 报错；构建不需要 git 历史，直接删除。
    rm -f "$TARGET_ROOT/u-boot/.git"
    log_ok "u-boot 已复制到 $TARGET_ROOT/u-boot"
fi

# ---------- 补丁 2：rkbin ----------
# 将 rkbin/ 子模块完整复制到目标工程根目录
log_step "[2/N] 复制 rkbin 到目标目录 ..."
RKBIN_SRC_DIR="$PATCHES_ROOT/rkbin"
if [[ ! -d "$RKBIN_SRC_DIR" ]]; then
    log_warn "rkbin/ 子模块目录不存在，跳过（请先执行 git submodule update --init）"
elif [[ -d "$TARGET_ROOT/rkbin" ]]; then
    log_warn "$TARGET_ROOT/rkbin 已存在，跳过（如需重新合入请先执行 clean-patches.sh）"
else
    cp -r "$RKBIN_SRC_DIR" "$TARGET_ROOT/rkbin"
    # rkbin 是子模块，内含指向父仓库的 .git 文件（gitdir 相对路径）。
    # cp 后路径失效会导致 git 报错；构建不需要 git 历史，直接删除。
    rm -f "$TARGET_ROOT/rkbin/.git"
    log_ok "rkbin 已复制到 $TARGET_ROOT/rkbin"
fi

# 后续可在此继续添加更多步骤，例如：
# ---------- 补丁 3：Kernel  ----------
# 格式参考上面步骤

echo ""
log_banner "所有补丁已处理完成"