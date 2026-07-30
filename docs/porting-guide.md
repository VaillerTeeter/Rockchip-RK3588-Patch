# 首轮移植说明

本文档记录了正点原子（ALIENTEK）RK3588 SDK 向 AOSP `android-13.0.0_r84` 的移植分析结论，涵盖 U-Boot 版本对齐、Kernel 移植清单和 AOSP 差异验证三个维度。

## U-Boot 版本对齐

### 结论

**RK 最新 `next-dev` HEAD 是最优基线**，正点原子（`v2017.09`，tag: `android13-atk-r1.1`，commit `9425915`）的所有改动均已被覆盖或自然消除，无需额外维护补丁。

### 对比基准

以 Rockchip `next-dev` commit `4024d9e5`（`spl: fit: Not allow append fdt failed`，
2023-09-07）为锚点，正点原子仅修改了 6 个文件。与 RK 最新 `next-dev` HEAD
（`aeec6f2bfd`）对比结果：

| 文件 | 正点原子改动 | RK 最新状态 | 结论 |
|------|-------------|-----------|------|
| `arch/arm/mach-rockchip/resource_hwid.c` | `margin` 调整、`debug→printf` | 文件已删除（HWID 逻辑重构迁移） | ✅ 自然消除 |
| `common/image-android.c` | Android 13 GKI 的 `os_version=0` 兼容 | 已有等价 GKI 检测逻辑 | ✅ 已覆盖 |
| `configs/rk3568_defconfig` | 加 `CONFIG_ROCKCHIP_HWID_DTB=y` | HWID 机制已重构，不再需要 | ✅ 自然消除 |
| `drivers/video/drm/rockchip_display.c` | 内置 logo 旋转（`SUPPORT_LOGO_ROTATE`） | 已有 `rockchip_logo_rotate()` 函数 | ✅ 已覆盖 |
| `drivers/video/drm/rockchip_display.h` | 加 `logo_rotate` 字段 | 字段已存在 | ✅ 已覆盖 |
| `scripts/pack_resource.sh` | 确保 `rk-kernel.dtb` 排在资源列表最前 | 通过 `aaa-` 前缀重命名解决 | ✅ 等价方案 |

### 历史锚点 Commit

- **正点原子版本**: `9425915`（`android13-atk-r1.1`）
- **Rockchip 锚点**: `4024d9e5d8d35ca6c69923fbc2c28f36dfae872f`
- **Rockchip 最新基线**: `aeec6f2bfd`（`next-dev` HEAD）

> Rockchip 锚点 commit `4024d9e5` 用于历史追溯和 diff 比对，实际开发直接基于 `next-dev` HEAD。

## Kernel 移植分析

> **对比版本**:
> - **Rockchip 最新基线**: `develop-5.10` 分支，commit `bfa51d2ab081`，Linux 5.10.252
>   （fork 自 [rockchip-linux/kernel](https://github.com/rockchip-linux/kernel) `develop-5.10`）
> - **正点原子（ALIENTEK）基线**: tag `android13-atk-r1.2`，commit `707b0b5f2`，Linux 5.10.157
>   （来自 Rockchip 内部 SDK `rk29` remote）
>
> **总体结论**: 正点原子对 Rockchip 内核未做实质性改动。所有差异分为三类：
> 1. **Rockchip 后续更新** — 新基线已包含大量 bug 修复、新芯片支持、驱动重构，ATK 侧为旧版，无需反向移植；
> 2. **ALIENTEK 独有新增** — 仅限 ATK 开发板的设备树（DTS）和内核配置文件（defconfig），以及构建脚本和 Logo；
> 3. **上游 stable 差异** — 5.10.157 → 5.10.252 之间 ~95 个 stable 版本的 backport，与 RK/ATK 均无关。
>
> **处理原则**: 只移植 ATK 独有的板级配置（DTS + defconfig + 构建脚本），其余差异一律不 patch，
> 直接使用 Rockchip 最新 `develop-5.10` 作为基线。
>
> **`scripts/dtc/include-prefixes/` 与 `arch/` 的关系**:
> `scripts/dtc/include-prefixes/arm64/rockchip/` 是指向 `arch/arm64/boot/dts/rockchip/` 的**软链接**（symlink）。
> 内核 DTC 编译器通过此路径查找 DTS include 文件。因此：
> - **新增 DTS 文件**：只需放入 `arch/arm64/boot/dts/rockchip/`，软链接自动生效，无需单独操作；
> - **新增编译目标**：需修改 `arch/arm64/boot/dts/rockchip/Makefile`，添加对应的 `.dtb` 编译条目。
> - `scripts/dtc/include-prefixes/` 下的 DTS 与 `arch/` 下内容完全相同（软链接关系），下方不再重复列出。
>
> 以下 DTS 文件基础路径均为 `arch/arm64/boot/dts/rockchip/`。

### 需要移植的文件

#### DTS — Makefile

| 序号 | 目录/文件 | 理由 |
|------|----------|------|
| 1 | `arch/arm64/boot/dts/rockchip/Makefile` | 将 ATK DTS 编译目标加入 Makefile |

#### DTS — RK3568 正点原子（8 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `rk3568-atk-evb1-ddr4-v10.dts` | 正点原子 RK3568 开发板主 DTS |
| 2 | `rk3568-atk-evb1-ddr4-v10.dtsi` | 正点原子 RK3568 开发板公共配置 |
| 3 | `rk3568-atk-evb1-mipi-dsi-1080p.dts` | ATK RK3568 + MIPI DSI 1080P 屏 |
| 4 | `rk3568-atk-evb1-mipi-dsi-10p1_800x1280.dts` | ATK RK3568 + 10.1" 800×1280 屏 |
| 5 | `rk3568-atk-evb1-mipi-dsi-720p.dts` | ATK RK3568 + MIPI DSI 720P 屏 |
| 6 | `rk3568-atk-evb1-non-mipi.dts` | ATK RK3568 无屏配置 |
| 7 | `rk3568-lcds.dtsi` | ATK RK3568 LCD 参数配置 |
| 8 | `rk3568-screen_choose.dtsi` | ATK RK3568 屏幕选择配置 |

#### DTS — RK3588 正点原子（9 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `rk3588-atk-evb7-lp4-v10.dts` | 正点原子 RK3588 开发板主 DTS |
| 2 | `rk3588-atk-evb7-lp4.dtsi` | 正点原子 RK3588 开发板公共配置 |
| 3 | `rk3588-atk-cameras.dtsi` | ATK RK3588 摄像头配置 |
| 4 | `rk3588-atk-lcds.dtsi` | ATK RK3588 LCD 参数配置 |
| 5 | `rk3588-atk-mipi-10p1_800x1280.dts` | ATK RK3588 + 10.1" 800×1280 MIPI 屏 |
| 6 | `rk3588-atk-mipi-5p5_1080x1920.dts` | ATK RK3588 + 5.5" 1080×1920 MIPI 屏 |
| 7 | `rk3588-atk-mipi-5p5_720x1280.dts` | ATK RK3588 + 5.5" 720×1280 MIPI 屏 |
| 8 | `rk3588-atk-non-mipi.dts` | ATK RK3588 无屏配置 |
| 9 | `rk3588-atk-screen_choose.dtsi` | ATK RK3588 屏幕选择配置 |

#### DTS — RK3588S ATK 公共配置（3 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `rk3588s-atk-camera.dtsi` | ATK RK3588S 摄像头配置 |
| 2 | `rk3588s-atk-lcds.dtsi` | ATK RK3588S LCD 参数配置 |
| 3 | `rk3588s-atk-screen_choose.dtsi` | ATK RK3588S 屏幕选择配置 |

#### DTS — RK3588S QuarkPi CA2（6 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `rk3588s-atk-quarkpi-ca2.dts` | 正点原子 QuarkPi CA2 主 DTS |
| 2 | `rk3588s-atk-quarkpi-ca2.dtsi` | QuarkPi CA2 公共配置 |
| 3 | `rk3588s-atk-quarkpi-ca2-mipi-10p1_800x1280.dts` | QuarkPi CA2 + 10.1" MIPI 屏 |
| 4 | `rk3588s-atk-quarkpi-ca2-mipi-5p5_1080x1920.dts` | QuarkPi CA2 + 5.5" 1080×1920 屏 |
| 5 | `rk3588s-atk-quarkpi-ca2-mipi-5p5_720x1280.dts` | QuarkPi CA2 + 5.5" 720×1280 屏 |
| 6 | `rk3588s-atk-quarkpi-ca2-non-mipi.dts` | QuarkPi CA2 无屏配置 |

#### Kernel 配置文件 — 需移植（10 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `kernel/configs/android-13-go.config` | Android 13 Go 版配置 fragment，旧版本残留 |
| 2 | `kernel/configs/android-13.config` | Android 13 配置 fragment，旧版本残留 |
| 3 | `kernel/configs/atk_dlrk3568.config` | ATK 正点原子 RK3568 defconfig fragment |
| 4 | `kernel/configs/atk_dlrk3588.config` | ATK 正点原子 RK3588 defconfig fragment |
| 5 | `kernel/configs/atk_quarkpi_ca2.config` | ATK 正点原子 QuarkPi CA2 defconfig fragment |
| 6 | `kernel/configs/non_debuggable.config` | Android 不可调试配置，旧版本残留 |
| 7 | `kernel/configs/pcie_wifi.config` | PCIe Wi-Fi 模块配置 |
| 8 | `kernel/configs/rk3326.config` | Rockchip 新基线已移除（旧芯片） |
| 9 | `kernel/configs/rk3399.config` | Rockchip 新基线已移除 |
| 10 | `kernel/configs/rk356x.config` | RK356x 通用配置，ALIENTEK 独有 |

#### 构建脚本（3 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `kernel_build.sh` | ALIENTEK 独有 — Kernel 通用构建脚本（`make ARCH=arm64` 标准编译） |
| 2 | `kernel_build_atk.sh` | ATK 正点原子定制 — 定义三个目标板级构建配置（ATK_DLRK3568 / ATK_DLRK3588 / atk_quarkpi_ca2），含 CROSS_COMPILE、DTB 名称、内核模块安装路径 |
| 3 | `make.sh` | ALIENTEK 独有 — 快速构建入口，调用 `kernel_build.sh` 或 `kernel_build_atk.sh` |

#### Logo（2 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `logo.bmp` | 开机 Logo 图片。Rockchip 基线为官方 Logo，ALIENTEK 为正点原子定制 Logo。**需替换成自己的** |
| 2 | `logo_kernel.bmp` | 内核 Logo 图片。同上。**需替换成自己的** |

### 无需移植 — 文件

> 以下文件在 Rockchip 与 ALIENTEK 之间存在内容差异，但均不需要向 ALIENTEK 侧反向移植。

#### 根目录文件（5 项）

| 序号 | 文件 | 差异说明 |
|------|------|----------|
| 1 | `.find-ignore` | 仅 ALIENTEK 存在，内容为空。空文件无实际排除规则，不影响代码功能 |
| 2 | `BUILD.bazel` | 仅 ALIENTEK 存在。Android GKI 构建系统（Kleaf/Bazel）配置文件，定义 `kernel_aarch64` 等构建目标，属于 Android 构建基础设施 |
| 3 | `MAINTAINERS` | 内容差异。Rockchip 版本（5.10.252）与 ALIENTEK 版本（5.10.157）在维护者邮箱、reviewer 更新、ALIENTEK 独有 DECnet/ARM FF-A/rtl8712 条目等方面不同。Rockchip 版本整体更新 |
| 4 | `Makefile` | SUBLEVEL=252 vs 157（Rockchip 领先 ~95 个稳定版）。Rockchip 采用内联 Clang 配置，ALIENTEK 委托给 `scripts/Makefile.clang` 和 `scripts/Makefile.compiler` |
| 5 | `build.config*` (14 项) | Android GKI 内核构建配置文件。Rockchip 新增 `fips140_eval_testing`，ALIENTEK 独有 `constants`/`rockpi4`，其余为版本演进。仅 Android 构建流程使用，不参与内核编译 |

#### arch/arm64/configs/（17 项）

| 序号 | 文件 | 差异说明 |
|------|------|----------|
| 1 | `db845c_gki.fragment` | Qualcomm DragonBoard 845c GKI fragment，上游更新 |
| 2 | `fips140_gki_eval_testing.fragment` | Rockchip 新增 FIPS 140 评估测试配置 |
| 3 | `gki_defconfig` | GKI 通用 defconfig，上游更新 |
| 4 | `hikey960_gki.fragment` | HiKey960 GKI fragment，上游更新 |
| 5 | `partybox_tiny.config` | Rockchip 新增 PartyBox 小型化配置 |
| 6 | `px30_linux_defconfig` | Rockchip PX30 Linux 配置更新 |
| 7 | `rk3308_linux_defconfig` | Rockchip RK3308 Linux 配置更新 |
| 8 | `rk3308_rkpartybox.config` | Rockchip 新增 PartyBox 配置 |
| 9 | `rk3308bs_mipi_display.config` | RK3308B MIPI 显示配置更新 |
| 10 | `rockchip_defconfig` | Rockchip 通用 defconfig 更新 |
| 11 | `rockchip_gki.config` | Rockchip GKI 配置更新 |
| 12 | `rockchip_gki.fragment` | Rockchip GKI fragment 更新 |
| 13 | `rockchip_linux_defconfig` | Rockchip Linux defconfig 更新 |
| 14 | `rockchip_linux_pcie_ep.config` | Rockchip 新增 PCIe Endpoint 配置 |
| 15 | `rockchip_rt.config` | Rockchip 实时配置更新 |
| 16 | `rockpi4_defconfig` | Rockchip 新增（原 ALIENTEK `rockpi4_gki.fragment` 改为 defconfig） |
| 17 | `rockpi4_gki.fragment` | ALIENTEK 独有（Rockchip 新基线已改为 `rockpi4_defconfig`） |

### 无需移植 —  文档与 GKI 配置（2 项目录）

| 序号 | 目录 | 差异说明 |
|------|------|----------|
| 1 | `Documentation/` (153 项) | 全部为文档差异，不参与内核编译。Rockchip 新增 CPU 漏洞文档（GDS/RFDS/SRSO/VMScape）、芯片 DT binding 文档（rv1103b-cru, rkx110_x120, rk3562_can 等）；ALIENTEK 独有 google,s2mpu.yaml, rockchip-cpu-avs.txt, decnet.rst 等。均属各自独立演进 |
| 2 | `android/` (32 项) | 全部为 GKI ABI 符号列表及模块配置文件。Rockchip 为更多厂商维护了额外 ABI 兼容列表；ALIENTEK 独有 `abi_gki_modules_exports/protected` 和 `gki_system_dlkm_modules`。不应互相移植 |

### 无需移植 — 通用内核子系统

> 以下目录全部为上游 Linux 5.10.y 稳定版 backport，无 Rockchip 或 ALIENTEK 平台定制。

#### 内存与存储

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 1 | `mm/` | 85 | 内存管理（alloc/cma/compaction/filemap/hugepages/ksm/memcontrol/memory-failure/migrate/mlock/mmap/oom/page_alloc/percpu/shmem/slab/swap/truncate/vmscan/zswap） |
| 2 | `fs/` | 592 | VFS 及各文件系统（btrfs/ceph/cifs/erofs/ext4/f2fs/fuse/nfs/overlayfs/proc/pstore/squashfs/ubifs/xfs 等） |
| 3 | `block/` | 43 | 通用块层 I/O 子系统（blk-mq/bfq/bio 等） |
| 4 | `io_uring/` | 3 | 异步 I/O 框架 |

#### 内核核心

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 5 | `kernel/` | 215 | 内核核心（bpf/cgroup/sched/signal/smp/sysctl/time/timer/trace/workqueue 等）。ALIENTEK 独有 `bpf_fuse.c` 为上游 5.10.157 残留，Rockchip 已移除 |
| 6 | `init/` | 6 | 内核初始化（main.c/calibrate.c/do_mounts） |
| 7 | `ipc/` | 3 | System V IPC（信号量/消息队列/共享内存） |
| 8 | `lib/` | 68 | 基础库（crypto/decompress/dim/dma/kunit/lz4/lzo/math/mpi/raid/xz/zlib/zstd） |

#### 网络、安全与音频

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 9 | `net/` | 699 | 网络协议栈（IPv4/IPv6/TCP/UDP/SCTP/netfilter/bridge/vlan/wireless/sunrpc 等）。路径中 "RK" 为仓库名误匹配，实际 0 项 Rockchip 相关差异 |
| 10 | `security/` | 59 | 安全子系统（SELinux/apparmor/tomoyo/integrity/keys/lsm/landlock） |
| 11 | `sound/` (通用) | 290 | ALSA 核心 + 各平台 ASoC 驱动（Intel/Mediatek/Qualcomm/Samsung 等平台 codec/机器驱动）。Rockchip 音频驱动独立在后面的表格 |

#### 构建、工具与虚拟化

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 12 | `scripts/` | 332 | 内核构建系统（Kbuild/Makefile.*/modpost/link-vmlinux/checkpatch 等） |
| 13 | `tools/` | 305 | 内核工具链（perf/bpf/cgroup/counter/crypto/gpio/iio/kvm/pci/pmu/power/testing/usb 等） |
| 14 | `samples/` | 14 | 内核示例代码（bpf/connector/fanotify/kdb/kfifo/kobject/kprobes/mei/pktgen/rpmsg/uhid/v4l/vfio-mdev） |
| 15 | `usr/` | 2 | initramfs 生成工具（gen_initramfs.sh + Kconfig） |
| 16 | `virt/` | 4 | KVM 虚拟化基础代码 |

#### 头文件

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 17 | `include/` (通用) | 682 | `linux/` 327 + `trace/` 97 + `uapi/` 90 + `net/` 74 + `dt-bindings/` 7 + `drm/` 7 + `soc/` 3 + `asm-generic/` 11 + `media/` 10 + `sound/` 8 + `scsi/` 7 + `acpi/` 3 + `crypto/` 3 + `kvm/` 3 + `rdma/` 3 + `xen/` 3 等。上游 backport |
| 18 | `include/dt-bindings/` | 9 | Rockchip DT 绑定头文件（clock/display/mfd/soc/suspend）。Rockchip 新增 RV1103B CRU/serdes/CSU/suspend 等宏定义。**不需要 patch** |
| 19 | `include/linux/` (RK) | 8 | Rockchip 平台头文件（rk630/rk806/rockchip_sip/rockchip_pm_config/pwm-rockchip/thunderboot 等）。**不需要 patch** |
| 20 | `include/soc/rockchip/` | 10 | Rockchip SoC 基础头文件（pm_domains/minidump/amp/csu/dmc/dvbm/opp_select/rockit/sip/system_monitor）。**不需要 patch** |
| 21 | `include/uapi/` (RK) | 4 | Rockchip 用户空间 API（rockchip_drm/rk_cryptodev/rk_hdmirx_config/rk_vcm_head）。**不需要 patch** |

### 无需移植 — arch/ 非 Rockchip 架构

> 全部为上游 5.10.y 稳定版 backport，无 Rockchip 平台定制。

| 序号 | 目录 | 说明 |
|------|------|------|
| 1 | `arch/alpha/` | DEC Alpha |
| 2 | `arch/arc/` | Synopsys ARC |
| 3 | `arch/arm/` | ARM32（Rockchip 为旧款芯片保留，ALIENTEK 仅编译 ARM64 不使用） |
| 4 | `arch/arm64/boot/dts/allwinner/` | 全志 ARM64 DTS |
| 5 | `arch/arm64/boot/dts/altera/` | Intel/Altera ARM64 DTS |
| 6 | `arch/arm64/boot/dts/amlogic/` | Amlogic ARM64 DTS |
| 7 | `arch/arm64/boot/dts/freescale/` | NXP i.MX8 ARM64 DTS |
| 8 | `arch/arm64/boot/dts/hisilicon/` | 海思 ARM64 DTS |
| 9 | `arch/arm64/boot/dts/marvell/` | Marvell ARM64 DTS |
| 10 | `arch/arm64/boot/dts/mediatek/` | 联发科 ARM64 DTS |
| 11 | `arch/arm64/boot/dts/microchip/` | Microchip ARM64 DTS |
| 12 | `arch/arm64/boot/dts/nvidia/` | NVIDIA Tegra ARM64 DTS |
| 13 | `arch/arm64/boot/dts/qcom/` | 高通 ARM64 DTS |
| 14 | `arch/arm64/boot/dts/renesas/` | 瑞萨 ARM64 DTS |
| 15 | `arch/arm64/boot/dts/ti/` | TI 德州仪器 ARM64 DTS |
| 16 | `arch/arm64/include/asm/` | ARM64 汇编头文件 |
| 17 | `arch/arm64/include/uapi/` | ARM64 用户空间 API 头文件 |
| 18 | `arch/arm64/kernel/` | ARM64 内核核心代码 |
| 19 | `arch/arm64/kvm/` | ARM64 KVM 虚拟化 |
| 20 | `arch/arm64/lib/` | ARM64 库函数 |
| 21 | `arch/arm64/mm/` | ARM64 内存管理 |
| 22 | `arch/arm64/net/` | ARM64 BPF JIT 等网络相关 |
| 23 | `arch/arm64/xen/` | ARM64 Xen 虚拟化 |
| 24 | `arch/csky/` | C-SKY |
| 25 | `arch/h8300/` | Renesas H8/300 |
| 26 | `arch/hexagon/` | Qualcomm Hexagon |
| 27 | `arch/ia64/` | Intel Itanium |
| 28 | `arch/m68k/` | Motorola 68000 |
| 29 | `arch/microblaze/` | Xilinx MicroBlaze |
| 30 | `arch/mips/` | MIPS |
| 31 | `arch/nds32/` | Andes NDS32 |
| 32 | `arch/nios2/` | Altera Nios II |
| 33 | `arch/openrisc/` | OpenRISC |
| 34 | `arch/parisc/` | HP PA-RISC |
| 35 | `arch/powerpc/` | PowerPC |
| 36 | `arch/riscv/` | RISC-V |
| 37 | `arch/s390/` | IBM S/390 |
| 38 | `arch/sh/` | SuperH |
| 39 | `arch/sparc/` | SPARC |
| 40 | `arch/um/` | User Mode Linux |
| 41 | `arch/x86/` | x86/x86_64 |
| 42 | `arch/xtensa/` | Tensilica Xtensa |

### 无需移植 — drivers/ 非 Rockchip 平台驱动

> 以下驱动均与 Rockchip 平台无关，全部差异来自上游 5.10.y 稳定版 backport。

| 序号 | 目录 | 项数 | 说明 |
|------|------|------|------|
| 1 | `drivers/accessibility/` | 2 | speakup 盲人辅助子系统 |
| 2 | `drivers/acpi/` | 60 | ACPI 子系统（acpica/apei/arm64 等）。RK3588 使用 Device Tree 而非 ACPI |
| 3 | `drivers/amba/` | 2 | AMBA 总线核心 + NVIDIA Tegra AHB |
| 4 | `drivers/android/` | 8 | Android GKI 相关（binder/binderfs/vendor_hooks 等） |
| 5 | `drivers/ata/` | 27 | AHCI/libata 子系统 + 各平台 SATA 控制器 |
| 6 | `drivers/atm/` | 6 | ATM 异步传输模式（已淘汰） |
| 7 | `drivers/auxdisplay/` | 1 | arm-charlcd 辅助显示 |
| 8 | `drivers/base/` | 38 | 驱动核心层（驱动模型/电源管理/regmap/firmware_loader/Mali 辅助） |
| 9 | `drivers/block/` | 30 | 块设备驱动（null_blk/loop/nbd/rbd/zram/virtio_blk/drbd/rnbd/xen-blk 等） |
| 10 | `drivers/bluetooth/` | 21 | 蓝牙子系统（Realtek/QCA/Intel/MTK 等芯片 HCI 驱动） |
| 11 | `drivers/bus/` | 14 | 总线子系统（MHI host/FSL MC/IMX WEIM/Sunxi RSB/TI SYSC 等） |
| 12 | `drivers/char/` | 42 | 字符设备（TPM 18/IPMI 6/hw_random 12/其他 6） |
| 13 | `drivers/clk/` (通用) | 108 | 通用时钟框架 + 各平台 clk 驱动（at91/bcm/imx/mediatek/meson/qcom/samsung/sunxi/tegra/ti/zynq 等） |
| 14 | `drivers/clocksource/` | 19 | 各平台计时器驱动（arm_arch_timer/hyperv/mips/qcom/riscv/ti 等） |
| 15 | `drivers/counter/` | 4 | 计数器子系统（microchip/stm32/ti） |
| 16 | `drivers/cpufreq/` (通用) | 26 | 各平台 cpufreq 驱动（acpi/amd/armada/imx/qcom/tegra/ti 等） |
| 17 | `drivers/cpuidle/` | 5 | CPU 空闲子系统（PSCI 域/PowerPC/dt 等） |
| 18 | `drivers/crypto/` (通用) | 84 | 各平台加密驱动（allwinner/cavium/hisilicon/marvell/qat/stm32/virtio 等） |
| 19 | `drivers/dax/` | 3 | 直接访问存储 |
| 20 | `drivers/devfreq/devfreq.c` | 1 | Devfreq 核心框架 |
| 21 | `drivers/devfreq/governor_userspace.c` | 1 | Userspace governor |
| 22 | `drivers/dio/` | 1 | HP DIO 总线（遗留设备） |
| 23 | `drivers/dma/` (通用) | 45 | DMA 引擎子系统（dw/pl330/imx-sdma/qcom/ti/xilinx 等平台） |
| 24 | `drivers/edac/` (通用) | 21 | EDAC 内存纠错（alter/bluefield/intel/qcom/thunderx 等） |
| 25 | `drivers/extcon/` | 3 | 外部连接器子系统 |
| 26 | `drivers/firewire/` | 5 | IEEE 1394 FireWire（RK3588 无此接口） |
| 27 | `drivers/firmware/` (通用) | 50 | ARM SCMI/SCPI/SDEI/EFI/PSCI/SMCCC/QCOM SCM/imx SCU/tegra BPMP/ti SCI 等 |
| 28 | `drivers/fpga/` | 8 | FPGA 管理框架（Intel Altera/Xilinx） |
| 29 | `drivers/fsi/` | 3 | IBM FSI 总线（IBM POWER 平台） |
| 30 | `drivers/gpio/` (通用) | 36 | GPIO 子系统（gpiolib + 各平台 gpio 驱动） |
| 31 | `drivers/gpu/` (通用) | 929 | DRM 核心框架 + ARM Mali 通用驱动 + NVIDIA Host1x + Renesas IPU。非 Rockchip 部分均为上游 backport |
| 32 | `drivers/greybus/` | 1 | Google Greybus |
| 33 | `drivers/hid/` | 46 | HID 人机接口设备 |
| 34 | `drivers/hsi/` | 2 | 高速同步串行接口（TI OMAP/Nokia） |
| 35 | `drivers/hv/` | 9 | Microsoft Hyper-V（仅 x86） |
| 36 | `drivers/hwmon/` | 63 | 硬件监控（acpi/pmbus/aspeed/ina2xx/jc42/nct6775 等各平台传感器） |
| 37 | `drivers/hwtracing/` | 24 | CoreSight 调试追踪 + Mali GPU CoreSight 集成 + Intel TH + STM |
| 38 | `drivers/i2c/` (通用) | 52 | I²C 子系统（designware/imx/omap/qcom/stm32 等平台 busses + core） |
| 39 | `drivers/i3c/` | 2 | I3C 总线（Cadence master） |
| 40 | `drivers/idle/` | 1 | Intel 空闲驱动（仅 x86） |
| 41 | `drivers/iio/` (通用) | 115 | IIO 子系统（accel/adc/gyro/imu 等各平台传感器） |
| 42 | `drivers/infiniband/` | 130 | InfiniBand/RDMA（Broadcom/Chelsio/Intel/Mellanox/软 RoCE 等） |
| 43 | `drivers/input/` (通用) | 131 | 输入子系统（joystick/keyboard/misc/mouse/touchscreen/sensors 等） |
| 44 | `drivers/interconnect/` | 6 | 互连子系统（Qualcomm 专用） |
| 45 | `drivers/iommu/` (通用) | 23 | IOMMU 子系统（arm-smmu/intel/amd/qcom 等） |
| 46 | `drivers/irqchip/` | 33 | 中断控制器（ARM GIC + 各平台 irqchip） |
| 47 | `drivers/isdn/` | 8 | ISDN 数字电话网（已淘汰） |
| 48 | `drivers/leds/` | 18 | LED 子系统（aw2013/lp50xx/pwm 等驱动 + 触发器） |
| 49 | `drivers/macintosh/` | 10 | Apple Macintosh 硬件（PowerPC/Apple 平台） |
| 50 | `drivers/mailbox/` (通用) | 10 | Mailbox 子系统（bcm/imx/ti/zynqmp 等） |
| 51 | `drivers/mcb/` | 4 | MEN Chameleon Bus（工业控制总线） |
| 52 | `drivers/md/` | 55 | MD/Device Mapper（bcache/dm-cache/dm-crypt/dm-raid/dm-thin/dm-verity 等） |
| 53 | `drivers/media/` (通用) | 423 | V4L2/DVB/RC 通用层 + PCI/USB/SPI 视频采集 + 各平台 media 驱动（exynos/mtk/omap/qcom/sunxi/ti 等） + 非 Rockchip I²C 传感器（imx/ov/gc/sc 等） |
| 54 | `drivers/memory/` | 5 | 内存控制器（Atmel/Broadcom/Marvell/Samsung/ST） |
| 55 | `drivers/memstick/` | 3 | MemoryStick 存储卡驱动 |
| 56 | `drivers/message/` | 2 | LSI/Broadcom Fusion MPT |
| 57 | `drivers/mfd/` (通用) | 29 | MFD 多功能芯片（arizona/exynos/intel/max/omap/stmpe 等） |
| 58 | `drivers/misc/` (通用) | 38 | 杂项驱动（cxl/eeprom/fastrpc/genwqe/mei/ocxl/sram/uacce/vmw 等） |
| 59 | `drivers/mmc/` (通用) | 67 | MMC/SD/SDIO 子系统（core + dw_mmc/sdhci/sunxi 等各平台 host 驱动） |
| 60 | `drivers/most/` | 2 | Microchip MOST 车载多媒体总线 |
| 61 | `drivers/mtd/` (通用) | 97 | MTD 子系统（chips/devices/nand/spi-nand/spi-nor/ubi 等） |
| 62 | `drivers/net/` (通用) | 906 | 网络子系统（Intel/Broadcom/Marvell/NXP/Qualcomm/Realtek 等 ethernet + Atheros/Intel/Mediatek/Realtek 等 wireless + can/phy 等） |
| 63 | `drivers/nfc/` | 10 | NFC 近场通信（nxp/st 等） |
| 64 | `drivers/ntb/` | 8 | 非透明桥（x86 服务器平台） |
| 65 | `drivers/nubus/` | 1 | Apple NuBus |
| 66 | `drivers/nvdimm/` | 8 | 持久内存框架 |
| 67 | `drivers/nvme/` | 22 | NVMe（host + target） |
| 68 | `drivers/nvmem/` (通用) | 6 | NVMEM 子系统（imx-ocotp/meson-efuse/qcom 等） |
| 69 | `drivers/of/` | 11 | DT 核心框架。RK 平台重度依赖 DT，差异为上游 backport |
| 70 | `drivers/opp/` | 2 | OPP 频率电压框架（core + debugfs） |
| 71 | `drivers/parisc/` | 4 | HP PA-RISC 平台 |
| 72 | `drivers/parport/` | 3 | 并行端口 |
| 73 | `drivers/pci/` (通用) | 62 | PCI/PCIe 子系统（controller/endpoint/hotplug/pcie 等各平台） |
| 74 | `drivers/pcmcia/` | 6 | PCMCIA/CardBus（已淘汰） |
| 75 | `drivers/perf/` | 6 | ARM PMU 性能计数器（arm-cmn/arm_dsu/arm_smmuv3/fsl_imx8） |
| 76 | `drivers/phy/` (通用) | 30 | 各平台 PHY 驱动（Broadcom/Cadence/Qualcomm/Samsung/ST/Tegra/TI 等） |
| 77 | `drivers/pinctrl/` (通用) | 44 | 各平台 pin control（ASpeed/BCM/Intel/Mediatek/Meson/QCOM/Sunxi/Tegra 等） |
| 78 | `drivers/platform/` | 47 | 平台设备（Chrome OS EC 13/Mellanox BlueField 3/x86 笔记本 26/Microsoft Surface 等） |
| 79 | `drivers/pnp/` | 2 | 即插即用（core + pnpacpi） |
| 80 | `drivers/power/` + `powercap/` (通用) | 39 | power/reset + power/supply 32（axp20x/bq/cw2015/gpio/max/sbs 等）+ powercap 4 |
| 81 | `drivers/pps/` | 7 | 脉冲信号子系统 |
| 82 | `drivers/ptp/` | 11 | PTP 时钟（chardev/qoriq + ptp_kvm 重组） |
| 83 | `drivers/pwm/` (通用) | 26 | PWM 子系统（bcm/imx/mediatek/meson/stm32/tegra/ti 等各平台） |
| 84 | `drivers/rapidio/` | 4 | RapidIO 互连 |
| 85 | `drivers/regulator/` (通用) | 17 | regulator 框架 + 各厂商芯片（fan53555/gpio/max/mtk/slg51000 等） |
| 86 | `drivers/remoteproc/` | 11 | 远程处理器框架（imx/mtk/qcom/stm32/ti 等） |
| 87 | `drivers/reset/` | 4 | 重置控制器（hisilicon/berlin 等） |
| 88 | `drivers/rpmsg/` (通用) | 8 | RPMSG 框架（qcom/virtio 等） |
| 89 | `drivers/rtc/` (通用) | 30 | RTC 子系统（ds1307/hym8563/pcf8563/sun6i 等各芯片驱动） |
| 90 | `drivers/s390/` | 36 | IBM S/390 大型机驱动（dasd/sclp/cio/crypto/net/zfcp） |
| 91 | `drivers/scsi/` | 165 | SCSI 子系统（核心 + aacraid/lpfc/megaraid/mpt3sas/qla2xxx 等 HBA + UFS） |
| 92 | `drivers/sh/` | 2 | SuperH 平台（clk/intc） |
| 93 | `drivers/slimbus/` | 3 | SLIMbus 音频总线 |
| 94 | `drivers/soc/` (通用) | 45 | 各平台 SoC 基础设施（Amlogic/FSL/IMX/MediaTek/Qualcomm/Samsung/Tegra/TI/UX500/Xilinx） |
| 95 | `drivers/soundwire/` | 4 | SoundWire 音频总线 |
| 96 | `drivers/spi/` (通用) | 38 | SPI 子系统（cadence/dw/fsl/geni/qcom/stm32/sun4i/xilinx 等） |
| 97 | `drivers/spmi/` | 1 | SPMI 电源管理接口 |
| 98 | `drivers/ssb/` | 1 | Sonics Silicon Backplane（Broadcom） |
| 99 | `drivers/staging/` (通用) | 73 | staging 驱动（android/comedi/greybus/iio/atomisp/rtl 等）。ALIENTEK 独有 `rtl8712/` 为旧 Wi-Fi 驱动残留 |
| 100 | `drivers/target/` | 17 | SCSI Target 子系统（iscsi/target_core/loopback 等） |
| 101 | `drivers/tee/` | 9 | 可信执行环境（AMD-TEE + OP-TEE + tee_core） |
| 102 | `drivers/thermal/` (通用) | 18 | 热管理框架（cpufreq_cooling/gov_power_allocator/intel/qcom/sun8i 等） |
| 103 | `drivers/thunderbolt/` | 10 | Intel Thunderbolt（x86 平台） |
| 104 | `drivers/tty/` (通用) | 66 | TTY/串口子系统（核心 + 8250 + amba-pl011/atmel/fsl/imx/meson/samsung/tegra 等 + vt） |
| 105 | `drivers/uio/` | 3 | 用户空间 I/O |
| 106 | `drivers/usb/` (通用) | 215 | USB 子系统（核心 + DWC2/DWC3/cdns3/chipidea/EHCI/OHCI/UHCI/xHCI + Gadget + musb + serial + storage + Type-C/PD 等） |
| 107 | `drivers/vdpa/` | 2 | vDPA 数据路径加速 |
| 108 | `drivers/vfio/` | 9 | VFIO 设备直通 |
| 109 | `drivers/vhost/` | 7 | vhost 虚拟化后端 |
| 110 | `drivers/video/` (通用) | 73 | 视频子系统非 Rockchip 部分（背光驱动 + 控制台 + fbdev 各平台驱动 + of_display_timing） |
| 111 | `drivers/virtio/` | 7 | virtio 半虚拟化（balloon/mmio/pci/ring/vdpa） |
| 112 | `drivers/vme/` | 2 | VME 总线 |
| 113 | `drivers/w1/` | 3 | 1-Wire 总线 |
| 114 | `drivers/watchdog/` | 22 | 看门狗子系统（sbsa_gwdt + at91/bcm/dw/imx/mtk/stm32 等各平台） |
| 115 | `drivers/xen/` | 19 | Xen 虚拟化（events/gntdev/pciback/xenbus 等 + Rockchip 新增 `arm/` 目录） |

### 无需移植 — drivers/ Rockchip 平台驱动

> 以下为 Rockchip 平台专属驱动。全部差异为 Rockchip 后续正向演进（bug 修复、新芯片支持、驱动重构），
> ALIENTEK 为旧版，**一律不需要 patch**。按功能领域分组如下。

#### 时钟 — `drivers/clk/rockchip/`（22 项）

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `Kconfig` | 新增 `CLK_RV1103B`、`ROCKCHIP_CLK_PVTPLL` 配置项 |
| 2 | `Makefile` | 新增 `clk-fractional-divider-v2.o`、`clk-pvtpll.o`、`clk-rv1103b.o` |
| 3 | `clk-fractional-divider-v2.c` | Rockchip 新增，347 行 fractional divider v2，支持高低位寄存器分离 |
| 4 | `clk-out.c` | `CLK_IGNORE_UNUSED` 改为 DT 属性 `rockchip,clk-ignore-unused` 可配置 |
| 5 | `clk-pll.c` | Bug 修复 ① PLL 小数分频计算修复（`frac_c` 中间变量）；② `err_pll` 路径 `kfree(pll->rate_table)` 内存泄漏修复 |
| 6 | `clk-pvtpll.c` | Rockchip 新增，679 行 PVTPLL 校准驱动 |
| 7 | `clk-px30.c` | usb480m 加 `CLK_IS_CRITICAL`；dclk_vop 移除不当 `CLK_SET_RATE_PARENT`；时钟 ID 修正 |
| 8 | `clk-rk3228.c` | DCLK_VOP 加 `CLK_SET_RATE_PARENT` `CLK_SET_RATE_NO_REPARENT` |
| 9 | `clk-rk3328.c` | USB3 OTG 参考时钟名修正 `clk_usb3otg_ref` → `clk_ref_usb3otg_src` |
| 10 | `clk-rk3399.c` | SCLK_CIF_OUT 加 `CLK_SET_RATE_PARENT` |
| 11 | `clk-rk3562.c` | DPLL 加 `CLK_IS_CRITICAL`；uart3_frac 父时钟修正；移除 `CLK_OTPC_ARB`；dclk_vop 修正 |
| 12 | `clk-rk3568.c` | DCLK_VOP0/1/2 统一使用 `CLK_SET_RATE_NO_REPARENT`（防止显示异常） |
| 13 | `clk-rk3588.c` | ⚠️ **关键修复** ① 移除 `CLK_OTPC_ARB` 门控；② DCLK_VOP_SRC 改为 `CLK_SET_RATE_NO_REPARENT`；③ 新增 `protect_clocks[]` 保护 PWM1~3 + VOP 时钟；④ 调用 `rockchip_clk_protect()` |
| 14 | `clk-rv1103b.c` | Rockchip 新增，790 行 RV1103B 芯片时钟驱动 |
| 15 | `clk-rv1106.c` | 新增 `sclk_ddr` factor 时钟；移除 3 个多余门控；PVTPLL 校准算法优化 |
| 16 | `clk.c` | 新增 `fractional_divider_v2` 分支；`rate=0`/`parent_rate=0` 安全防护；MODULE 模式 hlist ctx；`rockchip_clk_disable_unused()` |
| 17 | `clk.h` | 新增 RV1103B ~50 行寄存器基址；`branch_fraction_divider_v2` 枚举；`COMPOSITE_FRAC_V2` 宏；`rockchip_pvtpll_volt_sel_adjust()`/`rockchip_clk_disable_unused()` 声明 |
| 18 | `regmap/Kconfig` | 移除 `CLK_RK628`（RK628 时钟驱动已从新基线移除） |
| 19 | `regmap/Makefile` | 移除 `clk-rk628.o` |
| 20 | `regmap/clk-regmap-fractional-divider.c` | `rate=0` 安全返回 |
| 21 | `regmap/clk-regmap.h` | 移除未使用的 `COMPOSITE_NOMUX`/`COMPOSITE_FRAC_NOMUX` 宏 |
| 22 | `regmap/clk-rk628.c` | 仅 ALIENTEK 存在（609 行）。Rockchip 已移除，属有意清理 |

#### 显示/GPU/视频 — DRM / Mali / Video（~200 项）

| 序号 | 文件/目录 | 差异摘要 |
|------|----------|----------|
| 1 | `drivers/gpu/arm/bifrost/platform/rk/mali_kbase_config_rk.c` | `pm_ptr()` 替代 `#ifdef CONFIG_PM`；新增 `customer_demand` NVmem 读取 |
| 2 | `drivers/gpu/arm/mali400/mali/platform/rk/rk.c` | `#ifdef CONFIG_PM` 后移到函数前 |
| 3 | `drivers/gpu/arm/midgard/platform/rk/mali_kbase_config_rk.c` | 同 bifrost，`pm_ptr()` 替代 |
| 4 | `drivers/gpu/drm/rockchip/` (35) | DRM 驱动重大更新：新增 `rockchip_drm_clk.c`（DRM 时钟管理）、`rockchip_drm_trace.h`（DRM 追踪点）；移除 `rk628/` 目录；VOP2 寄存器配置大量更新；`rockchip_drm_drv.c` 引入 kernel thread + DRM GEM framebuffer helper + trace |
| 5 | `drivers/video/rockchip/` (61) | 视频子系统完整驱动集合：DVBM 3 + MPP 22（AV1/RKVdec2/VDPU/VEPU/IEP 编解码器）+ RGA2/RGA3 28（2D 加速器）+ RVE 4（视频增强）+ vehicle 3 + vtunnel 1。Rockchip 后续新增 AV1 解码、RKVdec2 多核调度、RGA fence/dma-buf 等 |

#### 多媒体 — Media / Staging Media

| 序号 | 文件/目录 | 差异摘要 |
|------|----------|----------|
| 1 | `drivers/media/i2c/rk628/` (19) | RK628 HDMI 转 CSI/DSI 桥接芯片驱动。Rockchip 新增 rk628_mipi_dphy.c、rk628_post_process.c/h |
| 2 | `drivers/media/i2c/rkserdes/` (1) | Rockchip SerDes 驱动目录（新增） |
| 3 | `drivers/media/platform/rockchip/` (78) | CIF 17 + HDMI 接收 5 + ISP 54（V33 ISP 支持/bridge/capture/params/stats 重构） |
| 4 | `drivers/staging/media/rkisp1/rkisp1-dev.c` | Bayer 格式转换 + 多流捕获 |
| 5 | `drivers/staging/media/rkvdec/rkvdec.c` | VP9 10-bit 解码 + H.265 缩放解码 |

#### 网络 — Ethernet / CAN / Wi-Fi / PHY

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/net/can/rockchip/` (6) | CAN FD 帧格式 + 总线错误恢复 + 休眠/唤醒优化 |
| 2 | `drivers/net/wireless/rockchip_wlan/` (3) | RTL8188EU/RTL8723BS/RTL8821CS Wi-Fi 驱动更新 |
| 3 | `drivers/net/phy/rk630phy.c` | 自动协商扩展 + Link 检测去抖 + EEE 低功耗以太网 |
| 4 | `drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c` | RK3588 多队列 TSO/GSO 卸载 + rx_clk_rgmii_delay 校准 + WoWLAN 唤醒帧过滤 |

#### PCIe（6 项）

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/pci/controller/dwc/pcie-dw-ep-rockchip.c` | BAR 动态分配 + MSI-X + Endpoint DMA 扩展 |
| 2 | `drivers/pci/controller/dwc/pcie-dw-rockchip.c` | RK3588 Gen3 x4 lane 配置 + Link 热复位恢复 + ASPM L1ss |
| 3 | `drivers/pci/controller/pcie-rockchip-ep.c` | Endpoint 驱动更新 |
| 4 | `drivers/pci/controller/pcie-rockchip-host.c` | 地址窗口分配 + INTx/MSI 中断域改进 |
| 5 | `drivers/pci/controller/pcie-rockchip.c` | PHY 初始化 + 时钟复位序列 |
| 6 | `drivers/pci/controller/pcie-rockchip.h` + `rockchip-pcie-dma.h` | 寄存器 + DMA 描述符更新 |

#### 存储 — MMC / MTD / NVMEM / rkflash

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/mmc/host/dw_mmc-rockchip.c` | HS400 增强 tuning + extcon 热插拔 + RK3588 SoC 数据 |
| 2 | `drivers/mtd/nand/raw/rockchip-nand-controller.c` | BCH ECC 按芯片可配置 + RV1103B/RK3506 compatible |
| 3 | `drivers/nvmem/rockchip-otp.c` | RK3588 OTP 分区定义及读取 API（CPU bin/leakage 等） |
| 4 | `drivers/nvmem/rk628-efuse.c` | 仅 ALIENTEK 存在。Rockchip 已迁移至 `drivers/misc/rk628/rk628_efuse.c`（架构统一） |
| 5 | `drivers/rkflash/` (7) | BBT 坏块管理 + 多片选 NAND + 各厂商页大小适配 |

#### 电源/时钟/复位 — cpufreq / devfreq / regulator / power / thermal

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/cpufreq/rockchip-cpufreq.c` | PVTPLL 功能集成：`customer_demand` NVmem + `rockchip_init_pvtpll_table()` + `rockchip_pvtpll_set_volt_sel()` |
| 2 | `drivers/devfreq/event/rockchip-dfi.c` | RK3562 DFI 专用初始化 + pmu_grf 防御性改进 |
| 3 | `drivers/devfreq/rockchip_dmc.c` | 延迟频率调节 + 深度休眠频率 + stall_time 获取（SMC）+ 内存分配错误处理改进 |
| 4 | `drivers/devfreq/rockchip_dmc_common.c` | 新增 `rockchip_dmcfreq_get_stall_time_ns()` 导出函数 |
| 5 | `drivers/regulator/rk806-regulator.c` | 输出电压档位 + 休眠模式配置 |
| 6 | `drivers/regulator/rk808-regulator.c` | DVS 斜率 + 初始电压优化 |
| 7 | `drivers/regulator/rk860x-regulator.c` | 轻载模式 + 过流保护阈值配置 |
| 8 | `drivers/power/supply/rk816_battery.c` | 充放电曲线校准 + 温度补偿 + 零电量关机阈值 |
| 9 | `drivers/power/supply/rk817_battery.c` | 同上，RK817 版本 |
| 10 | `drivers/power/supply/rk818_battery.c` | 同上，RK818 版本 |
| 11 | `drivers/power/supply/rt9455_charger.c` | 输入电流自适应 + 热调节 + 充电状态机优化 |
| 12 | `drivers/thermal/rockchip_thermal.c` | RK3588 多通道温度采集 + 临界温度关机触发 + 校准参数 |

#### I/O 外设 — I²C / SPI / GPIO / PWM / PinCtrl / DMA

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/i2c/busses/i2c-rk3x.c` | Reset 控制器支持 + SCL OE debounce + slave hold SCL 检测恢复 + 定时参数优化 + WAIT_TIMEOUT 降至 200ms + 原子性 START 保护 + polling 模式中断保护 + RV1103B SoC 数据 |
| 2 | `drivers/spi/spi-rockchip.c` | DMA 零拷贝 + CS 保持配置 |
| 3 | `drivers/spi/spi-rockchip-sfc.c` | Dual/Quad IO 时序校准 |
| 4 | `drivers/spi/spi-rockchip-slave.c` | Rockchip 新增，SPI 从模式 |
| 5 | `drivers/spi/spi-rockchip-test.c` | Rockchip 新增，SPI 环回测试 |
| 6 | `drivers/spi/spidev-rkmst.c` | 32-bit 字长 + 模式配置 |
| 7 | `drivers/spi/spidev-rkslv.c` | SPI 从模式用户空间接口更新 |
| 8 | `drivers/gpio/gpio-rockchip.c` | `GPIO_TYPE_V2_2` 版本检测 + V2 debounce 修复 + Both-edge 中断重构 + `of_node_put()` 泄漏修复 |
| 9 | `drivers/pwm/pwm-rockchip.c` | 连续/单次模式切换 + PWM 捕获模式 + 极性反转 |
| 10 | `drivers/pwm/pwm-rockchip-test.c` | Rockchip 新增，PWM 单元测试 |
| 11 | `drivers/pwm/pwm-rockchip-irq-callbacks.h` | Rockchip 新增，PWM IRQ 回调头文件 |
| 12 | `drivers/pwm/pwm-rockchip.h` | 仅 ALIENTEK 存在。Rockchip 已重构为内联结构，移除该独立头文件 |
| 13 | `drivers/pinctrl/pinctrl-rockchip.{c,h}` | RV1103B/RK3506/RK3576 引脚/驱动强度/施密特触发配置 |
| 14 | `drivers/pinctrl/pinctrl-rk628.c` | 仅 ALIENTEK 存在。Rockchip 已迁移至 `drivers/misc/rk628/rk628_pinctrl.c`（架构重构） |
| 15 | `drivers/dma/rockchip-dma.c` | Rockchip 新增，Rockchip DMA 引擎驱动 |

#### 系统基础设施 — firmware / soc / mailbox / rpmsg / hwspinlock

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/firmware/rockchip_sip.c` | PVTPLL 新功能（`sip_smc_get_pvtpll_info` / `sip_smc_pvtpll_config`） |
| 2 | `drivers/firmware/arm_ffa/` | 仅 ALIENTEK 存在。Rockchip 新基线已完全移除 ARM FF-A 驱动，属有意清理 |
| 3 | `drivers/soc/rockchip/` (34) | SoC 基础设施层：FIQ 调试器 + Vendor Storage 4 + Minidump 4 + 电源管理 3 + AMP 多核通信 5 + ThunderBoot 快启 4 + cpuinfo/debug/decompress/dmabuf_procfs/ipa/opp_select/system_monitor/csu 等 9。全部为 Rockchip 后续平台增强 |
| 4 | `drivers/mailbox/rockchip-mailbox.c` | V2 Mailbox 支持（RK3576 平台）+ 数据驱动设计重构 + `trigger_method` DT 属性 + License 更新 |
| 5 | `drivers/mailbox/rockchip-mbox-demo.c` | Rockchip 新增，138 行 mailbox demo |
| 6 | `drivers/rpmsg/rockchip_rpmsg_test.c` | 多通道并发测试 + 传输延迟测量 |
| 7 | `drivers/rpmsg/rockchip_rpmsg.c` | 仅 ALIENTEK 存在。Rockchip 已废弃，改用 mailbox 方式重构 |
| 8 | `drivers/rpmsg/rockchip_rpmsg_mbox.c` | Rockchip 新增，新版基于 mailbox 的 RPMSG |
| 9 | `drivers/rpmsg/rockchip_rpmsg_softirq.c` | Rockchip 新增，高优先级软中断消息路径 |
| 10 | `drivers/hwspinlock/rockchip_hwspinlock.c` | RV1103B/RK3506 芯片支持 + 锁超时检测 |
| 11 | `drivers/iommu/rockchip-iommu.c` | Bug 修复：`platform_get_irq()` 负值增加 `pm_runtime_disable(dev)`，修复 runtime PM 引用计数泄漏 |

#### 加密 — `drivers/crypto/rockchip/`（42 项）

> **整个 crypto 驱动架构完全重构**。
>
> **ALIENTEK 旧架构**：30+ 扁平文件，基于 tasklet 队列（rk_crypto_core/v1/v2/v3/procfs/ahash_utils/skcipher_utils/utils/bignum 等），自定义 `crypto_queue` + `spin_lock` + `tasklet_schedule`。
>
> **Rockchip 新架构**：重构为 `rkcrypto/` 子目录，使用内核标准 `crypto_engine` API + `completion` 机制，新增 `fallback` 支持，统一 V1/V2/V3 代码结构。
>
> ① Kconfig 新增 `CRYPTO_DEV_ROCKCHIP_CRYPTO`；② Makefile 从 30 行扁平 → 单行 `rkcrypto/`；③ rk3288_crypto.c 移除 ~200 行旧 tasklet 代码，替换为 `crypto_engine_alloc_init+crypto_engine_start+init_completion`；④ rk3288_crypto.h 结构体精简（移除 20+ 字段，新增 `crypto_engine`+`completion`）；⑤ rk3288_crypto_ahash.c 新增 fallback 非对齐数据支持；⑥ ALIENTEK 侧 30 个旧文件被移除。**不需要 patch**。

#### 输入/传感器 — input / IIO

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/input/remotectl/rockchip_pwm_remotectl.{c,h}` (2) | **重大重构**：PWM V4 控制器支持 + 面向对象设计（`rk_remote_pwm_data` + funcs 函数指针表）+ 代码优化 + V4 16 个 pwrkey vs V1 10 个 |
| 2 | `drivers/input/sensors/accel/sh3001_acc.c` | 仅 ALIENTEK 存在。Rockchip 已移除，旧版残留 |
| 3 | `drivers/input/sensors/gyro/sh3001_gyro.c` | 同上 |
| 4 | `drivers/iio/imu/rk_amp_imu/` | Rockchip 新增，AMP IMU 驱动 |
| 5 | `drivers/iio/adc/rockchip_saradc.c` | `mutex lock` 替代 `mlock` + `FIELD_PREP` 宏 + RV1103B 数据 |

#### 多功能芯片 / 杂项 — MFD / misc

| 序号 | 文件/目录 | 差异摘要 |
|------|----------|----------|
| 1 | `drivers/mfd/` (RK 强相关，10~11 项) | rk630/i2c+spi、rk806/core+spi+i2c（新增）、rk808、rt5033、display-serdes/、rkx110_x120/。ALIENTEK 独有 rk628.c（已移除） |
| 2 | `drivers/misc/rk628/` (38) | RK628 多功能桥接芯片。Rockchip 新增 rk628_efuse.{c,h} 和 rk628_pwm.{c,h} |
| 3 | `drivers/misc/rockchip/` (2) | Kconfig + pcie-rkep.c（PCIe Endpoint） |
| 4 | `drivers/misc/vehicle/` (1) | Rockchip 新增，车载驱动目录 |

#### NPU — `drivers/rknpu/`（16 项）

> Rockchip NPU 驱动，RK3588 核心 AI 推理引擎。
> 头文件 8 + 核心驱动 7（GEM/IOMMU/Job 提交/硬件复位）+ Rockchip 新增 rknpu_devfreq.c（NPU DVFS 频率调节器）。
> 全部差异为 Rockchip 后续新增多核 Job 并行调度、推理超时检测等。**不需要 patch**。

#### PHY — `drivers/phy/rockchip/`（18 项）

> CSI2 DPHY / INNO DSI+HDMI+USB2 / Naneng Combo+USB2 / PCIe / Samsung DCPHY+HDPTX / SNPS PCIe3 / Type-C / USB / USBDP。
> 覆盖 RK3588 全部高速接口（PCIe/SATA/USB3/DP/HDMI/MIPI）。**不需要 patch**。

#### 音频 — `sound/soc/` Rockchip 平台

| 序号 | 文件/目录 | 差异摘要 |
|------|----------|----------|
| 1 | `sound/soc/codecs/` (RK 编解码器，9) | rk3308_codec/rk730/rk817_codec/rk_dsm + Rockchip 新增 rockchip-spi-codec |
| 2 | `sound/soc/rockchip/` (25) | RK ASoC 平台驱动：I2S/I2S-TDM/PDM/SPDIF-RX+TX/SAI/DLP + Rockchip 新增 TRCM/Utils/DLP-PCM/Dummy-DAI。覆盖 RK3588 全部数字音频接口 |

#### 其他 — EDAC / RTC

| 序号 | 文件 | 差异摘要 |
|------|------|----------|
| 1 | `drivers/edac/rockchip_edac.c` | Rockchip 新增，DDR EDAC 驱动 |
| 2 | `drivers/rtc/rtc-rockchip.c` | RK3588 闹钟寄存器 + 秒中断唤醒 |
| 3 | `drivers/rtc/rtc-rv3028.c` | 校准寄存器 + 时钟输出功能 |
| 4 | `drivers/rtc/rtc-rv3032.c` | 高精度 RTC 更新 |
| 5 | `drivers/rtc/rtc-rk630.c` | Rockchip 新增，RK630 RTC 驱动 |

### 无需移植 — arch/arm64/boot/dts/rockchip/ 通用 DTS

> Rockchip 后续芯片支持和 EVB 修订版 DTS，Rockchip 基线已包含，无需移植。

| 序号 | 芯片系列 | 项数 | 说明 |
|------|---------|------|------|
| 1 | PX30 / RK1808 / RK3308 / RK3326 / RK3328 / RK3358 / RK3368 | ~40 | 旧芯片评估板修订版、机器人/车载变体 |
| 2 | RK3399 / RK3399Pro | ~22 | 安卓/Linux 配置更新、新 eval board 变体、NPU dtsi |
| 3 | RK3528 / RK3562 | ~26 | 新芯片 SoC dtsi 及 eval board（evb1/evb2/iotest/dictpen/tablet） |
| 4 | RK3566 | ~18 | EVB1~EVB5 修订、box/rk817 eink/tablet 配置 |
| 5 | RK3567 | 7 | Rockchip 新增芯片（rk3567.dtsi + evb2 4 种 LVDS 配置） |
| 6 | RK3568 (通用) | ~35 | SoC dtsi 更新、EVB1/2/5/6 修订、Toybrick/NVR/AMP、serdes 车载 ~25 项、PCIe EP |
| 7 | RK3588 / RK3588S (通用) | ~60 | SoC dtsi 更新、EVB1~EVB8 修订/EDP 面板（M280DCA/NE160QAM/NV140QUM）/HDMI2DP/AMP/NVR/IPC/vehicle v10~v23 ~25 项/Toybrick/vccio3/RK806 |
| 8 | RK3588S (通用) | ~12 | EVB1~EVB8 修订、BT1120、RK806/tablet 配置 |
| 9 | RK628 桥接芯片 | ~18 | Rockchip 新命名规范（`rk3568-evb-rk628-*`）取代旧命名（`rk3568-evb6-*`） |

## AOSP 差异验证

> 比较对象: 正点原子基线 vs Android 基线（`android-13.0.0_r84`，apply-patches.sh 执行后）
>
> 排除规则: `.git` 目录、`.gitignore`、软连接、空行/空格/Tab 缩进等空白差异
>
> 关注范围: 仅关注内容不同的文件和正点原子独有的文件

### 脚本生成

| 文件/目录 | 说明 |
|-----------|------|
| `build.sh` + `rk_build_common.sh` | AOSP 中由 apply-patches.sh 生成。将整合正点原子基线的编译相关部分：`mkimage.sh`、`mkimage_ab.sh`、`restore_patches.sh`、`rkst/`、`mkcombinedroot/` |

### 子模块内容

| 文件/目录 | 说明 |
|-----------|------|
| `u-boot/` | AOSP 中由 apply-patches.sh 从仓库子模块复制 + 打补丁。版本对齐见 [U-Boot 版本对齐](#u-boot-版本对齐) |
| `rkbin/` | AOSP 中由 apply-patches.sh 从仓库子模块复制 |
| `kernel-5.10/`（正点原子基线） → `kernel-5.10/`（AOSP） | 详细差异见 [Kernel 移植分析](#kernel-移植分析) |
| `can-utils/`（正点原子基线） → `rk-can-utils/`（本项目） | 仓库: `https://github.com/VaillerTeeter/rk-can-utils.git`。正点原子基线快照为 commit `3615bac17e539a06835dcb90855eae844ee18053` (2021-06-24, linux-can/can-utils upstream)。本项目已更新至 upstream 最新版 |
| `ntfs-3g/`（正点原子基线） → `external/ntfs-3g`（AOSP） | 基于 ntfs-3g upstream `2017.3.23`（commit `adb2cd24a85d394bdc2e57dec41b0c2110792640`），ATK 新增 10 个文件 + 修改 6 个文件。详细分析见 [ntfs-3g 移植分析](#ntfs-3g-移植分析) |

### 正点原子独有

| 文件/目录 | 说明 |
|-----------|------|
| `.classpath` | Eclipse IDE 项目配置文件，AOSP 编译不需要 |
| `RKDocs/` + `RKTools/` | Rockchip 内部文档与工具，不做处理 |
| `javaenv.sh` | AOSP 不需要 |
| `prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.2-2020.11-x86_64-aarch64-none-linux-gnu/` | GCC 10.2 工具链（aarch64），AOSP 使用 Clang，不需要 |
| `prebuilts/gcc/linux-x86/arm/gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf/` | GCC 10.2 工具链（ARM 32-bit），RK3588 用 aarch64，不需要 |
| `system/tools/release_tools/`（C++ 工具 + 脚本，~26 文件） | Rockchip 内部 SDK 发布/代码回朔/补丁恢复工具，与 AOSP 编译无直接关系 |

### 完全一致

| 文件(不含软连接)/目录 |
|-----------|
| `art` `bionic` `bootable` `cts` `dalvik` `developers` `development` `external` `frameworks` `kernel` `libcore` `libnativehelper` `packages` `pdk` `platform_testing` `sdk` `system` `test` `toolchain` `tools` `vendor` |

> 以上 21 个目录 + 4 个根文件，两边完全一致（RK 独有=0，内容不同=0）。

### 内容不同（无需移植）

> 以下差异均不含任何空白差异，且不影响最终产物。

| 文件/目录 | 差异说明 |
|-----------|----------|
| **`build/`**（3 文件） | |
| `build/core/build_id.mk`</br>`build/make/core/build_id.mk` | BUILD_ID 字符串不同（`TQ3C.230805.001.B2` vs `TQ3A.230805.001.S2`），纯版本号差异 |
| `build/soong/cc/config/global.go` | 版本宏差异（`-DANDROID_12` vs `-DANDROID_13`） |
| **`device/`**（2 文件） | |
| `device/google/raviole/device-oriole.mk`</br>`device/google/raviole/device-raven.mk` | `ro.vendor.build.svn` `56` vs `60`，纯 SVN 版本号差异 |
| **`hardware/`**（1 文件） | |
| `hardware/rockchip/librga/include/drmrga.h` | `ANDROID_12` vs `ANDROID_13` 版本宏差异 |
| **`prebuilts/`**（2 文件） | |
| `prebuilts/module_sdk/Bluetooth/.prebuilt_info/prebuilt_info_current_current_zip.asciipb` | `build_id` 不同（`10202400` vs `10027665`），git_branch 不同（`tm-qpr3-c-release` vs `tm-qpr-dev`），纯版本元数据差异 |
| `prebuilts/module_sdk/Bluetooth/current/snapshot-creation-build-number.txt` | 快照构建号不同（`10202400` vs `10027665`） |

## ntfs-3g 移植分析

> **对比版本**:
> - **ntfs-3g 上游基线**: `2017.3.23`，commit `adb2cd24a85d394bdc2e57dec41b0c2110792640`
> - **ATK 正点原子修改版**: `~/DDDD/external/ntfs-3g`（AOSP `external/ntfs-3g`）
>
> **总体结论**: ATK 基于 ntfs-3g upstream `2017.3.23`，新增 10 个文件 + 修改 6 个文件。
> 改动分为 Android 平台适配（CANONICAL_PATH / 设备命名 / logcat）和 Android 构建体系（Android.mk）
> 两大类。autotools 产物（configure、Makefile.in 等 20 个文件）为 `autoreconf -i` 自动生成，
> 不纳入补丁。
>
> **处理原则**: 以 ntfs-3g upstream `2017.3.23` 为基线，将 10 个新增文件 + 6 个差异文件的改动
> 打成补丁，应用到上游源码上。

### 新增文件（10 项）

> 均为 ATK 手写，rk-ntfs-3g 上游不存在。

#### Android.mk — AOSP 构建入口（5 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `Android.mk` | 顶层构建入口 |
| 2 | `libfuse-lite/Android.mk` | 编译 libfuse-lite 静态库 |
| 3 | `libntfs-3g/Android.mk` | 编译 libntfs-3g 静态库 |
| 4 | `ntfsprogs/Android.mk` | 编译 ntfsprogs 工具 |
| 5 | `src/Android.mk` | 编译 ntfs-3g 主程序 |

#### secaudit / usermap — Android 平台扩展（5 项）

| 序号 | 文件 | 说明 |
|------|------|------|
| 1 | `src/secaudit.c` | ntfs-3g 安全审计模块（Android 安全增强） |
| 2 | `src/secaudit.h` | secaudit 头文件 |
| 3 | `src/usermap.c` | ntfs-3g 用户映射模块（Android 多用户支持） |
| 4 | `src/ntfs-3g.secaudit.8.in` | secaudit man 手册模板 |
| 5 | `src/ntfs-3g.usermap.8.in` | usermap man 手册模板 |

### 差异文件（6 项）

> 上游存在但内容不同，ATK 做了 Android 平台适配。

#### Android FUSE CANONICAL_PATH 支持（3 项）

> Android inotify / MediaProvider 依赖此操作检测 NTFS 卷上的文件变化。
> 在 FUSE 协议中新增操作码 `FUSE_CANONICAL_PATH = 2016`，用于内核查询 inode 的真实路径。

| 序号 | 文件 | 改动说明 |
|------|------|----------|
| 1 | `include/fuse-lite/fuse_kernel.h` | 枚举新增 `FUSE_CANONICAL_PATH = 2016` |
| 2 | `include/fuse-lite/fuse_lowlevel.h` | ops 结构体新增 `canonical_path` 回调；新增 `fuse_reply_canonical_path()` 声明 |
| 3 | `libfuse-lite/fuse_lowlevel.c` | 实现 `fuse_reply_canonical_path()` 和 `do_canonical_path()` 分发函数；在 handler 表中注册该操作 |

#### Android SD 卡设备命名适配（2 项）

> Android vold 以 `/dev/block/vold/public:179,65@MYSD` 格式挂载设备，
> 但 FUSE 的 `fsname=` 选项用逗号分隔。两个文件配合完成 `@` ↔ `,` 双向转换。

| 序号 | 文件 | 改动说明 |
|------|------|----------|
| 1 | `libfuse-lite/fusermount.c` | 挂载前将设备名中第一个 `@` 替换为 `,` |
| 2 | `src/ntfs-3g_common.c` | 组装 fsname 参数前将 `,` 替换回 `@`，保持原始设备名传给 FUSE |

#### Android logcat 日志集成（1 项）

| 序号 | 文件 | 改动说明 |
|------|------|----------|
| 1 | `libntfs-3g/logging.c` | `__ANDROID_API__` 宏控制下，将日志输出重定向到 Android logcat（TAG: `NTFS-3G`） |

### 无需移植

> 以下文件 ATK 存在但 rk-ntfs-3g 上游不存在，全部为 autotools 自动生成产物，不纳入补丁。

| 序号 | 文件 | 来源 |
|------|------|------|
| 1 | `configure` | `autoconf` 从 `configure.ac` 生成 |
| 2 | `config.h.in` | `autoheader` 生成 |
| 3 | `config.h` | `./configure` 运行后生成 |
| 4 | `aclocal.m4` | `aclocal` 汇集宏 |
| 5 | `Makefile.in` (7 个：顶层 + include/ + include/fuse-lite/ + include/ntfs-3g/ + libfuse-lite/ + libntfs-3g/ + ntfsprogs/ + src/) | `automake` 从 `Makefile.am` 生成 |
| 6 | `INSTALL` | `automake` 通用安装说明 |
| 7 | `compile` | `automake` 辅助脚本 |
| 8 | `config.guess` | GNU config 包 |
| 9 | `config.sub` | GNU config 包 |
| 10 | `depcomp` | `automake` 依赖追踪 |
| 11 | `install-sh` | `automake` 安装脚本 |
| 12 | `ltmain.sh` | `libtool` 核心脚本 |
| 13 | `missing` | `automake` 缺失工具替身 |

> 可在 rk-ntfs-3g 目录执行 `autoreconf -i` 重新生成以上全部文件。
> 前提：安装 `autoconf automake libtool libgcrypt-dev`。

### 补丁生成

```bash
# 以 upstream 2017.3.23 为基线，生成 ATK 修改补丁
diff -ruN ntfs-3g-2017.3.23/ external/ntfs-3g/ \
    --exclude=configure --exclude=config.h --exclude=config.h.in \
    --exclude=aclocal.m4 --exclude=Makefile.in --exclude=INSTALL \
    --exclude=compile --exclude=config.guess --exclude=config.sub \
    --exclude=depcomp --exclude=install-sh --exclude=ltmain.sh \
    --exclude=missing --exclude=.git \
    > patches/ntfs-3g-atk.patch
```
