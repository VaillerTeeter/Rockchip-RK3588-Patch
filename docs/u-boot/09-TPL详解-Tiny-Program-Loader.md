# Rockchip U-Boot TPL 详解

本章详细介绍 TPL（Tiny Program Loader）的功能定位、平台配置、DTS 配置、编译打包流程及调试手段。

## 一、概述

### 1.1 功能定位

TPL（Tiny Program Loader）是 Rockchip U-Boot 开源启动链中最早期的 Loader，运行在芯片内部 **SRAM** 中，其核心作用是替代闭源 **DDR Bin** 完成 DDR 内存的初始化工作。

在完整启动链中，TPL 的位置如下：

```
BOOTROM → TPL（DDR Bin）→ SPL（Miniloader）→ TRUST → U-Boot → Kernel
```

其中：
- **TPL** 功能等价于 **DDR Bin**（负责 DDR 初始化）
- **SPL** 功能等价于 **Miniloader**（负责系统 lowlevel 初始化和后级固件加载）
- TPL + SPL 组合实现了与闭源 DDR Bin + Miniloader 一致的功能，可互相替换

> TPL / SPL / U-Boot Proper 的基本概念和启动流程请参考"基础简介"章节；DDR Bin 与 TPL 的替换关系请参考"平台架构"章节。

### 1.2 TPL 与 DDR Bin 对比

| 对比维度 | TPL | DDR Bin |
|----------|-----|---------|
| **代码来源** | U-Boot 同一份源码编译而来 | Rockchip 闭源二进制 |
| **运行位置** | SRAM | SRAM |
| **核心职责** | DDR 初始化 | DDR 初始化 |
| **代码可见性** | 开源，可修改和调试 | 闭源，不可修改 |
| **配置方式** | 通过 Kconfig + DDR 源码参数 | 无 |
| **调用栈支持** | 支持，`stacktrace.sh dump.txt tpl` | 不支持 |
| **维护方式** | 跟随 U-Boot 仓库统一管理 | 独立维护于 rkbin 仓库 |

### 1.3 代码路径

TPL 相关源码主要分布在以下目录：

| 路径 | 说明 |
|------|------|
| `./tpl/` | TPL 编译输出目录 |
| `./drivers/ram/rockchip/` | DDR 初始化核心源码 |
| `./drivers/ram/rockchip/sdram_inc/` | 各平台 DDR 参数配置 |
| `./arch/arm/mach-rockchip/` | 平台级 TPL 启动代码 |
| `./common/spl/` | TPL/SPL 公共代码 |

> TPL 代码复用 U-Boot 框架的 DM、DTS 等机制，但运行在极有限的 SRAM 空间内，编译时会通过 `CONFIG_TPL_BUILD` 宏裁剪大量无关代码。

## 二、平台配置

### 2.1 UART 配置

TPL 阶段的串口输出依赖以下两个配置项：

| 配置项 | 说明 |
|--------|------|
| `CONFIG_DEBUG_UART_BASE` | UART 控制器基地址 |
| `CONFIG_ROCKCHIP_UART_MUX_SEL_M` | UART IOMUX Group 选择 |

**范例**：RV1126 配置 UART2 M2 用于打印调试信息。

**方式一**：通过 `make menuconfig` 配置

```
Device Drivers ---> Serial drivers ---> (0xff570000) Base address of UART
ARM architecture ---> (2) UART mux select
```

**方式二**：通过修改 `defconfig` 文件（不推荐，建议使用 `make menuconfig` 后用 `make savedefconfig` 更新）

```
CONFIG_DEBUG_UART_BASE=0xff570000
CONFIG_ROCKCHIP_UART_MUX_SEL_M=2
```

> **注意**：编译时如果 `make.sh` 后面带有芯片型号参数，会先执行 `make xxx_defconfig` 覆盖 `.config`，导致 `menuconfig` 的改动丢失。建议先用 `make xxx_defconfig`，再 `make menuconfig`，最后不带参数执行 `./make.sh`。

### 2.2 DRAM Type 配置

通过 `CONFIG_ROCKCHIP_TPL_INIT_DRAM_TYPE` 配置 TPL 支持的 DRAM 类型：

| DDR Type | 配置值 |
|----------|--------|
| DDR2 | 2 |
| DDR3 | 3 |
| DDR4 | 0 |
| LPDDR2 | 5 |
| LPDDR3 | 6 |
| LPDDR4 | 7 |

**范例**：RV1126 配置 TPL 支持 DDR3。

```
Device Drivers ---> (3) TPL select DRAM type
```

### 2.3 快速开机配置

如果需要编译生成支持快速开机的 `tpl.bin`，可通过开启 `CONFIG_SPL_KERNEL_BOOT` 来编译生成。

> 当前仅支持 **RV1126 / RV1109** 平台。

### 2.4 宽温支持

如果需要编译生成支持宽温的 `tpl.bin`，可通过开启 `CONFIG_ROCKCHIP_DRAM_EXTENDED_TEMP_SUPPORT` 来编译生成。

> 当前仅支持 **RV1126 / RV1109** 平台。

### 2.5 DDR 参数修改

DDR 初始化源码位于 `./drivers/ram/rockchip/` 目录下。DDR 相关的关键参数（如频率、驱动强度、ODT 强度等）均需要在源码中修改。

**各平台的参数位置**：

| 平台 | 参数文件位置 |
|------|-------------|
| RV1126 / RV1109 | `./drivers/ram/rockchip/sdram_inc/rv1126/sdram-rv1126-loader_params.inc` |
| 其他平台 | 在对应 `sdram_xxx.c` 源文件中修改（如 `sdram_rk3399.c`） |

> RV1126 / RV1109 平台将 DDR 相关参数集中到 `sdram-rv1126-loader_params.inc` 中，方便统一管理和修改。

### 2.6 重要 Kconfig 选项一览

| 配置项 | 说明 |
|--------|------|
| `CONFIG_TPL_BUILD` | TPL 编译宏，编译时自动生成，用于区分 TPL 和 U-Boot Proper 代码路径 |
| `CONFIG_DEBUG_UART_BASE` | UART 基地址 |
| `CONFIG_ROCKCHIP_UART_MUX_SEL_M` | UART IOMUX Group |
| `CONFIG_ROCKCHIP_TPL_INIT_DRAM_TYPE` | DRAM 类型选择 |
| `CONFIG_SPL_KERNEL_BOOT` | 快速开机支持（仅 RV1126/RV1109） |
| `CONFIG_ROCKCHIP_DRAM_EXTENDED_TEMP_SUPPORT` | 宽温支持（仅 RV1126/RV1109） |

## 三、DTS 配置

### 3.1 TPL 阶段的 DTB

与 U-Boot Proper 和 SPL 类似，TPL 也拥有自己的 DTS 文件，编译时会自动生成相应的 DTB 文件，附加在 `u-boot-tpl.bin` 末尾。

```
源码目录：arch/arm/dts/
```

编译过程中，U-Boot 会过滤出 DTS 中带 `u-boot,dm-tpl` 属性的节点，再剔除 `defconfig` 中 `CONFIG_OF_TPL_REMOVE_PROPS` 指定的 property，最终生成 `u-boot-tpl.dtb` 并追加在 `u-boot-tpl.bin` 末尾。

### 3.2 必要节点保留

TPL 运行在 SRAM 中，内存空间极其有限，因此只会保留与 DDR 初始化直接相关的节点。以串口为例：

```
chosen {
    stdout-path = &uart2;
};

&uart2 {
    u-boot,dm-tpl;
    clock-frequency = <24000000>;
    status = "okay";
};
```

> 如果 TPL 阶段无串口输出，请首先检查 `chosen` 节点的 `stdout-path` 配置，以及 `u-boot,dm-tpl` 属性是否正确添加。

### 3.3 DM 属性说明

DTS 节点在不同阶段的保留属性对照：

| 属性 | 作用阶段 |
|------|----------|
| `u-boot,dm-pre-reloc` | U-Boot Proper（relocation 前） |
| `u-boot,dm-spl` | SPL 阶段 |
| `u-boot,dm-tpl` | TPL 阶段 |

> 如果需要某个外设节点在 TPL 阶段可用，必须在该节点中添加 `u-boot,dm-tpl` 属性。

## 四、编译与打包

### 4.1 代码编译

U-Boot 对同一份代码通过不同的编译路径生成 TPL 固件。编译 TPL 时会自动生成 `CONFIG_TPL_BUILD` 宏，用于区分 TPL 和 U-Boot Proper 的代码路径。U-Boot 会在编译完 `u-boot.bin` 之后继续编译 TPL，并创建独立的输出目录 `./tpl/`。

**编译过程输出范例**：

```
// 编译 U-Boot Proper
......
DTC arch/arm/dts/rv1108-evb.dtb
DTC arch/arm/dts/rk3399-puma-ddr1866.dtb
DTC arch/arm/dts/rv1126-evb.dtb
FDTGREP dts/dt.dtb
FDTGREP dts/dt-spl.dtb
FDTGREP dts/dt-tpl.dtb
CAT u-boot-dtb.bin
MKIMAGE u-boot.img
COPY u-boot.dtb
MKIMAGE u-boot-dtb.img
COPY u-boot.bin
ALIGN u-boot.bin

// 编译 TPL（独立输出到 tpl/ 目录）
......
CC tpl/common/init/board_init.o
CC tpl/disk/part.o
LD tpl/common/init/built-in.o
......
LD tpl/u-boot-tpl
......
OBJCOPY tpl/u-boot-tpl-nodtb.bin
COPY tpl/u-boot-tpl.bin
```

**编译产物**：

| 文件 | 说明 |
|------|------|
| `./tpl/u-boot-tpl.map` | MAP 表文件 |
| `./tpl/u-boot-tpl.sym` | SYMBOL 表文件 |
| `./tpl/u-boot-tpl` | ELF 文件（类比内核的 `vmlinux`，**重要**） |
| `./tpl/u-boot-tpl.dtb` | TPL 自身的 DTB 文件 |
| `./tpl/u-boot-tpl.bin` | 可执行二进制文件，会被打包成 Loader 用于烧写 |

**编译命令示例**：

```
./make.sh rv1126
```

### 4.2 固件打包

#### 4.2.1 Tag 替换

编译生成的 `u-boot-tpl.bin` 需要将头部前 4 个字节替换成相应平台的 **Tag** 后才是一个合法的 DDR Bin。

| 平台 | Tag |
|------|-----|
| RV1126 / RV1109 | `"110B"` |

**范例**：替换 RV1126 `u-boot-tpl.bin` 的 Tag。

```
dd bs=4 skip=1 if=tpl/u-boot-tpl.bin of=tpl/u-boot-tpl-tag.bin && sed -i '1s/^/110B&/' tpl/u-boot-tpl-tag.bin
```

> 该步骤的自动化实现可参考 `./scripts/spl.sh` 脚本。

#### 4.2.2 生成完整 Loader

如果需要生成完整的、可烧写入板子的 Loader 文件，可通过以下命令自动完成 `u-boot-tpl.bin` 的 Tag 替换动作以及和 `spl.bin` 的打包：

```
./make.sh --tpl --spl
```

该命令等效于：用 TPL + SPL 替换 DDR Bin + Miniloader，打包成 Loader。

### 4.3 make.sh 命令参考

| 命令 | 说明 |
|------|------|
| `./make.sh [board]` | 编译指定平台的 U-Boot（首次使用必须带 `[board]` 参数） |
| `./make.sh --tpl` | 用 TPL 替换 DDR Bin（保留 Miniloader），打包成 Loader |
| `./make.sh --spl` | 用 SPL 替换 Miniloader（保留 DDR Bin），打包成 Loader |
| `./make.sh --tpl --spl` | 用 TPL + SPL 替换 DDR Bin + Miniloader，打包成 Loader |
| `./make.sh --spl-new` | 比 `--spl` 多一步重新编译再打包 |

> 编译与打包的完整流程以及 `make.sh` 的更多用法请参考"编译烧写"章节。

### 4.4 独立获取 DDR Bin

如果仅需要 DDR Bin 而不需要完整 Loader，用户需要自行完成 Tag 替换步骤（参见 4.2.1 节），替换后得到的 `u-boot-tpl-tag.bin` 即为可独立使用的 DDR Bin。

## 五、调试手段

### 5.1 串口检查

如果 TPL 阶段无任何串口输出，请按以下步骤排查：

1. **确认 UART 基地址正确**：检查 `CONFIG_DEBUG_UART_BASE` 是否与硬件原理图一致
2. **确认 IOMUX 配置正确**：检查 `CONFIG_ROCKCHIP_UART_MUX_SEL_M` 是否选择了正确的 UART Group
3. **确认 DTS 节点保留**：检查 `u-boot,dm-tpl` 属性是否已添加到对应的 UART 节点
4. **确认 `stdout-path` 正确**：检查 `chosen` 节点中的 `stdout-path` 是否指向正确的 UART 节点

> 更多串口调试方法请参考"调试手段"章节。

### 5.2 调用栈回溯

TPL 支持调用栈回溯（Stacktrace）机制。当 TPL 阶段发生异常时，可以将 Call trace 信息复制到文件，使用 `stacktrace.sh` 脚本将地址转换为可读的函数名和代码位置：

```
./scripts/stacktrace.sh ./dump.txt tpl   # 解析来自 TPL 的调用栈
```

> **注意**：执行该命令时，当前机器上的固件必须和当前代码环境匹配，否则会得到错误的转换结果。
>
> 调用栈回溯的完整原理请参考"平台架构"章节的"调用栈回溯"部分。

### 5.3 常见问题排查

| 问题现象 | 可能原因 | 排查方向 |
|----------|----------|----------|
| TPL 无串口输出 | UART 配置错误 | 检查 5.1 节的串口配置 |
| TPL 打印后卡死 | DDR 初始化失败 | 检查 DRAM Type 配置（2.2 节）、DDR 参数（2.5 节）、硬件供电 |
| DDR 容量识别不正确 | DDR 参数配置错误 | 检查 `sdram-xxx-loader_params.inc` 或 `sdram_xxx.c` 中的容量配置 |
| 编译报错 | defconfig 依赖问题 | 执行 `make distclean` 后重新编译 |
| TPL + SPL 组合启动失败 | 打包顺序错误 | 确认使用了 `./make.sh --tpl --spl` 完整打包 |

## 六、进阶参考

| 参考主题 | 相关章节 |
|----------|----------|
| TPL / SPL / U-Boot Proper 概念 | 基础简介 |
| 启动链与内存布局 | 平台架构 |
| 编译烧写完整流程 | 编译烧写 |
| SPL 模块详解 | SPL |
| 调试手段与工具 | 调试手段 |
| ATAGS 固件通信机制 | 平台架构 |
