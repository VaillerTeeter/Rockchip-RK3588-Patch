#!/bin/bash
# 共享工具库 —— 供仓库内所有脚本 source 引用
#
# 用法：
#   source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
#
# 提供：
#   - 彩色日志函数：log_info / log_ok / log_warn / log_error / log_step / log_banner
#   - 命令执行包装：run_cmd
#   - 资源合入函数：copy_with_guard / apply_patches / extract_tarball / apply_resources
#   - 资源清理函数：remove_with_guard / revert_patches / clean_resources
#   - 环境依赖检查：check_build_deps

# ---------- 颜色常量 ----------
_R='\033[0;31m'  # red
_G='\033[0;32m'  # green
_Y='\033[0;33m'  # yellow
_B='\033[0;34m'  # blue
_C='\033[0;36m'  # cyan
_W='\033[1;37m'  # bold white
_N='\033[0m'     # reset

# ---------- 日志函数 ----------
log_info()    { echo -e "${_C}  ℹ  ${_N}$*"; }
log_ok()      { echo -e "${_G}  ✓  ${_N}$*"; }
log_warn()    { echo -e "${_Y}  ⚠  ${_N}$*"; }
log_error()   { echo -e "${_R}  ✗  ${_N}$*" >&2; }
log_step()    { echo -e "${_W}  ▶  ${_N}$*"; }
log_banner()  {
    echo -e "${_B}════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${_N}"
    echo -e "${_W}  $*${_N}"
    echo -e "${_B}════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${_N}"
}

# ---------- 步骤计数 ----------
STEP=0
TOTAL=0

# init_steps <total>
# 初始化步骤计数器，必须在第一次调用 step 之前调用。
init_steps() {
    STEP=0
    TOTAL="$1"
}

# step <描述>
# 每次调用自动递增 STEP 并输出 "[0N/TOTAL] 描述"（0 填充，等宽对齐）。
step() {
    STEP=$((STEP + 1))
    log_step "[$(printf '%02d' $STEP)/$(printf '%02d' $TOTAL)] $*"
}

# ---------- 命令执行包装 ----------
# run_cmd <描述> <命令...>
# 执行命令，成功输出 log_ok，失败输出 log_error 并退出
run_cmd() {
    local desc="$1"; shift
    log_info "${desc}"
    if "$@"; then
        log_ok "${desc} 完成"
    else
        log_error "${desc} 失败（exit $?）"
        exit 1
    fi
}

# ---------- 文件/目录复制（幂等） ----------
# copy_with_guard <src> <dst> [label]
# - src 为文件 → cp 单文件
# - src 为目录 → cp -r 递归复制，自动清理 .git（子模块残留）
# - dst 已存在 → log_warn 跳过
# 返回 0 表示成功或跳过，返回 1 表示源路径不存在
copy_with_guard() {
    local src="$1"
    local dst="$2"
    local label="${3:-$(basename "$src")}"

    if [[ -f "$src" ]]; then
        if [[ -f "$dst" ]]; then
            log_warn "    [$dst] 已存在，跳过（如需重新合入请先执行 clean-patches.sh）"
            return 0
        fi

        cp "$src" "$dst"
        log_ok "    [${label}] 已复制到 $dst"
    elif [[ -d "$src" ]]; then
        if [[ -d "$dst" ]]; then
            log_warn "    [$dst] 已存在，跳过（如需重新合入请先执行 clean-patches.sh）"
            return 0
        fi

        cp -r "$src" "$dst"

        # 子模块内含指向父仓库的 .git 文件（gitdir 相对路径）。
        # cp 后路径失效会导致 git 报错；构建不需要 git 历史，直接删除。
        # 同时删除 .scmversion，确保后续 git init 块能重新生成。
        rm -f "$dst/.git" "$dst/.scmversion"

        log_ok "    [${label}] 已复制到 $dst"
    else
        log_error "    源路径不存在: $src"
        return 1
    fi
}

# ---------- 文件/目录删除（幂等） ----------
# remove_with_guard <path> [label]
# - path 为文件 → rm -f
# - path 为目录 → rm -rf
# - 不存在 → log_warn 跳过
# 返回 0 表示成功或跳过
remove_with_guard() {
    local path="$1"
    local label="${2:-$(basename "$path")}"

    if [[ -f "$path" ]]; then
        rm -f "$path"
        log_ok "    [${label}] 已删除"
    elif [[ -d "$path" ]]; then
        rm -rf "$path"
        log_ok "    [${label}] 已删除"
    else
        log_warn "    [${label}] 不存在，跳过"
    fi
}

# ---------- 补丁应用函数 ----------
# apply_patches <patch_dir> <repo_dir> [label]
# 将 <patch_dir> 下所有 .patch 按文件名排序后应用到 <repo_dir>
# - <repo_dir>/.git 不存在则跳过
# - 幂等：git apply --check --reverse 通过说明已应用，跳过
apply_patches() {
    local patch_dir="$1"
    local repo_dir="$2"
    local label="${3:-$(basename "$patch_dir")}"

    if [[ ! -d "$repo_dir/.git" ]]; then
        log_warn "    [$repo_dir] 不是 git 仓库，跳过 ${label} 补丁"
        return 0
    fi

    if ! compgen -G "$patch_dir/"*.patch > /dev/null 2>&1; then
        log_warn "    [${label}] 下无 .patch 文件，跳过"
        return 0
    fi

    local _patch_max=0
    for f in $(ls "$patch_dir/"*.patch | sort); do
        local _n; _n=$(basename "$f")
        ((${#_n} > _patch_max)) && _patch_max=${#_n}
    done

    for patch in $(ls "$patch_dir/"*.patch | sort); do
        local patch_name
        patch_name=$(basename "$patch")
        if (cd "$repo_dir" && git apply --check --reverse "$patch" 2>/dev/null); then
            log_warn "    [${label}] PATCH: $(printf "%-${_patch_max}s" "$patch_name") 已应用，跳过"
        else
            (cd "$repo_dir" && git apply --ignore-space-change --whitespace=nowarn "$patch")
            log_ok "    [${label}] PATCH: $(printf "%-${_patch_max}s" "$patch_name") 已应用"
        fi
    done
}

# ---------- 补丁回退函数 ----------
# revert_patches <patch_dir> <repo_dir> [label]
# 将 <patch_dir> 下所有 .patch 按文件名倒序在 <repo_dir> 中 git apply --reverse
# - <repo_dir>/.git 不存在则跳过
# - 幂等：git apply --check --reverse 通过才执行实际回退
revert_patches() {
    local patch_dir="$1"
    local repo_dir="$2"
    local label="${3:-$(basename "$patch_dir")}"

    if [[ ! -d "$repo_dir/.git" ]]; then
        log_warn "    [$repo_dir] 不是 git 仓库，跳过 ${label} 补丁回退"
        return 0
    fi

    if ! compgen -G "$patch_dir/"*.patch > /dev/null 2>&1; then
        log_warn "    [${label}] 下无 .patch 文件，跳过"
        return 0
    fi

    local _patch_max=0
    for f in $(ls "$patch_dir/"*.patch | sort --reverse); do
        local _n; _n=$(basename "$f")
        ((${#_n} > _patch_max)) && _patch_max=${#_n}
    done

    for patch in $(ls "$patch_dir/"*.patch | sort --reverse); do
        local patch_name
        patch_name=$(basename "$patch")
        if (cd "$repo_dir" && git apply --check --reverse "$patch" 2>/dev/null); then
            (cd "$repo_dir" && git apply --reverse --whitespace=nowarn "$patch")
            log_ok "    [${label}] REVERT: $(printf "%-${_patch_max}s" "$patch_name")"
        else
            log_warn "    [${label}] REVERT: $(printf "%-${_patch_max}s" "$patch_name") 未应用或无法回滚，跳过"
        fi
    done
}

# ---------- 解压函数 ----------
# extract_tarball <tarball> <dest_dir> [label]
# 将 tarball 解压到目标目录
# - tarball 不存在时 warn 跳过
# - tar -xf 自动识别压缩格式（兼容 .tar.gz / .tar.xz / .tar.bz2）
extract_tarball() {
    local tarball="$1"
    local dest_dir="$2"
    local label="${3:-$(basename "$tarball")}"

    if [[ ! -f "$tarball" ]]; then
        log_warn "    tarball 不存在: $tarball，跳过"
        return 0
    fi

    tar -xf "$tarball" -C "$dest_dir"
    log_ok "    [${label}] 已解压"
}

# ---------- 统一资源合入 ----------
#
# apply_resources [SENTINEL args...]...
#
# 按 copy → patch → extract 顺序执行三个阶段的资源合入操作。
# 每个阶段由 sentinel 标记（--copy / --patch / --extract），段内参数为多个条目，
# 每个条目的 label 均可省略（默认取对应路径的 basename）。
#
# ---- Sentinel 与参数格式 ----
#
#   --copy    src dst [label]  [src dst label ...]
#   --patch   patch_dir repo_dir [label [source_repo]]  [patch_dir repo_dir label ...]
#   --extract tarball dest_dir [label]  [tarball dest_dir label ...]
#
# ---- 各段预检 ----
#
#   --copy    检查 src 是否存在（-e），不存在则 warn 并跳过该条目。
#             存在则委托 copy_with_guard（幂等，目标已存在时跳过）。
#   --patch   检查 patch_dir 是否存在（-d），不存在则 warn 跳过。
#             存在则委托 apply_patches（幂等，git apply --check --reverse）。
#             source_repo（可选第 4 参数）：
#               若 repo_dir 是通过 copy_with_guard 从子模块 cp 得到的副本
#               （其 .git 已被删除），传入原始子模块路径作为 source_repo，
#               本函数会先执行 git init + 空 commit + .scmversion，再 apply_patches。
#               此操作幂等：.scmversion 存在时跳过。
#   --extract 检查 tarball 是否存在（-f），不存在则 warn 跳过。
#             存在则委托 extract_tarball（tar -xf 自动识别格式）。
#
# ---- 跳过日志 ----
#
#   某 sentinel 未出现 → 对应阶段打印一条 log_info "无需要...，跳过"。
#
# ---- 调用示例 ----
#
#   1) 纯 copy（多文件）：
#     apply_resources --copy \
#         "scripts/build.sh"  "/target/build.sh"  "build.sh" \
#         "scripts/common.sh" "/target/rk_build_common.sh" "rk_build_common.sh"
#
#   2) copy + patch（子模块需要 git init）：
#     apply_resources \
#         --copy  "$SRC" "$DST" "kernel" \
#         --patch "patches/kernel" "$DST" "kernel" "$SRC"
#
#   3) patch + extract（多 patch 目录）：
#     apply_resources \
#         --patch \
#             "patches/build/make"  "/target/build/make"  "build/make" \
#             "patches/build/soong" "/target/build/soong" "build/soong" \
#         --extract \
#             "toolchain.tar.xz" "/opt/aarch64" "aarch64 工具链" \
#             "toolchain-arm.tar.xz" "/opt/arm"   "arm32 工具链"
#
#   4) 三阶段全空（仅日志）：
#     apply_resources
#     → 输出三条 "无需要...，跳过"
apply_resources() {
    local mode=""
    local _ctx_label=""
    local had_copy=0 had_patch=0 had_extract=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --copy)    mode="copy";    shift; continue ;;
            --patch)   mode="patch";   shift; continue ;;
            --extract) mode="extract"; shift; continue ;;
        esac

        case "$mode" in
            copy)
                had_copy=1
                local _src="$1";  local _dst="$2";  local _label="${3:-$(basename "$1")}"
                [[ -z "$_ctx_label" ]] && _ctx_label="$_label"
                shift 3 2>/dev/null || { shift $#; break; }
                if [[ -e "$_src" ]]; then
                    copy_with_guard "$_src" "$_dst" "$_label"
                else
                    log_warn "    源路径不存在: $_src，跳过（u-boot/rkbin/rk-kernel-5.10 子模块请先执行 git submodule update --init）"
                fi
                ;;
            patch)
                had_patch=1
                local _pdir="$1"; local _rdir="$2"; local _plabel="${3:-$(basename "$1")}"
                [[ -z "$_ctx_label" ]] && _ctx_label="$_plabel"
                local _psrc=""

                # 可选第 4 参数：源仓库（用于 cp 子模块后初始化 git）。
                # 必须是真正的 git 仓库（-e .git，兼容 submodule 文件），防止多 entry 时下一个 entry 的路径被误判为 source_repo。
                if [[ -n "${4:-}" && "${4:-}" != --* && -e "${4:-}/.git" ]]; then
                    _psrc="$4"
                    shift 1
                fi
                shift 3 2>/dev/null || { shift $#; break; }

                # 有源仓库且目标已复制 → 初始化 git + 生成 .scmversion（幂等）
                if [[ -n "$_psrc" && -d "$_rdir" && ! -f "$_rdir/.scmversion" ]]; then
                    local _branch _hash _scmver
                    _branch="$(git -C "$_psrc" symbolic-ref -q --short HEAD 2>/dev/null || echo "main")"
                    _hash="$(git -C "$_psrc" rev-parse --short HEAD 2>/dev/null || true)"
                    git -C "$_rdir" init -q
                    git -C "$_rdir" symbolic-ref HEAD "refs/heads/${_branch}"
                    GIT_AUTHOR_NAME="build" GIT_AUTHOR_EMAIL="build@local" \
                    GIT_COMMITTER_NAME="build" GIT_COMMITTER_EMAIL="build@local" \
                    git -C "$_rdir" commit --allow-empty -q \
                        -m "sync: ${_branch}@${_hash}"
                    _scmver="${_hash:+-g${_hash}}"
                    printf '%s' "$_scmver" > "$_rdir/.scmversion"
                    log_info "    .scmversion = \"${_scmver}\" (来自 ${_psrc})"
                fi

                if [[ -d "$_pdir" ]]; then
                    apply_patches "$_pdir" "$_rdir" "$_plabel"
                else
                    log_warn "    patch 目录不存在: $_pdir，跳过"
                fi
                ;;
            extract)
                had_extract=1
                local _tarball="$1"; local _dstdir="$2"; local _tlabel="${3:-$(basename "$1")}"
                [[ -z "$_ctx_label" ]] && _ctx_label="$_tlabel"
                shift 3 2>/dev/null || { shift $#; break; }
                if [[ -f "$_tarball" ]]; then
                    extract_tarball "$_tarball" "$_dstdir" "$_tlabel"
                else
                    log_warn "    tarball 不存在: $_tarball，跳过"
                fi
                ;;
        esac
    done

    [[ $had_copy    -eq 0 ]] && log_ok "    [${_ctx_label:+${_ctx_label}}] 无需要复制的文件/目录，跳过"
    [[ $had_patch   -eq 0 ]] && log_ok "    [${_ctx_label:+${_ctx_label}}] 无需要应用的补丁，跳过"
    [[ $had_extract -eq 0 ]] && log_ok "    [${_ctx_label:+${_ctx_label}}] 无需要解压的压缩包，跳过"

    return 0
}

# ---------- 统一资源清理 ----------
#
# clean_resources [SENTINEL args...]...
#
# 按 remove → revert 顺序执行两个阶段的资源清理操作。
# 每个阶段由 sentinel 标记（--remove / --revert），段内参数为多个条目，
# 每个条目的 label 均可省略（默认取对应路径的 basename）。
#
# ---- Sentinel 与参数格式 ----
#
#   --remove  path [label]  [path label ...]
#   --revert  patch_dir repo_dir [label]  [patch_dir repo_dir label ...]
#
# ---- 各段预检 ----
#
#   --remove  委托 remove_with_guard（幂等，不存在则跳过）。
#   --revert  检查 patch_dir 是否存在（-d），不存在则 warn 跳过。
#             存在则委托 revert_patches（幂等，git apply --check --reverse）。
#
# ---- 跳过日志 ----
#
#   某 sentinel 未出现 → 对应阶段打印一条 log_info "无需要...，跳过"。
#
# ---- 调用示例 ----
#
#   1) 纯 remove（多文件/目录）：
#     clean_resources --remove \
#         "/target/build.sh"           "build.sh" \
#         "/target/rk_build_common.sh" "rk_build_common.sh"
#
#   2) remove + revert：
#     clean_resources \
#         --remove "/target/u-boot" "u-boot" \
#         --revert "patches/bionic" "/target/bionic" "bionic"
#
#   3) 纯 revert（多 patch 目录）：
#     clean_resources --revert \
#         "patches/build/make"  "/target/build/make"  "build/make" \
#         "patches/build/soong" "/target/build/soong" "build/soong"
#
#   4) 两阶段全空（仅日志）：
#     clean_resources
#     → 输出两条 "无需要...，跳过"
clean_resources() {
    local mode=""
    local _ctx_label=""
    local had_remove=0 had_revert=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remove) mode="remove"; shift; continue ;;
            --revert) mode="revert"; shift; continue ;;
        esac

        case "$mode" in
            remove)
                had_remove=1
                local _path="$1"; local _rlabel="${2:-$(basename "$1")}"
                [[ -z "$_ctx_label" ]] && _ctx_label="$_rlabel"
                shift 2 2>/dev/null || { shift $#; break; }
                remove_with_guard "$_path" "$_rlabel"
                ;;
            revert)
                had_revert=1
                local _pdir="$1"; local _rdir="$2"; local _rvlabel="${3:-$(basename "$1")}"
                [[ -z "$_ctx_label" ]] && _ctx_label="$_rvlabel"
                shift 3 2>/dev/null || { shift $#; break; }
                if [[ -d "$_pdir" ]]; then
                    revert_patches "$_pdir" "$_rdir" "$_rvlabel"
                else
                    log_warn "    patch 目录不存在: $_pdir，跳过"
                fi
                ;;
        esac
    done

    [[ $had_remove -eq 0 ]] && log_ok "    [${_ctx_label:+${_ctx_label}}] 无需要删除的文件/目录，跳过"
    [[ $had_revert -eq 0 ]] && log_ok "    [${_ctx_label:+${_ctx_label}}] 无需要回退的补丁，跳过"

    return 0
}

# ---------- 环境依赖检查 ----------
# check_build_deps —— 检查所有编译/开发依赖，缺失时汇总 apt 安装命令
#
# 依赖调用方已定义 SCRIPT_DIR（指向脚本所在目录）。
# 如果 ANDROID_ROOT 已设置则优先使用（由 build.sh 在 lunch 前设置）。
#
# 检查完成后设置全局变量 CPU_CORES（供 make -j 使用）。
check_build_deps() {
    log_banner "检查编译环境依赖"

    local _root="${ANDROID_ROOT:-$SCRIPT_DIR}"
    local missing_apt=()    # 缺失的 apt 包名
    local missing_other=()  # 缺失的非 apt 项（含安装提示）

    # ---- apt 包检查（command -v 验证）----
    _check_cmd() {
        local cmd="$1" pkg="$2"
        if command -v "$cmd" &>/dev/null; then
            log_ok "${pkg} (${cmd})"
        else
            log_warn "${pkg} 未安装（${cmd} 不可用）"
            missing_apt+=("$pkg")
        fi
    }

    _check_cmd "tree"                       "tree"
    _check_cmd "make"                       "build-essential"
    _check_cmd "gcc"                        "build-essential"
    _check_cmd "htop"                       "htop"
    _check_cmd "python3"                    "python3"
    _check_cmd "node"                       "nodejs"
    _check_cmd "npm"                        "npm"
    _check_cmd "go"                         "golang-go"
    _check_cmd "unzip"                      "unzip"
    _check_cmd "dtc"                        "device-tree-compiler"
    _check_cmd "ifconfig"                   "net-tools"
    _check_cmd "aarch64-linux-gnu-gcc"      "gcc-aarch64-linux-gnu"
    _check_cmd "flex"                       "flex"
    _check_cmd "bison"                      "bison"
    _check_cmd "git"                        "git"
    _check_cmd "curl"                       "curl"
    _check_cmd "xz"                         "xz-utils"
    _check_cmd "cpio"                       "cpio"
    _check_cmd "perl"                       "perl"
    _check_cmd "lz4"                        "lz4"

    # ---- openjdk-11-jdk（版本必须为 11）----
    if command -v java &>/dev/null; then
        local jver
        jver=$(java -version 2>&1 | awk -F'"' 'NR==1{split($2,a,"."); print (a[1]=="1"?a[2]:a[1])}')
        if [[ "$jver" == "11" ]]; then
            log_ok "openjdk-11-jdk ($(java -version 2>&1 | head -1))"
        else
            log_warn "JDK 版本为 ${jver}，Android 13 需要 JDK 11"
            missing_apt+=("openjdk-11-jdk")
        fi
    else
        log_warn "openjdk-11-jdk 未安装（java 不可用）"
        missing_apt+=("openjdk-11-jdk")
    fi

    # ---- pyenv（非 apt 包，通过 curl 安装）----
    if command -v pyenv &>/dev/null; then
        log_ok "pyenv ($(pyenv --version 2>&1))"
    else
        log_warn "pyenv 未安装"
        missing_other+=("pyenv: curl https://pyenv.run | bash")
    fi

    # ---- clang r450784d（AOSP 预编译工具链）----
    local clang_path="${_root}/prebuilts/clang/host/linux-x86/clang-r450784d/bin/clang"
    if [[ -x "$clang_path" ]]; then
        log_ok "clang-r450784d ($("$clang_path" --version | head -1))"
    else
        log_error "AOSP 预编译 clang-r450784d 未找到: ${clang_path}"
        missing_other+=("clang-r450784d: 请确认 AOSP prebuilts/clang 已就位")
    fi

    # ---- CPU 核心数（设置全局变量，供 make -j 使用）----
    CPU_CORES=$(nproc)
    log_info "CPU 核心数: ${CPU_CORES}"

    # ---- 物理内存 ----
    local total_ram_kb total_ram_gb
    total_ram_kb=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}') || total_ram_kb=0
    total_ram_gb=$((total_ram_kb / 1024 / 1024))
    if [[ $total_ram_gb -lt 32 ]]; then
        log_warn "物理内存: ${total_ram_gb}GB（AOSP 官方要求 64GB，当前配置整编可能 OOM）"
    elif [[ $total_ram_gb -lt 64 ]]; then
        log_warn "物理内存: ${total_ram_gb}GB（AOSP 官方要求 64GB，可能影响并行编译速度）"
    else
        log_info "物理内存: ${total_ram_gb}GB"
    fi

    # ---- 磁盘空间 ----
    local avail_gb
    avail_gb=$(df -BG "$_root" 2>/dev/null | awk 'NR==2{gsub("G",""); print $4}') || avail_gb=0
    if [[ "$avail_gb" -lt 200 ]]; then
        log_warn "可用磁盘: ${avail_gb}GB（AOSP 官方要求 400GB，当前空间可能不足以完成整编）"
    elif [[ "$avail_gb" -lt 400 ]]; then
        log_warn "可用磁盘: ${avail_gb}GB（AOSP 官方推荐 400GB，建议扩容后再整编）"
    else
        log_info "可用磁盘: ${avail_gb}GB"
    fi

    # ---- 操作系统版本 ----
    if [[ -f /etc/os-release ]]; then
        local os_id os_ver
        os_id=$(. /etc/os-release && echo "$ID")
        os_ver=$(. /etc/os-release && echo "$VERSION_ID")
        if [[ "$os_id" == "ubuntu" ]]; then
            log_info "操作系统: Ubuntu ${os_ver}"
            if [[ "$os_ver" != "20.04" && "$os_ver" != "18.04" ]]; then
                log_warn "Android 13 官方支持 Ubuntu 18.04/20.04，当前 ${os_ver} 可能遇到兼容问题"
            fi
        else
            log_warn "操作系统: ${os_id} ${os_ver}，Android 13 推荐在 Ubuntu 20.04 上构建"
        fi
    fi

    # ---- 汇总缺失 ----
    if [[ ${#missing_apt[@]} -gt 0 ]] || [[ ${#missing_other[@]} -gt 0 ]]; then
        echo ""
        log_warn "══════════════════════════════════════════════════════════════"
        log_warn "  以下依赖缺失，请在继续编译前安装："
        log_warn "══════════════════════════════════════════════════════════════"

        if [[ ${#missing_apt[@]} -gt 0 ]]; then
            # 去重（build-essential 由 make 和 gcc 各触发一次）
            local _apt_pkgs=() _seen=()
            for p in "${missing_apt[@]}"; do
                if [[ ! " ${_seen[*]} " =~ " ${p} " ]]; then
                    _apt_pkgs+=("$p")
                    _seen+=("$p")
                fi
            done
            echo ""
            log_info "apt 包缺失，请执行："
            echo -e "${_W}  sudo apt install -y ${_apt_pkgs[*]}${_N}"
        fi

        if [[ ${#missing_other[@]} -gt 0 ]]; then
            echo ""
            for item in "${missing_other[@]}"; do
                log_info "${item}"
            done
        fi
        echo ""
        log_warn "══════════════════════════════════════════════════════════════"
    else
        log_ok "所有编译依赖已就绪"
    fi

    log_banner "环境检查完成"
}