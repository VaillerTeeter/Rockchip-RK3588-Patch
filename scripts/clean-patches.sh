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

# ============================================================
# 清理步骤
# 与 apply-patches.sh 的合入步骤一一对应，按逆序执行。
# 当前仅保留补丁 1 的清理，后续按此模式添加更多。
# ============================================================

# ---------- 补丁 1：U-Boot ----------
log_step "[1/N] 删除 u-boot/ 目录 ..."
if [[ -d "$TARGET_ROOT/u-boot" ]]; then
    rm -rf "$TARGET_ROOT/u-boot"
    log_ok "已删除 $TARGET_ROOT/u-boot"
else
    log_warn "$TARGET_ROOT/u-boot 不存在，跳过"
fi

# ---------- 补丁 2：rkbin ----------
log_step "[2/N] 删除 rkbin/ 目录 ..."
if [[ -d "$TARGET_ROOT/rkbin" ]]; then
    rm -rf "$TARGET_ROOT/rkbin"
    log_ok "已删除 $TARGET_ROOT/rkbin"
else
    log_warn "$TARGET_ROOT/rkbin 不存在，跳过"
fi

# 后续可在此继续添加更多清理步骤，例如：
# ---------- 补丁 3：Kernel  ----------
# 格式参考上面步骤

echo ""
log_banner "清理完成"