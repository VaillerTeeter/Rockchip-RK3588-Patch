# Rockchip U-Boot FIT 详解

本章详细介绍 **FIT**（Flattened Image Tree）固件格式及其在 Rockchip 平台上的安全/非安全启动方案。全文主要以 `boot.img` 为例进行说明，同样适用于 `recovery.img`。

> **说明**：FIT 格式的固件引导主要由 **SPL** 负责，相关概念和启动流程请参考“SPL 章节”；U-Boot 镜像格式的整体对比（RK 格式 vs FIT 格式）请参考“平台架构章节”。

## 一、FIT 基础

### 1.1 基本概念

**FIT**（Flattened Image Tree）是 U-Boot 原生支持的一种新固件引导方案，支持任意多个 Image 的打包和校验。FIT 使用 **ITS**（Image Source File）文件描述 Image 信息，最终通过 **mkimage** 工具生成 **ITB**（Flattened Image Tree Blob）镜像。

ITS 文件使用 DTS 的语法规则，非常灵活，可以直接使用 **libfdt** 库和相关工具。FIT 是 U-Boot 默认支持且主推的固件格式，SPL 和 U-Boot 阶段都支持对 FIT 格式的固件引导。

> **更多参考**：
> ```
> ./doc/uImage.FIT/
> ```

> **注意**：因为官方的 FIT 功能无法满足实际产品需求，Rockchip 平台对 FIT 进行了适配和优化。FIT 方案中**必须使用 Rockchip U-Boot 编译生成的 mkimage 工具**，不能使用 PC 自带的 mkimage。

### 1.2 ITS 范例

以下以 `u-boot.its` 和 `u-boot.itb` 作为范例进行介绍：

- **`/images`** 节点：静态定义所有可获取的资源（相当于 `dtsi` 文件的角色，最后可用或不用）；
- **`/configurations`** 节点：每个 `config` 子节点描述一套可启动的配置（相当于板级 `dts` 文件），通过 `default` 属性指定当前选用的默认配置。

```
/dts-v1/;

/ {
    description = "Simple image with OP-TEE support";
    #address-cells = <1>;

    images {
        uboot {
            description = "U-Boot";
            data = /incbin/("./u-boot-nodtb.bin");
            type = "standalone";
            os = "U-Boot";
            arch = "arm";
            compression = "none";
            load = <0x00400000>;
            hash {
                algo = "sha256";
            };
        };
        optee {
            description = "OP-TEE";
            data = /incbin/("./tee.bin");
            type = "firmware";
            arch = "arm";
            os = "op-tee";
            compression = "none";
            load = <0x8400000>;
            entry = <0x8400000>;
            hash {
                algo = "sha256";
            };
        };
        fdt {
            description = "U-Boot dtb";
            data = /incbin/("./u-boot.dtb");
            type = "flat_dt";
            compression = "none";
            hash {
                algo = "sha256";
            };
        };
    };

    // configurations 节点下可以定义任意多个不同的 conf 节点，但实际产品方案上我们只需要一个 conf 即可。
    configurations {
        default = "conf";
        conf {
            description = "Rockchip armv7 with OP-TEE";
            rollback-index = <0x0>;
            firmware = "optee";
            loadables = "uboot";
            fdt = "fdt";
            signature {
                algo = "sha256,rsa2048";
                padding = "pss";
                key-name-hint = "dev";
                sign-images = "fdt", "firmware", "loadables";
            };
        };
    };
};
```

**ITS → ITB 生成流程：**

```
                      mkimage + dtc
[u-boot.its] + [images] =========> [u-boot.itb]
```

### 1.3 ITB 文件内容

使用 **`fdtdump`** 命令可查看 ITB 文件内容：

```
cjh@ubuntu:~/uboot-nextdev/u-boot$ fdtdump fit/u-boot.itb | less

/dts-v1/;
// magic: 0xd00dfeed
// totalsize: 0x600 (1536)
// off_dt_struct: 0x48
// off_dt_strings: 0x48c
// off_mem_rsvmap: 0x28
// version: 17
// last_comp_version: 16
// boot_cpuid_phys: 0x0
// size_dt_strings: 0xc3
// size_dt_struct: 0x444

/memreserve/ 7f34d3411000 600;
/ {
    version = <0x00000001>;         // 新增固件版本号
    totalsize = <0x000bb600>;       // 新增字段描述整个 itb 文件的大小
    timestamp = <0x5ecb3553>;       // 新增当前固件生成时刻的时间戳
    description = "Simple image with OP-TEE support";
    #address-cells = <0x00000001>;
    images {
        uboot {
            data-size = <0x0007ed54>;      // 新增字段描述固件大小
            data-position = <0x00000a00>;  // 新增字段描述固件偏移
            description = "U-Boot";
            type = "standalone";
            os = "U-Boot";
            arch = "arm";
            compression = "none";
            load = <0x00400000>;
            hash {
                // 新增固件的 sha256 校验和
                value = <0xeda8cd52 0x8f058118 0x00000003 0x35360000 0x6f707465 0x0000009f 0x00000091 0x00000000>;
                algo = "sha256";
            };
        };
        optee {
            data-size = <0x0003a058>;
            data-position = <0x0007f800>;
            description = "OP-TEE";
            type = "firmware";
            arch = "arm";
            os = "op-tee";
            compression = "none";
            load = <0x08400000>;
            entry = <0x08400000>;
            hash {
                value = <0xa569b7fc 0x2450ed39 0x00000003 0x35360000 0x66647400 0x00001686 0x000b9a00 0x552d426f>;
                algo = "sha256";
            };
        };
        fdt {
            data-size = <0x00001686>;
            data-position = <0x000b9a00>;
            description = "U-Boot dtb";
            type = "flat_dt";
            compression = "none";
            hash {
                value = <0x0f718794 0x78ece7b2 0x00000003 0x35360000 0x00000001 0x6e730000 0x636f6e66 0x00000000>;
                algo = "sha256";
            };
        };
    };
    configurations {
        default = "conf";
        conf {
            description = "Rockchip armv7 with OP-TEE";
            rollback-index = <0x00000001>;  // 固件防回滚版本号，没有手动指定时默认为 0
            firmware = "optee";
            loadables = "uboot";
            fdt = "fdt";
            signature {
                algo = "sha256,rsa2048";
                padding = "pss";
                key-name-hint = "dev";
                sign-images = "fdt", "firmware", "loadables";
            };
        };
    };
};
```

### 1.4 ITB 结构

ITB 本质是 `fdt_blob + images` 的文件集合，有如下两种打包方式。Rockchip 平台方案采用**结构 2**。

```
               fdt blob
|-----------------------------------|
|     |------| |------| |------|    |
|     | img0 | | img1 | | img2 |    |  结构 1：image 在 fdt_blob 内，即 itb = fdt_blob(含 img)
|     |------| |------| |------|    |
|-----------------------------------|

|--------------|------|------|------|
|              |      |      |      |
| fdt blob     | img0 | img1 | img2 |  结构 2：image 在 fdt_blob 外，即 itb = fdt_blob + img
|              |      |      |      |
|--------------|------|------|------|
```

## 二、平台配置

### 2.1 芯片支持

目前作为正式 Feature 发布在 SDK 的平台，请参考各芯片的 Feature 支持状态表。已支持的平台通常涵盖以下芯片：

- **RV1126** 及之后的平台：默认采用 FIT 格式
- **RV1126** 之前的平台：采用 RK 格式（`uboot.img` + `trust.img`）

### 2.2 代码与配置

**框架代码：**

```
// 框架代码
./common/image.c
./common/image-fit.c
./common/spl/spl_fit.c

// 平台代码：
./arch/arm/mach-rockchip/fit.c
./cmd/bootfit.c

// 工具代码
./tools/mkimage.c
./tools/fit_image.c
```

**U-Boot 阶段配置：**

```
// U-Boot 阶段支持 FIT
CONFIG_ROCKCHIP_FIT_IMAGE=y

// U-Boot 阶段：安全启动、防回滚、硬件 Crypto
CONFIG_FIT_SIGNATURE=y
CONFIG_FIT_ROLLBACK_PROTECT=y
CONFIG_DM_CRYPTO=y
CONFIG_FIT_HW_CRYPTO=y

// SPL 阶段：安全启动、防回滚、硬件 Crypto
CONFIG_SPL_FIT_SIGNATURE=y
CONFIG_SPL_FIT_ROLLBACK_PROTECT=y
CONFIG_SPL_DM_CRYPTO=y
CONFIG_SPL_FIT_HW_CRYPTO=y

// uboot.img 镜像包含几份 uboot.itb，单份 uboot.itb 多大
CONFIG_SPL_FIT_IMAGE_KB=2048
CONFIG_SPL_FIT_IMAGE_MULTIPLE=2

// U-Boot 工程编译后默认输出 FIT 格式的 uboot.img；否则为传统的 RK 格式 uboot.img 和 trust.img。
CONFIG_ROCKCHIP_FIT_IMAGE_PACK=y
```

**RSA 参数配置：**

由于不同平台的 Crypto 模块可能不同，RSA 功能的配置参数也不同。具体请参考当前平台的通用 defconfig：

```
CONFIG_RSA_N_SIZE
CONFIG_RSA_E_SIZE
CONFIG_RSA_C_SIZE
```

通用 defconfig 示例：`[芯片]_defconfig`，例如 `rv1126_defconfig`、`rk3568_defconfig`。

> **说明**：如果 FIT 方案是作为 SDK 正式发布的 Feature，大部分基础配置已使能。用户需要自己配置的选项通常只有安全启动相关：
> ```
> // U-Boot 安全启动和防回滚机制
> CONFIG_FIT_SIGNATURE=y
> CONFIG_FIT_ROLLBACK_PROTECT=y
>
> // SPL 安全启动和防回滚机制
> CONFIG_SPL_FIT_SIGNATURE=y
> CONFIG_SPL_FIT_ROLLBACK_PROTECT=y
> ```

- **`CONFIG_FIT_SIGNATURE` 未使能**：U-Boot 可以同时支持引导三种格式的固件：Android、uImage、FIT（发布的 SDK 会根据平台需求选择开启哪几种支持）。
- **`CONFIG_FIT_SIGNATURE` 使能**：U-Boot 只支持引导 FIT 固件。

### 2.3 镜像文件

FIT 方案最终输出两个 FIT 格式的固件用于烧写：**`uboot.img`**（没有 `trust.img`）和 **`boot.img`**，还有一个 SPL 文件用于打包成 Loader。

| 固件 | 组成 | 说明 |
|------|------|------|
| **`uboot.img`** | `uboot.itb = trust + u-boot.bin + mcu.bin`（可选） | `uboot.img = uboot.itb × N` 份（N 一般是 2）。trust 和 mcu 文件来自 rkbin 工程，编译脚本会自动索引并获取。 |
| **`boot.img`** | `boot.itb = kernel + fdt + resource + ramdisk`（可选） | `boot.img = boot.itb × M` 份（M 一般是 1） |
| **SPL 文件** | `spl/u-boot-spl.bin` | 负责引导 FIT 格式的 `uboot.img`。用户需要用其替换不开源的 Miniloader，最终打包出 Loader。 |

**MCU 配置：**

目前某些平台可能带有 MCU 固件，不同产品可以根据相应的 TRUST ini 配置来决定是否启用。例如：

```
// 文件：RKTRUST/RV1126TOS_TB.ini，用于快速开机产品，启用了 MCU。
[TOS]
TOSTA=bin/rv11/rv1126_tee_ta_tb_v1.04.bin
ADDR=0x00040000

// MCU 配置格式：固件路径，启动地址，状态(okay 或 disabled)。
// 如果为 disabled，则 MCU 不会被打包进 uboot.img 中。
[MCU]
MCU=bin/rv11/rv1126_mcu_v1.02.bin,0x108000,okay
```

**固件压缩：**

目前某些平台可以支持 `uboot.img` 内部子固件的压缩：

| 平台 | 压缩格式 | 固件 |
|------|----------|------|
| RV1126 | gzip、none | u-boot.bin, trust, mcu（可选） |

用户可以在 rkbin 工程中对应的 TRUST ini 增加属性来启用。例如：

```
// 文件：RKTRUST/RV1126TOS_SPI_NOR_TINY.ini，用于小容量 SPI NOR 产品。
[TOS]
TOS=bin/rv11/rv1126_tee_v1.02.bin
ADDR=0x08400000
[MCU]
MCU=bin/rv11/rv1126_mcu_v1.00.bin,0x208000,disabled

// 压缩格式：gzip 或 none，不存在如下配置字段则默认非压缩。
[COMPRESSION]
COMPRESSION=gzip
```

**`./fit` 目录：**

U-Boot 编译完成后会在目录下生成 `./fit` 文件夹，包含一些中间文件，后续章节会介绍。

> **说明**：`boot.img` 和 `uboot.img` 分别在 SDK 工程和 U-Boot 工程下被编译生成。但是**支持安全启动的 `boot.img` 必须放在 U-Boot 工程下重新打包签名**，后续章节会介绍。

### 2.4 ITS 文件

| 固件 | ITS 文件位置 | 说明 |
|------|-------------|------|
| **U-Boot ITS** | `./fit/u-boot.its` | 由 defconfig 中 `CONFIG_SPL_FIT_GENERATOR` 指定的脚本动态创建，固件编译成功后可见 |
| **Boot ITS** | `device/rockchip/[platform]/xxx.its` | 位于 SDK 工程下，`[platform]` 是平台目录 |

## 三、工具与脚本

### 3.1 核心工具

```
// 核心打包工具，编译完成后会自动生成。U-Boot 和 rkbin 仓库下都有（U-Boot 仓库下是实时编译生成）。
./tools/mkimage

// 固件打包脚本
./make.sh

// 固件重签名脚本
scripts/fit-resign.sh

// 固件解包脚本
scripts/fit-unpack.sh

// 固件替换脚本
scripts/fit-repack.sh
```

脚本工具的使用在后续章节会介绍，此处先重点介绍 `make.sh` 的参数。

### 3.2 make.sh 参数

**可选项**（用户根据实际情况决定是否传递）：

| 参数 | 说明 |
|------|------|
| `--spl-new` | 传递此参数，表示使用当前编译的 SPL 文件打包 Loader；否则使用 rkbin 工程里的 SPL 文件 |
| `--version-uboot [n]` | 指定 `uboot.img` 的固件版本号，n 必须是十进制正整数 |
| `--version-boot [n]` | 指定 `boot.img` 的固件版本号，n 必须是十进制正整数 |
| `--version-recovery [n]` | 指定 `recovery.img` 的固件版本号，n 必须是十进制正整数 |

**必选项**（启用安全启动的情况）：

| 参数 | 说明 |
|------|------|
| `--rollback-index-uboot [n]` | 指定 `uboot.img` 固件防回滚版本号，n 必须是十进制正整数 |
| `--rollback-index-boot [n]` | 指定 `boot.img` 固件防回滚版本号，n 必须是十进制正整数 |
| `--rollback-index-recovery [n]` | 指定 `recovery.img` 固件防回滚版本号，n 必须是十进制正整数 |
| `--no-check` | 打包安全固件时被使用，用于跳过安全固件打包脚本的自校验 |

> **说明**：
> - **固件防回滚版本号**：只有在启用了安全启动的前提下才允许被激活使用，该版本号保存在 OTP 或其它安全存储中。主要作用是防止固件版本被回退后进行漏洞攻击。
> - **固件版本号**：可选，不指定的情况下默认为 0。主要作用只是作为固件版本标识，方便用户对固件进行版本管理。

## 四、非安全启动

### 4.1 uboot.img

**编译命令：**

```
./make.sh rv1126 --spl-new --version-uboot 10   # 可不指定 --spl-new 和 --version-uboot
```

**编译结果：**

```
    ......
    CC spl/common/spl/spl.o
    CC spl/lib/display_options.o
    LD spl/common/spl/built-in.o
    LD spl/lib/built-in.o
    LD spl/u-boot-spl
    OBJCOPY spl/u-boot-spl-nodtb.bin
    CAT spl/u-boot-spl-dtb.bin
    COPY spl/u-boot-spl.bin
    CFGCHK u-boot.cfg

out:rv1126_spl_loader_v1.00.100.bin
fix opt:rv1126_spl_loader_v1.00.100.bin
merge success(rv1126_spl_loader_v1.00.100.bin)
/home4/cjh/uboot-nextdev

// 生成 rv1126_spl_loader_v1.00.100.bin（用 SPL 替代了 RK 平台传统的 Miniloader）
// loader ini 文件来源
pack loader(SPL) okay! Input: /home4/cjh/rkbin/RKBOOT/RV1126MINIALL.ini
// 来自 --spl-new 参数的提示；用户可以选择不加这个参数。
pack loader with new: spl/u-boot-spl.bin

// 生成 uboot.img（包含 trust 和 U-Boot），版本号为 10
Image(no-signed, version=10): uboot.img (FIT with uboot, trust...) is ready
// trust ini 文件来源
pack uboot.img okay! Input: /home4/cjh/rkbin/RKTRUST/RV1126TOS.ini

Platform RV1126 is build OK, with exist .config
```

**打包备份：**

通过 defconfig 配置指定 `uboot.img` 的多备份：

```
CONFIG_SPL_FIT_IMAGE_KB=2048       // 单份 ITB 大小
CONFIG_SPL_FIT_IMAGE_MULTIPLE=2    // 打包的份数
```

SPL 根据这个配置去探测和引导 U-Boot 和 Trust，主要是应对 OTA 升级过程中异常掉电引起的固件损坏而无法启动的问题。

### 4.2 boot.img

FIT 方案如果作为 SDK 正式发布的 Feature，SDK 编译完成后会生成 FIT 格式的 `boot.img`。

> **注意**：如果要生成安全启动用的 `boot.img`，必须把 SDK 生成的 `boot.img` 放到 U-Boot 工程下重新打包并签名，因为安全固件打包的签名工具、配置、参数等都来源于 U-Boot 工程。

## 五、安全启动

FIT 方案支持安全启动，相关的 Feature：

- **sha256 + rsa2048 + pkcs-v2.1(pss) padding**
- 固件防回滚
- 固件重签名（远程签名）
- Crypto 硬件加速

### 5.1 校验原理

#### 5.1.1 校验流程

```
Maskrom → 校验 loader（包含 SPL, DDR, USB-Plug）
   SPL  → 校验 uboot.img（包含 Trust、U-Boot...）
U-Boot  → 校验 boot.img（包含 Kernel, FDT, Ramdisk...）
```

目前默认只支持 **sha256 + rsa2048 + pkcs-v2.1(pss) padding** 的安全校验模式。

#### 5.1.2 Key 存放

RSA Key 被 mkimage 打包在 `u-boot.dtb` 和 `u-boot-spl.dtb` 中，然后它们再被打包进 `u-boot.bin` 和 `u-boot-spl.bin`。

`u-boot.dtb` 里 RSA Key 的格式如下（同理 `u-boot-spl.dtb`）：

```
cjh@ubuntu:~/uboot-nextdev$ fdtdump u-boot.dtb | less
/dts-v1/;
....

/ {
    #address-cells = <0x00000001>;
    #size-cells = <0x00000001>;
    compatible = "rockchip,rv1126-evb", "rockchip,rv1126";
    model = "Rockchip RV1126 Evaluation Board";

    // signature 节点由 mkimage 工具自动插入生成，节点里保存了 RSA-SHA 算法类型、RSA 核心因子参数等信息。
    signature {
        key-dev {
            required = "conf";
            algo = "sha256,rsa2048";
            rsa,np = <0x00000000 0x00000000 ...>;
            rsa,c = <0x00000000>;
            rsa,r-squared = <0x00000000>;
            rsa,modulus = <0xc25ae693 0xc359f2a4 ...>;
            rsa,exponent-BN = <0x00000000 0x00000000 ...>;
            rsa,exponent = <0x00000000 0x00000368>;
            rsa,n0-inverse = <0xe95771c5>;
            rsa,num-bits = <0x00000800>;
            key-name-hint = "dev";
        };
    };
};
```

> **说明**：SPL 支持烧写 Key Hash 的功能，`u-boot-spl.dtb` 的 `key-dev` 会多出 `burn-key-hash = <0x00000001>;`。

#### 5.1.3 Key 使用

从 Maskrom 到 Kernel 为止的安全启动，统一使用**一把 RSA 公钥**完成安全校验：

| 阶段 | 校验方式 |
|------|----------|
| **Maskrom 校验 Loader** | RSA 公钥需要使用 PC 工具 `rk_sign_tool` 写入 Loader 的文件头中。安全启动时，Maskrom 首先从 Loader 固件头中获取 RSA 公钥并校验合法性，然后再使用该公钥校验 Loader 的固件签名。`rk_sign_tool` 可从 rkbin 仓库中获取，U-Boot 会自动完成对 Loader 的签名。 |
| **SPL 校验 U-Boot 和 Trust** | SPL 把 RSA 公钥保存在 `u-boot-spl.dtb` 中，`u-boot-spl.dtb` 会被打包进 `u-boot-spl.bin` 文件（最后打包进 Loader）。安全启动时 SPL 从自己的 DTB 文件中拿出 RSA 公钥对 `uboot.img` 进行安全校验。 |
| **U-Boot 校验 Boot** | U-Boot 把 RSA 公钥保存在 `u-boot.dtb` 中，`u-boot.dtb` 会被打包进 `u-boot.bin` 文件（最后打包为 `uboot.img`）。安全启动时 U-Boot 从自己的 DTB 文件中拿 RSA 公钥对 `boot.img` 进行校验。 |

因此，当前这一级的 RSA Key 已经作为自身固件的一部分，由前一级 Loader 完成了安全校验，从而保证了 Key 的安全。

#### 5.1.4 签名存放

RSA 的签名结果被保存在 ITB 文件中。被签名内容由 **`hashed-nodes`** 指定：包括了整个 `conf` 节点的属性、被打包固件的节点等。

如下是 `u-boot.itb` 的签名信息（同理 `boot.itb`）：

```
cjh@ubuntu:~/uboot-nextdev$ fdtdump uboot.img | less
/dts-v1/;
......
    configurations {
        default = "conf";
        conf {
            description = "Rockchip armv7 with OP-TEE";
            // 当前的固件版本号
            rollback-index = <0x0000001c>;
            firmware = "optee";
            loadables = "uboot";
            fdt = "fdt";

            // 被签名内容和签名结果，由 mkimage 自动插入
            signature {
                hashed-strings = <0x00000000 0x000000da>;
                // 指定被签名内容
                hashed-nodes = "/", "/configurations", "/configurations/conf",
                    "/images/fdt", "/images/fdt/hash",
                    "/images/optee", "/images/optee/hash",
                    "/images/uboot", "/images/uboot/hash";
                // 进行签名的时间、签名者、版本
                timestamp = <0x5e9427b4>;
                signer-version = "2017.09-g8bb63db-200413-dirty #cjh";
                signer-name = "mkimage";
                // 签名结果！！（采用 sha256 + rsa2048）
                value = <0x78397d5d 0xb9219a0b ...>;
                algo = "sha256,rsa2048";
                key-name-hint = "dev";
                sign-images = "fdt", "firmware", "loadables";
            };
        };
    };
```

#### 5.1.5 防回滚

- 安全启动支持对 `boot.img` 和 `uboot.img` 分别指定当前固件版本号。如果当前固件版本号小于机器上的最小版本号，则不允许启动。
- 最小版本号的更新：完成安全校验且确认系统可以正常启动后，被更新到 OTP 或安全存储中。

### 5.2 前期准备

#### 5.2.1 生成 Key

在 U-Boot 工程下执行以下步骤生成签名用的 RSA 密钥对。通常情况下只需要生成一次，此后都用这对密钥签名和验证固件，**请妥善保管**。

**步骤 1：创建 keys 目录。**

```
mkdir -p keys
```

**步骤 2：使用 RK 的 `rk_sign_tool` 工具生成 RSA2048 的私钥 `privateKey.pem` 和公钥 `publicKey.pem`**（请参考 `rk_sign_tool` 的使用手册），分别更名存放为 `keys/dev.key` 和 `keys/dev.pubkey`。

**步骤 3：使用 `-x509` 和私钥生成一个自签名证书 `keys/dev.crt`**（效果本质等同于公钥）。

```
openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt
```

> **注意**：如果报错用户目录下没有 `.rnd` 文件：
> ```
> Can't load /home4/cjh//.rnd into RNG
> ```
> 请先手动创建：`touch ~/.rnd`

**最终 keys 目录结构：**

```
dev.crt dev.key dev.pubkey
```

> **注意**：上述的 `"keys"`、`"dev.key"`、`"dev.crt"`、`"dev.pubkey"` 名字都**不可变**。因为这些名字已经在 ITS 文件中静态定义，如果改变则会打包失败。

#### 5.2.2 安全配置

在 U-Boot 的 defconfig 中打开如下配置：

```
// 必选。
CONFIG_FIT_SIGNATURE=y
CONFIG_SPL_FIT_SIGNATURE=y

// 可选。
CONFIG_FIT_ROLLBACK_PROTECT=y       // boot.img 防回滚
CONFIG_SPL_FIT_ROLLBACK_PROTECT=y   // uboot.img 防回滚
```

> **建议**：通过 `make menuconfig` 的方式选中配置后，再通过 `make savedefconfig` 更新原本的 defconfig 文件。这样可以避免因为强加 defconfig 配置而导致依赖关系不对，进而导致编译失败的情况。

#### 5.2.3 准备固件

把 SDK 工程下生成的 `boot.img` 复制一份到 U-Boot 根目录下。

### 5.3 编译打包

#### 5.3.1 基础命令（不防回滚）

```
./make.sh rv1126 --spl-new --boot_img boot.img --recovery_img recovery.img
```

**编译结果：**

```
......
// 编译完成后，生成已签名的 uboot.img 和 boot.img。
start to sign rv1126_spl_loader_v1.00.100.bin
......
sign loader ok.
......
Image(signed, version=0): uboot.img (FIT with uboot, trust...) is ready
Image(signed, version=0): recovery.img (FIT with kernel, fdt, resource...) is ready
Image(signed, version=0): boot.img (FIT with kernel, fdt, resource...) is ready
Image(signed): rv1126_spl_loader_v1.05.106.bin (with spl, ddr, usbplug) is ready
pack uboot.img okay! Input: /home4/cjh/rkbin/RKTRUST/RV1126TOS.ini
Platform RV1126 is build OK, with new .config(make rv1126-secure_defconfig)
```

#### 5.3.2 扩展命令 1：防回滚

如果开启防回滚，必须追加 rollback 参数。例如：

```
// 指定 uboot.img 和 boot.img 的最小版本号分别为 10、12。
./make.sh rv1126 --spl-new --boot_img boot.img --recovery_img recovery.img \
    --rollback-index-uboot 10 --rollback-index-boot 12 --rollback-index-recovery 12
```

**编译结果：**

```
......
// 编译完成后，生成已签名的 uboot.img 和 boot.img，且包含防回滚版本号。
start to sign rv1126_spl_loader_v1.00.100.bin
......
sign loader ok.
......
Image(signed, version=0, rollback-index=10): uboot.img (FIT with uboot, trust) is ready
Image(signed, version=0, rollback-index=12): recovery.img (FIT with kernel, fdt, resource...) is ready
Image(signed, version=0, rollback-index=12): boot.img (FIT with kernel, fdt, resource...) is ready
Image(signed): rv1126_spl_loader_v1.00.100.bin (with spl, ddr, usbplug) is ready
```

#### 5.3.3 扩展命令 2：烧写 Key Hash

如果要把公钥 Hash 烧写到 OTP/eFUSE，必须追加参数 `--burn-key-hash`。例如：

```
// 指定 uboot.img 和 boot.img 的最小版本号分别为 10、12。
// 要求 SPL 阶段把公钥 Hash 烧写到 OTP/eFUSE 中。
./make.sh rv1126 --spl-new --boot_img boot.img --recovery_img recovery.img \
    --rollback-index-uboot 10 --rollback-index-boot 12 --rollback-index-recovery 12 --burn-key-hash
```

**编译结果：**

```
......
// 使能 burn-key-hash
### spl/u-boot-spl.dtb: burn-key-hash=1
// 编译完成后，生成已签名的 uboot.img 和 boot.img，且包含防回滚版本号。
start to sign rv1126_spl_loader_v1.00.100.bin
......
sign loader ok.
......
Image(signed, version=0, rollback-index=10): uboot.img (FIT with uboot, trust) is ready
Image(signed, version=0, rollback-index=12): recovery.img (FIT with kernel, fdt, resource...) is ready
Image(signed, version=0, rollback-index=12): boot.img (FIT with kernel, fdt, resource...) is ready
Image(signed): rv1126_spl_loader_v1.00.100.bin (with spl, ddr, usbplug) is ready
```

上电开机时能看到 SPL 打印：`RSA: Write key hash successfully`。

#### 5.3.4 参数说明

| 参数 | 说明 |
|------|------|
| `--boot_img` | 可选。指定待签名的 `boot.img`。 |
| `--recovery_img` | 可选。指定待签名的 `recovery.img`。 |
| `--rollback-index-uboot` | 可选。指定 `uboot.img` 防回滚版本号。 |
| `--rollback-index-boot` | 可选。指定 `boot.img` 防回滚版本号。 |
| `--rollback-index-recovery` | 可选。指定 `recovery.img` 防回滚版本号。 |
| `--spl-new` | 如果编译命令不带此参数，则默认使用 rkbin 中的 SPL 文件打包生成 Loader；否则使用当前编译的 SPL 文件打包 Loader。 |
| `--burn-key-hash` | SPL 阶段把公钥 Hash 烧写到 OTP/eFUSE。**注意：该参数应在整个产品开发验证完后再配置，否则安全开启后，产品开发过程中每次只能更新签名过的固件。** |

> **说明**：因为 `u-boot-spl.dtb` 中需要被打包进 RSA 公钥（来自于用户），所以 RK 发布的 SDK 不会在 rkbin 仓库提交支持安全启动的 SPL 文件。因此用户编译时要指定 `--spl-new` 参数。但是用户也可以把自己的 SPL 版本提交到 rkbin 工程，此后编译固件时就可以不再指定此参数，每次都使用这个稳定版的 SPL 文件。

> **注意**：编译后会生成三个固件：**Loader**、**`uboot.img`**、**`boot.img`**。只要 RSA Key 没有更换，就允许单独更新其中的任意固件。

### 5.4 校验原则

| 校验阶段 | 配置条件 | 行为 |
|----------|----------|------|
| **Maskrom 校验 SPL** | OTP 没有烧写 Key | Maskrom 走非安全启动流程 |
| | OTP 有烧写 Key | Maskrom 校验 Loader 里的 Key，必须跟 OTP 里的一致才会开始进行安全校验，不一致就不让启动 |
| **SPL 校验 U-Boot** | `CONFIG_SPL_FIT_SIGNATURE=y` | SPL **一定**会对 `uboot.img` 进行安全校验，校验成功才启动；`uboot.img` 没有签名或校验失败，不启动 |
| | `CONFIG_SPL_FIT_SIGNATURE=n` | SPL 本身没包含安全启动相关的代码，一定不会校验 `uboot.img`（无论是否签名） |
| **U-Boot 校验 Boot/Recovery** | `CONFIG_FIT_SIGNATURE=y` | U-Boot **一定**会对 `boot.img` / `recovery.img` 进行安全校验，校验成功才启动；没有签名或校验失败，不启动 |
| | `CONFIG_FIT_SIGNATURE=n` | U-Boot 本身没包含安全启动相关的代码，一定不会校验 `boot.img` / `recovery.img`（无论是否签名） |

> **注意**：当前这一级是否会去校验后一级，跟当前这级固件是否被签名**没有任何关系**。只取决于自身是否包含安全启动的相关代码，即上述配置是否为 `y`。

### 5.5 启动信息

如下是安全启动的完整打印信息：

```
BW=32 Col=10 Bk=8 CS0 Row=15 CS=1 Die BW=16 Size=1024MB
out
U-Boot SPL board init
U-Boot SPL 2017.09-gacb99c5-200408-dirty #cjh (Apr 09 2020 - 20:51:21)
unrecognized JEDEC id bytes: 00, 00, 00

Trying to boot from MMC1
// SPL 完成签名校验
sha256,rsa2048:dev+
// 防回滚检测：当前 uboot.img 固件版本号是 10，本机的最小版本号是 9
rollback index: 10 >= 9, OK
// SPL 完成各子镜像的 hash 校验
### Checking optee ... sha256+ OK
### Checking uboot ... sha256+ OK
### Checking fdt ... sha256+ OK

Jumping to U-Boot via OP-TEE
I/TC:
E/TC:0 0 plat_rockchip_pmu_init:2003 0
E/TC:0 0 plat_rockchip_pmu_init:2006 cpu off
E/TC:0 0 plat_rockchip_pmusram_prepare:1945 pmu sram prepare 0x14b10000 0x8400880 0x1c
E/TC:0 0 plat_rockchip_pmu_init:2020 pmu sram prepare
E/TC:0 0 plat_rockchip_pmu_init:2056 remap
I/TC: OP-TEE version: 3.6.0-233-g35ecf936 #1 Tue Mar 31 08:46:13 UTC 2020 arm
I/TC: Next entry point address: 0x00400000
I/TC: Initialized

U-Boot 2017.09-gacb99c5-200408-dirty #cjh (Apr 09 2020 - 20:51:21 +0800)

Model: Rockchip RV1126 Evaluation Board
PreSerial: 2
DRAM: 1023.5 MiB
Sysmem: init
Relocation Offset: 00000000, fdt: 3df404e0
Using default environment
dwmmc@ffc50000: 0
Bootdev(atags): mmc 0
MMC0: HS200, 200Mhz
PartType: EFI
boot mode: normal
conf: sha256,rsa2048:dev+
resource: sha256+
DTB: rk-kernel.dtb
FIT: signed, conf required
HASH(c): OK

I2c0 speed: 400000Hz
PMIC: RK8090 (on=0x10, off=0x00)
vdd_logic 800000 uV
vdd_arm 800000 uV
vdd_npu init 800000 uV
vdd_vepu init 800000 uV
......
Hit key to stop autoboot('CTRL+C'): 0
### Booting FIT Image at 0x3d8122c0 with size 0x0052b200
Fdt Ramdisk skip relocation
### Loading kernel from FIT Image at 3d8122c0 ...
    Using 'conf' configuration
    // U-Boot 完成签名校验
    Verifying Hash Integrity ... sha256,rsa2048:dev+ OK
    // 防回滚检测：当前 boot.img 固件版本号是 22，本机的最小版本号是 21
    Verifying Rollback-index ... 22 >= 21, OK
    Trying 'kernel' kernel subimage
        Description: Kernel for arm
        Type: Kernel Image
        Compression: uncompressed
        Data Start: 0x3d8234c0
        Data Size: 5349248 Bytes = 5.1 MiB
        Architecture: ARM
        OS: Linux
        Load Address: 0x02008000
        Entry Point: 0x02008000
        Hash algo: sha256
        Hash value: 64b4a0333f7862967be052a67ee3858884fcefebf4565db5c3828a941a15f34a
    Verifying Hash Integrity ... sha256+ OK  // 完成 kernel 的 hash 校验
    ### Loading ramdisk from FIT Image at 3d8122c0 ...
    Using 'conf' configuration
    Trying 'ramdisk' ramdisk subimage
        Description: Ramdisk for arm
        Type: RAMDisk Image
        Compression: uncompressed
        Data Start: 0x3dd3d4c0
        Data Size: 0 Bytes = 0 Bytes
        Architecture: ARM
        OS: Linux
        Load Address: 0x0a200000
        Entry Point: unavailable
        Hash algo: sha256
        Hash value: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    Verifying Hash Integrity ... sha256+ OK  // 完成 ramdisk 的 hash 校验
    Loading ramdisk from 0x3dd3d4c0 to 0x0a200000
    ### Loading fdt from FIT Image at 3d8122c0 ...
    Using 'conf' configuration
    Trying 'fdt' fdt subimage
        Description: Device tree blob for arm
        Type: Flat Device Tree
        Compression: uncompressed
        Data Start: 0x3d812ec0
        Data Size: 66974 Bytes = 65.4 KiB
        Architecture: ARM
        Load Address: 0x08300000
        Hash algo: sha256
        Hash value: 8fb1f170766270ed4f37cce4b082a51614cb346c223f96ddfe3526fafc5729d7
    Verifying Hash Integrity ... sha256+ OK  // 完成 fdt 的 hash 校验
    Loading fdt from 0x3d812ec0 to 0x08300000
    Booting using the fdt blob at 0x8300000
    Loading Kernel Image from 0x3d8234c0 to 0x02008000 ... OK
    Using Device Tree in place at 08300000, end 0831359d
Adding bank: 0x00000000 - 0x08400000 (size: 0x08400000)
Adding bank: 0x0848a000 - 0x40000000 (size: 0x37b76000)
Total: 236.327 ms

Starting kernel ...

[ 0.000000] Booting Linux on physical CPU 0xf00
[ 0.000000] Linux version 4.19.111 (cjh@ubuntu) (gcc version 6.3.1 20170404 (Linaro GCC 6.3-2017.05)) #28 SMP PREEMPT Wed Mar 25 16:03:27 CST 2020
[ 0.000000] CPU: ARMv7 Processor [410fc075] revision 5 (ARMv7), cr=10c5387d
```

### 5.6 安全校验操作流程（Step-by-Step）

以下为完整的操作步骤摘要，便于快速参考：

**步骤 1：配置 defconfig**

打开对应平台的 `configs/rxxxxx_defconfig`，选择如下配置：

```
// 必选。
CONFIG_FIT_SIGNATURE=y
CONFIG_SPL_FIT_SIGNATURE=y

// 可选。
CONFIG_FIT_ROLLBACK_PROTECT=y       // boot.img 防回滚
CONFIG_SPL_FIT_ROLLBACK_PROTECT=y   // uboot.img 防回滚
```

**步骤 2：生成 Keys**

```
mkdir -p keys
../rkbin/tools/rk_sign_tool kk --bits 2048 --out .
cp privateKey.pem keys/dev.key && cp publicKey.pem keys/dev.pubkey
openssl req -batch -new -x509 -key keys/dev.key -out keys/dev.crt
```

> **说明**：该步骤执行一次即可，然后妥善保存这些 Keys。

**步骤 3：编译签名**（以 RV1126 为例，其他芯片替换芯片名即可）

```
// Linux：拷贝 boot.img、recovery.img 到 U-Boot 目录下，执行下列脚本签名
// loader, uboot, boot, recovery，设置 uboot, boot, recovery 的防版本回滚号
./make.sh rv1126 --spl-new --boot_img boot.img --recovery_img recovery.img \
    --rollback-index-uboot 1 --rollback-index-boot 2

// Android：签名 loader, uboot，设置 uboot 的防版本回滚号
./make.sh rv1126 --spl-new --rollback-index-uboot 1
```

> **注意**：如果编译出现 `Can't load XXXXXX//.rnd into RNG`，请执行：`touch ~/.rnd`

**步骤 4：烧写公钥 Hash（可选，仅最终量产时使用）**

```
// Linux
./make.sh rv1126 --spl-new --boot_img boot.img --recovery_img recovery.img \
    --rollback-index-uboot 1 --rollback-index-boot 2 --burn-key-hash

// Android
./make.sh rv1126 --spl-new --rollback-index-uboot 1 --burn-key-hash
```

> **注意**：该步骤应在整个产品开发验证完后再配置 `--burn-key-hash`，否则安全开启后，产品开发过程中每次只能更新签名过的固件。

**步骤 5：Android 其他固件签名**

参考《Rockchip_Developer_Guide_Secure_Boot_for_UBoot_Next_Dev_CN.md》。

## 六、远程签名

从上述章节可以看出，制作安全固件时要求用户在本地 PC 上完成，即用户必须持有 RSA 密钥对和固件。但在实际场景中，用户可能需要把固件上传到远程服务器，由服务器持有 RSA 私钥完成签名，然后把签名过的固件返回给本地用户。对于这种情况，RK 的 FIT 方案需要通过**"重签名"**实现。

### 6.1 实现思路

- 因为只能拿到服务器的公钥，所以用户先用**临时私钥 + 服务器公钥**在本地 PC 上对固件进行一次打包签名，会生成带有临时签名的安全固件和被签名数据。
  - 公钥的作用是为了把公钥打包进 DTB 文件，在安全启动流程时使用；私钥的作用是做临时签名。
- 用户把**被签名数据**发送给服务器即可（不需整个固件，更节省时间），服务器使用私钥对被签名数据进行签名，然后把签名返回给用户。
- 用户使用这份签名替换安全固件中的临时签名即可获得最后用于烧写的安全固件。

### 6.2 被签名数据

上述章节提到的被签名数据包含：**FDT Blob 配置 + 子镜像 Hash 集合**。

**FDT Blob 节点配置：**

`hashed-nodes` 指定了一系列节点，这些节点的内容都会纳入被签名数据。

```
cjh@ubuntu:~/uboot-nextdev$ fdtdump uboot.img | less
/dts-v1/;
......
    configurations {
        default = "conf";
        conf {
            description = "Rockchip armv7 with OP-TEE";
            rollback-index = <0x0000001c>;
            firmware = "optee";
            loadables = "uboot";
            fdt = "fdt";

            signature {
                hashed-strings = <0x00000000 0x000000da>;
                // 这些节点的内容都会纳入被签名数据
                hashed-nodes = "/", "/configurations/conf",
                    "/images/fdt", "/images/fdt/hash",
                    "/images/optee", "/images/optee/hash",
                    "/images/uboot", "/images/uboot/hash";
                ......
```

**子镜像 Hash 的集合：**

mkimage 会为各个子镜像自动生成 Hash 值，并追加进 `hash` 节点。`sign-images` 指定的所有子镜像 Hash 值都会纳入被签名数据（本质是通过 `hashed-nodes` 进行指定了 `hash` 节点）。例如：

```
cjh@ubuntu:~/uboot-nextdev/u-boot$ fdtdump fit/u-boot.itb | less

/dts-v1/;
......
/ {
    totalsize = <0x000bb600>;
    timestamp = <0x5ecb3553>;
    description = "Simple image with OP-TEE support";
    #address-cells = <0x00000001>;
    images {
        uboot {
            data-size = <0x0007ed54>;
            data-position = <0x00000a00>;
            description = "U-Boot";
            type = "standalone";
            os = "U-Boot";
            arch = "arm";
            compression = "none";
            load = <0x00400000>;
            hash {
                // uboot 镜像的 hash，由 mkimage 工具自动计算生成
                value = <0xeda8cd52 0x8f058118 0x00000003 0x35360000 0x6f707465 0x0000009f 0x00000091 0x00000000>;
                algo = "sha256";
            };
        };
        ......
```

### 6.3 具体步骤

假设用于签名固件的 RSA 密钥对是：`dev.key`、`dev.pubkey` 和 `dev.crt`。`dev.key` 作为私钥由远程服务器持有，用户只有 `dev.pubkey` 和 `dev.crt`。

**步骤 1：本地生成临时签名固件**

在本地 U-Boot 工程环境下，用户把 `dev.crt` 放到 `keys` 目录下，然后用 RK 的 `rk_sign_tool` 工具随机生成一把临时私钥，命名为 `dev.key` 放到 `keys` 目录下。参考上面的章节（但是编译参数要追加 `--no-check`）生成签名固件 `uboot.img` 和 `boot.img`（实际最后不会被使用，用户需要的是中间文件）。

> **注意**：编译命令要指定参数 `--no-check`，否则会因为 `dev.key` 和 `dev.crt` 不匹配导致打包脚本自校验失败。例如：
> ```
> ./make.sh rv1126 --spl-new --boot_img boot.img \
>     --rollback-index-uboot 10 --rollback-index-boot 12 --no-check
> ```

除了生成签名固件 `uboot.img` 和 `boot.img`，用户还可以在 `fit/` 目录下得到中间文件：

```
// 被签名内容（data2sign 意为：data to sign）
fit/uboot.data2sign
fit/boot.data2sign

// 已签名 ITB 文件（使用临时私钥），我们的 img 文件由它们进行多备份后获得。
fit/uboot.itb
fit/boot.itb
```

**步骤 2：远程签名**

用户把 `uboot.data2sign` 发送给远程服务器。假设远程服务器持有的私钥为 `dev.key`，使用如下命令签名并输出签名结果 `uboot.sig`：

```
openssl dgst -sha256 -sign dev.key -sigopt rsa_padding_mode:pss -out uboot.sig uboot.data2sign
```

**步骤 3：替换签名**

服务器把签名结果文件 `uboot.sig` 返回给用户，用户使用 `uboot.sig` 替换 `uboot.itb` 中的临时签名：

```
./scripts/fit-resign.sh -f fit/uboot.itb -s uboot.sig   # 会生成新的 uboot.img，用于烧写
```

同理处理 `boot.itb` 文件。由此用户获得了最终有效的签名固件 `uboot.img` 和 `boot.img`。

> **注意**：
> - `fit-resign.sh` 时 `-f` 指定的 ITB 文件不是 IMG 文件。脚本会对 ITB 重签名后生成 IMG 文件。
> - 执行 `fit-resign.sh` 时用的 ITB 文件必须是步骤 1 编译生成的，即 ITB 文件和 `data2sign` 文件是一对一对应的，因为 `data2sign` 信息中包含了生成 ITB 文件的时间戳，即 `/timestamp = <...>`。所以即使当前没有任何代码改动，重新编译获得一个新的 `uboot.itb`，把 `uboot.sig` 替换进新的 `uboot.itb` 中也会引起安全启动失败！
> - 由于没有私钥，Loader 需要单独发送到服务器端进行签名。

### 6.4 其他方案分析

除了"重签名"方式，是否可以直接上传整个固件（`boot.img`、`uboot.img`）或分立镜像（`u-boot.bin`、FDT、Ramdisk、Kernel...）给服务器进行签名？

| 方案 | 问题点 |
|------|--------|
| **方案一**：上传非安全的 `boot.img`、`uboot.img` 给服务器重新打包+签名 | 还需要上传本地 U-Boot 编译环境下的配置信息、`u-boot-spl.bin` 文件等 |
| **方案二**：上传安全的 `boot.img`、`uboot.img` 给服务器重新打包+签名 | 本地编译固件时已经打包了 RSA 公钥，服务器会进行 RSA 公钥二次打包 |
| **方案三**：上传所有分立镜像（Kernel, DTB, Ramdisk, Resource...）进行打包+签名 | 上传文件太多，比较繁琐，而且同样存在方案一的问题 |

以上方案的共同问题点：服务器端必须使用 RK 的 mkimage 工具，而这个工具有可能被 RK 更新。

> **总结**：目前的"重签名"是操作最简便、没有依赖、最不容易出错的方案——用户只需上传被签名数据，服务器使用 `openssl` 命令签名即可。

## 七、固件解包

用户可以借助脚本对固件解包，例如 `boot.img`：

```
cjh@ubuntu:~/uboot-nextdev$ ./scripts/fit-unpack.sh -f boot.img -o out
Unpack to directory out:
    fdt : 82813 bytes... sha256+
    kernel : 5844640 bytes... sha256+
    ramdisk : 0 bytes... sha256+
    resource : 120832 bytes... sha256+
```

> **说明**：如果 IMG 包含多备份，脚本只解包第一份 ITB。`sha256+` 表示固件没有损坏，否则显示 `sha256-`。

## 八、固件替换

用户可以借助脚本批量替换子固件。例如：用 `out` 目录里存在的子固件去替换 `uboot.img` 里同名的子固件。

```
cjh@ubuntu:~/uboot-nextdev$ ./scripts/fit-repack.sh -f uboot.img -d out/
Unpack to directory out/repack/:
    uboot : 6 bytes... sha256+
    optee : 6 bytes... sha256+
    fdt : 4 bytes... sha256+
....
Image(repack): uboot.img is ready