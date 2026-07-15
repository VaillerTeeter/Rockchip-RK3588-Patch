# Rockchip U-Boot SPL 详解

本章详细介绍 SPL（Secondary Program Loader）的功能定位、支持的固件格式、系统模块和驱动模块的配置与使用，以及编译打包流程。

## 一、概述

SPL 是 Rockchip U-Boot 开源启动链中的 **Secondary Program Loader**，运行在 DDR 上，其核心作用是替代闭源 **Miniloader** 完成 `trust.img` 和 `uboot.img` 的加载与引导工作。

在完整启动链中，SPL 的位置如下：

```
BOOTROM → TPL（DDR Bin）→ SPL（Miniloader）→ TRUST → U-Boot → Kernel
```

SPL 目前支持引导两种固件格式：

- **FIT 固件**：默认使能，推荐使用；
- **RKFW 固件**：默认关闭，需要用户单独配置和使能。

> SPL 的基本概念和启动流程请参考"基础简介"章节；Miniloader 与 SPL 的替换关系请参考"平台架构"章节。

## 二、固件格式与引导

### 2.1 FIT 格式

FIT（Flattened Image Tree）是 U-Boot mainline 支持的固件格式，使用 DTS 语法对打包的 image 进行描述。其优点是复用 DTS 的语法和编译规则，灵活性强，固件解析可直接使用 libfdt 库。

描述文件为 `u-boot.its`，最终生成的 FIT 固件为 `u-boot.itb`。

#### 2.1.1 u-boot.its 文件结构

- **`/images`** 节点：静态定义所有可获取的资源配置（类似 `dtsi` 的角色，最后可用、可不用）；
- **`/configurations`** 节点：每个 `config` 子节点描述一套可启动的配置（类似板级 `dts`），通过 `default` 属性指定当前选用的默认配置。

**范例**：

```
/dts-v1/;

/ {
    description = "Configuration to load ATF before U-Boot";
    #address-cells = <1>;

    images {
        uboot@1 {
            description = "U-Boot (64-bit)";
            data = /incbin/("u-boot-nodtb.bin");
            type = "standalone";
            os = "U-Boot";
            arch = "arm64";
            compression = "none";
            load = <0x00200000>;
        };

        atf@1 {
            description = "ARM Trusted Firmware";
            data = /incbin/("bl31_0x00010000.bin");
            type = "firmware";
            arch = "arm64";
            os = "arm-trusted-firmware";
            compression = "none";
            load = <0x00010000>;
            entry = <0x00010000>;
        };

        atf@2 {
            description = "ARM Trusted Firmware";
            data = /incbin/("bl31_0xff091000.bin");
            type = "firmware";
            arch = "arm64";
            os = "arm-trusted-firmware";
            compression = "none";
            load = <0xff091000>;
        };

        optee@1 {
            description = "OP-TEE";
            data = /incbin/("bl32.bin");
            type = "firmware";
            arch = "arm64";
            os = "op-tee";
            compression = "none";
            load = <0x08400000>;
        };

        fdt@1 {
            description = "rk3328-evb.dtb";
            data = /incbin/("arch/arm/dts/rk3328-evb.dtb");
            type = "flat_dt";
            compression = "none";
        };
    };

    configurations {
        default = "config@1";
        config@1 {
            description = "rk3328-evb.dtb";
            firmware = "atf@1";
            loadables = "uboot@1", "atf@2", "optee@1";
            fdt = "fdt@1";
        };
    };
};
```

#### 2.1.2 u-boot.itb 文件

FIT 固件可理解为一种特殊的 DTB 文件，只是其内容为 image。生成过程如下：

```
[u-boot.its] + [images]  —— mkimage + dtc ——>  [u-boot.itb]
```

编译阶段会自动为每个 image 子节点追加 `data-size`（固件大小）和 `data-offset`（固件偏移）字段。用户可以使用 `fdtdump` 命令查看 `u-boot.itb` 内容：

```
cjh@ubuntu:~/uboot-nextdev/u-boot$ fdtdump u-boot.itb | less

/dts-v1/;
// magic: 0xd00dfeed
// totalsize: 0x497 (1175)
// off_dt_struct: 0x38
// off_dt_strings: 0x414
// off_mem_rsvmap: 0x28
// version: 17
// last_comp_version: 16
// boot_cpuid_phys: 0x0
// size_dt_strings: 0x83
// size_dt_struct: 0x3dc

/ {
    timestamp = <0x5d099c85>;
    description = "Configuration to load ATF before U-Boot";
    #address-cells = <0x00000001>;
    images {
        uboot@1 {
            data-size = <0x0009f8a8>;
            data-offset = <0x00000000>;
            description = "U-Boot (64-bit)";
            type = "standalone";
            os = "U-Boot";
            arch = "arm64";
            compression = "none";
            load = <0x00600000>;
        };
        atf@1 {
            data-size = <0x0000c048>;
            data-offset = <0x0009f8a8>;
            description = "ARM Trusted Firmware";
            type = "firmware";
            arch = "arm64";
            os = "arm-trusted-firmware";
            compression = "none";
            load = <0x00010000>;
            entry = <0x00010000>;
        };
        atf@2 {
            data-size = <0x00002000>;
            data-offset = <0x000ab8f0>;
            description = "ARM Trusted Firmware";
            type = "firmware";
            arch = "arm64";
            os = "arm-trusted-firmware";
            compression = "none";
            load = <0xfff82000>;
        };
        fdt@1 {
            data-size = <0x00005793>;
            data-offset = <0x000ad8f0>;
            description = "rk3308-evb.dtb";
            type = "flat_dt";
            compression = "none";
        };
    };
};
```

> **更多参考**：FIT 格式的详细文档位于 `./doc/uImage.FIT/`。

### 2.2 RKFW 格式

为了能更直接替换掉 Miniloader 且无需修改后级固件的分区和打包格式，Rockchip 平台增加了 RKFW 格式的引导支持。RKFW 格式即保持独立分区的固件（`trust.img` 和 `uboot.img`），与闭源方案的存储布局完全兼容。

#### 2.2.1 配置

```
CONFIG_SPL_LOAD_RKFW            // 使能开关
CONFIG_RKFW_TRUST_SECTOR        // trust.img 分区地址，需与分区表定义一致
CONFIG_RKFW_U_BOOT_SECTOR       // uboot.img 分区地址，需与分区表定义一致
```

#### 2.2.2 驱动

```
./include/spl_rkfw.h
./common/spl/spl_rkfw.c
```

> RKFW 格式与闭源方案的分区兼容性细节请参考"平台架构"章节的存储布局与分区表部分。

## 三、存储与启动

### 3.1 存储启动优先级

SPL 通过 U-Boot DTS 中的 `u-boot,spl-boot-order` 属性指定存储设备的启动优先级。该属性位于 `rkxxxx-u-boot.dtsi` 的 `chosen` 节点中：

```
/ {
    aliases {
        mmc0 = &emmc;
        mmc1 = &sdmmc;
    };

    chosen {
        u-boot,spl-boot-order = &sdmmc, &nandc, &emmc;
        stdout-path = &uart2;
    };
};
```

各级 Loader 的默认启动优先级对比如下：

| 阶段 | 优先级（由高到低） |
|------|-------------------|
| **Maskrom** | SPI NOR → SPI NAND → eMMC → SD |
| **Pre-loader（SPL）** | SD → SPI NOR → SPI NAND → eMMC |

> 将 SD 卡的优先级提到最高可以方便系统从 SD 卡启动进行调试。

### 3.2 GPT 分区表

SPL 使用 GPT 分区表管理存储分区。

#### 3.2.1 配置

```
CONFIG_SPL_LIBDISK_SUPPORT=y
CONFIG_SPL_EFI_PARTITION=y
CONFIG_PARTITION_TYPE_GUID=y
```

#### 3.2.2 驱动

```
./disk/part.c
./disk/part_efi.c
```

#### 3.2.3 接口

```
int part_get_info(struct blk_desc *dev_desc, int part, disk_partition_t *info);
int part_get_info_by_name(struct blk_desc *dev_desc, const char *name, disk_partition_t *info);
```

### 3.3 A/B System

SPL 支持 Android A/B 系统启动，即系统固件分为 **slot-a** 和 **slot-b** 两份，可从任意一个 slot 启动，升级时可直接将固件写入另一个 slot。

#### 3.3.1 配置

```
CONFIG_SPL_AB=y
```

#### 3.3.2 驱动

```
./common/spl/spl_ab.c
```

#### 3.3.3 接口

```
int spl_get_current_slot(struct blk_desc *dev_desc, char *partition, char *slot);
int spl_get_partitions_sector(struct blk_desc *dev_desc, char *partition, u32 *sectors);
```

> A/B 系统的完整原理和分区表要求请参考"系统模块"章节。

### 3.4 ATAGS 传参

SPL 与 U-Boot Proper 之间通过 ATAGS 机制传递启动参数，包括启动的存储设备类型、打印串口信息等。ATAGS 是 Rockchip 平台各固件之间共享配置信息的核心手段。

#### 3.4.1 配置

```
CONFIG_ROCKCHIP_PRELOADER_ATAGS=y
```

#### 3.4.2 驱动

```
./arch/arm/include/asm/arch-rockchip/rk_atags.h
./arch/arm/mach-rockchip/rk_atags.c
```

#### 3.4.3 接口

```
int atags_set_tag(u32 magic, void *tagdata);
struct tag *atags_get_tag(u32 magic);
```

> ATAGS 的完整工作原理和传递内容请参考"平台架构"章节。

## 四、系统模块

### 4.1 Kernel Boot

通常情况下 Kernel 由 U-Boot Proper 加载和引导，但在某些场景下 SPL 也可以直接支持加载 Kernel，从而跳过 U-Boot Proper 阶段以缩短启动时间。目前支持加载 Android Header Version 2 的 `boot.img` 和 RK 格式固件。

**启动顺序**：

```
Maskrom → DDR → SPL → Trust → Kernel
```

### 4.2 Pinctrl

Pinctrl 用于配置引脚复用和电气属性，SPL 阶段通过 DM 框架统一管理。

#### 4.2.1 配置

```
CONFIG_SPL_PINCTRL_GENERIC=y
CONFIG_SPL_PINCTRL=y
```

#### 4.2.2 驱动

```
./drivers/pinctrl/pinctrl-uclass.c
./drivers/pinctrl/pinctrl-generic.c
./drivers/pinctrl/pinctrl-rockchip.c
```

#### 4.2.3 DTS 配置

以 sdmmc 为例，需要在 U-Boot DTS 中为相关节点添加 `u-boot,dm-spl` 属性，使其在 SPL 阶段可用：

```
&pinctrl {
    u-boot,dm-spl;
};

&pcfg_pull_none_4ma {
    u-boot,dm-spl;
};

&pcfg_pull_up_4ma {
    u-boot,dm-spl;
};

&sdmmc {
    u-boot,dm-spl;
};

&sdmmc_pin {
    u-boot,dm-spl;
};

&sdmmc_clk {
    u-boot,dm-spl;
};

&sdmmc_cmd {
    u-boot,dm-spl;
};

&sdmmc_bus4 {
    u-boot,dm-spl;
};

&sdmmc_pwren {
    u-boot,dm-spl;
};
```

#### 4.2.4 注意事项

SPL 启用 Pinctrl 时，需要修改 defconfig 中的 `CONFIG_OF_SPL_REMOVE_PROPS` 定义，从其中删除 `pinctrl-0` 和 `pinctrl-names` 字段，确保引脚配置属性不会被过滤掉。

### 4.3 Secure Boot

> **说明**：SPL Secure Boot 的详细实现原理和配置流程请参考"进阶原理"章节和"平台架构"章节的 Fuse/OTP 部分。Secure Boot 涉及到 Trust（ATF/OP-TEE）配合、efuse 烧写、固件签名等跨模块操作，内容较为复杂，此处不做展开。

## 五、驱动模块

### 5.1 MMC

SPL 阶段的 eMMC / SD 卡驱动，负责从 MMC 存储介质加载后级固件。

#### 5.1.1 配置

```
CONFIG_SPL_MMC_SUPPORT=y              // 默认已使能
```

#### 5.1.2 驱动

```
./common/spl/spl_mmc.c
```

#### 5.1.3 接口

```
int spl_mmc_load_image(struct spl_image_info *spl_image, struct spl_boot_device *bootdev);
```

### 5.2 MTD Block

SPL 将 NAND Flash、SPI NAND Flash、SPI NOR Flash 的访问接口统一封装到 Block 层，上层调用无需关心底层存储类型差异。

#### 5.2.1 配置

**MTD 基础驱动支持**：

```
CONFIG_MTD=y
CONFIG_CMD_MTD_BLK=y
CONFIG_SPL_MTD_SUPPORT=y
CONFIG_MTD_BLK=y
CONFIG_MTD_DEVICE=y
```

**SPI NAND 驱动支持**：

```
CONFIG_MTD_SPI_NAND=y
CONFIG_ROCKCHIP_SFC=y
CONFIG_SPL_SPI_FLASH_SUPPORT=y
CONFIG_SPL_SPI_SUPPORT=y
```

**NAND Flash 驱动支持**：

```
CONFIG_NAND=y
CONFIG_CMD_NAND=y
CONFIG_NAND_ROCKCHIP=y              // NandC v6，可通过 NANDC_NANDC_VER 寄存器（0x00000801）确认
// CONFIG_NAND_ROCKCHIP_V9=y        // NandC v9，可通过 NANDC_NANDC_VER 寄存器（0x56393030）确认，如 RK3326/PX30
CONFIG_SPL_NAND_SUPPORT=y
CONFIG_SYS_NAND_U_BOOT_LOCATIONS=y
CONFIG_SYS_NAND_U_BOOT_OFFS=0x8000
CONFIG_SYS_NAND_U_BOOT_OFFS_REDUND=0x10000
#define CONFIG_SYS_NAND_PAGE_SIZE 2048    // 需按实际 page size 定义，≥512MB 的 NAND 一般配置为 4096
```

**SPI NOR Flash 驱动支持**：

```
CONFIG_CMD_SF=y
CONFIG_CMD_SPI=y
CONFIG_SPI_FLASH=y
CONFIG_SF_DEFAULT_MODE=0x1
CONFIG_SF_DEFAULT_SPEED=50000000
CONFIG_SPI_FLASH_GIGADEVICE=y
CONFIG_SPI_FLASH_MACRONIX=y
CONFIG_SPI_FLASH_WINBOND=y
CONFIG_SPI_FLASH_MTD=y
CONFIG_ROCKCHIP_SFC=y
CONFIG_SPL_SPI_SUPPORT=y
CONFIG_SPL_MTD_SUPPORT=y
CONFIG_SPL_SPI_FLASH_SUPPORT=y
```

#### 5.2.2 驱动

```
./common/spl/spl_mtd_blk.c
```

#### 5.2.3 接口

```
int spl_mtd_load_image(struct spl_image_info *spl_image, struct spl_boot_device *bootdev);
```

> MTD 设备的调试方法请参考"调试手段"章节的 MMC 命令部分（MTD 也可以走 Block 层的 `mmc` 命令访问）。

### 5.3 OTP

OTP（One-Time Programmable）用于存储不可更改的安全数据，在 Secure Boot 流程中用于保存公钥哈希等关键信息。

#### 5.3.1 配置

```
CONFIG_SPL_MISC=y
CONFIG_SPL_ROCKCHIP_SECURE_OTP=y
```

#### 5.3.2 驱动

```
./drivers/misc/misc-uclass.c
./drivers/misc/rockchip-secure-otp.S
```

#### 5.3.3 接口

```
int misc_read(struct udevice *dev, int offset, void *buf, int size);
int misc_write(struct udevice *dev, int offset, void *buf, int size);
```

### 5.4 Crypto

Secure Boot 流程中用于完成 HASH 计算和 RSA 签名校验的硬件加密引擎。

#### 5.4.1 配置

```
CONFIG_SPL_DM_CRYPTO=y

// 二选一，各平台的 defconfig 已默认使能对应配置
CONFIG_SPL_ROCKCHIP_CRYPTO_V1=y    // V1 加密引擎
CONFIG_SPL_ROCKCHIP_CRYPTO_V2=y    // V2 加密引擎
```

#### 5.4.2 驱动

```
./drivers/crypto/crypto-uclass.c
./drivers/crypto/rockchip/crypto_v1.c
./drivers/crypto/rockchip/crypto_v2.c
./drivers/crypto/rockchip/crypto_v2_pka.c
./drivers/crypto/rockchip/crypto_v2_util.c
```

#### 5.4.3 接口

```
u32 crypto_algo_nbits(u32 algo);
struct udevice *crypto_get_device(u32 capability);
int crypto_sha_init(struct udevice *dev, sha_context *ctx);
int crypto_sha_update(struct udevice *dev, u32 *input, u32 len);
int crypto_sha_final(struct udevice *dev, sha_context *ctx, u8 *output);
int crypto_sha_csum(struct udevice *dev, sha_context *ctx, char *input, u32 input_len, u8 *output);
int crypto_rsa_verify(struct udevice *dev, rsa_key *ctx, u8 *sign, u8 *output);
```

### 5.5 UART

SPL 阶段的串口通过 `rkxxxx-u-boot.dtsi` 中的 `chosen` 节点的 `stdout-path` 属性指定。

以 rk3308 为例：

```
chosen {
    stdout-path = &uart2;
};

&uart2 {
    u-boot,dm-pre-reloc;
    clock-frequency = <24000000>;
    status = "okay";
};
```

> 如果 SPL 阶段无串口输出，请首先检查 `chosen` 节点的 `stdout-path` 配置，以及 `u-boot,dm-pre-reloc` 属性是否正确添加。

## 六、编译与打包

### 6.1 代码编译

U-Boot 对同一份代码通过不同的编译路径生成 SPL 固件。编译 SPL 时会自动生成 `CONFIG_SPL_BUILD` 宏，用于区分 SPL 和 U-Boot Proper 的代码路径。U-Boot 会在编译完 `u-boot.bin` 之后继续编译 SPL，并创建独立的输出目录 `./spl/`。

**编译过程输出范例**：

```
// 编译 U-Boot Proper
......
DTC arch/arm/dts/rk3399-puma-ddr1866.dtb
DTC arch/arm/dts/rv1108-evb.dtb
make[2]: 'arch/arm/dts/rk3328-evb.dtb' is up to date.
SHIPPED dts/dt.dtb
FDTGREP dts/dt-spl.dtb
CAT u-boot-dtb.bin
MKIMAGE u-boot.img
COPY u-boot.dtb
MKIMAGE u-boot-dtb.img
COPY u-boot.bin

// 编译 SPL（独立输出到 spl/ 目录）
LD spl/arch/arm/cpu/built-in.o
CC spl/board/rockchip/evb_rk3328/evb-rk3328.o
LD spl/dts/built-in.o
CC spl/common/init/board_init.o
COPY tpl/u-boot-tpl.dtb
CC spl/cmd/nvedit.o
CC spl/env/common.o
CC spl/env/env.o
......
LD spl/drivers/block/built-in.o
......
```

**编译产物**：

```
./spl/u-boot-spl.bin
```

### 6.2 固件打包

SPL 编译完成后，需要与 TPL 组合打包为 Loader 镜像才能烧写使用，或者替换 Miniloader 完成系统引导。

**FIT 格式打包**：

对于使用 FIT 格式的平台，通过 `make.sh` 脚本完成 SPL 的打包：

```
# 用 TPL + SPL 替换 DDR Bin + Miniloader，打包成 Loader
./make.sh --tpl --spl

# 用 SPL 替换 Miniloader（保留 DDR Bin），打包成 Loader
./make.sh --spl

# 用 TPL 替换 DDR Bin（保留 Miniloader），打包成 Loader
./make.sh --tpl

# 比 --spl 多一步重新编译再打包
./make.sh --spl-new
```

**RKFW 格式打包**：

```
# 打包 trust
./make.sh trust

# 打包 loader
./make.sh loader

# 指定 ini 文件打包
./make.sh trust <ini-file>
./make.sh loader <ini-file>
```

> 编译与打包的完整流程以及 `make.sh` 的更多用法请参考"编译烧写"章节和"平台架构"章节的 Make.sh 部分。
