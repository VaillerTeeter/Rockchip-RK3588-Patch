# Rockchip U-Boot 系统模块

本章详细介绍 Rockchip 平台 U-Boot 中的各系统功能模块，包括 AArch32 模式、Android AB 系统、AVB 安全启动、Cmdline 参数传递、DFU 固件更新、DTBO/DTO 设备树叠加、ENV 环境变量、Fastboot 烧写、文件系统支持、HW-ID DTB 硬件识别、SD/U 盘启动升级等核心模块的配置与使用方法。

## 一、AArch32 模式

### 1.1 概述

ARMv8 的 64 位芯片支持从 **AArch64** 退化到 **AArch32** 模式运行（与 ARMv7 兼容），代码必须用 32 位编译。

### 1.2 确认方式

用户可以通过以下宏来确认当前是否为 ARMv8 的 AArch32 模式：

```
CONFIG_ARM64_BOOT_AARCH32=y
```

## 二、Android AB 系统

### 2.1 概述

A/B System 即把系统固件分为两份，分别称为 **slot-a** 和 **slot-b**。系统可以从任意一个 slot 启动，当一个 slot 启动失败后还可以从另一个启动；升级时可以直接将固件拷贝到另一个 slot 上，无需进入系统升级模式。

目前 RK 平台的 **Pre-loader** 和 **U-Boot** 都可以支持 A/B 系统。

> 详细原理和流程请参考 **进阶原理章节**。

### 2.2 配置项

A/B System 需要依赖 **LIBAVB**，相关配置如下：

```
// A/B 依赖的库
CONFIG_AVB_LIBAVB=y
CONFIG_AVB_LIBAVB_AB=y
CONFIG_AVB_LIBAVB_ATX=y
CONFIG_AVB_LIBAVB_USER=y
CONFIG_RK_AVB_LIBAVB_USER=y

// 使能 A/B 功能
CONFIG_ANDROID_AB=y
```

### 2.3 分区表

A/B System 对分区表有要求：需要支持 A/B 的分区必须增加后缀 `_a` 和 `_b`。

`parameter.txt` 参考如下：

```
FIRMWARE_VER:8.1
MACHINE_MODEL:RK3326
MACHINE_ID:007
MANUFACTURER: RK3326
MAGIC: 0x5041524B
ATAG: 0x00200800
MACHINE: 3326
CHECK_MASK: 0x80
PWR_HLD: 0,0,A,0,1
TYPE: GPT
CMDLINE:
mtdparts=rk29xxnand:0x00002000@0x00004000(uboot_a),0x00002000@0x00006000(uboot_b),0x00002000@0x00008000(trust_a),0x00002000@0x0000a000(trust_b),0x00001000@0x0000c000(misc),0x00001000@0x0000d000(vbmeta_a),0x00001000@0x0000e000(vbmeta_b),0x00020000@0x0000e000(boot_a),0x00020000@0x0002e000(boot_b),0x00100000@0x0004e000(system_a),0x00300000@0x0032e000(system_b),0x00100000@0x0062e000(vendor_a),0x00100000@0x0072e000(vendor_b),0x00002000@0x0082e000(oem_a),0x00002000@0x00830000(oem_b),0x0010000@0x00832000(factory),0x00008000@0x842000(factory_bootloader),0x00080000@0x008ca000(oem),-@0x0094a000(userdata)
```

### 2.4 注意事项

旧的 U-Boot 使能 A/B 系统之后，用户访问带 `_a` / `_b` 的分区时，传递给 **`part_get_info_by_name()`** 的分区名必须带 slot 后缀，例如 `"boot_a"` 或 `"boot_b"`。这会增加很多冗余代码：用户必须先获取当前系统的 slot，再进行字符串拼接，最终得到分区名。

新的代码优化了这个问题。如果用户的代码版本在下面这个提交点之后，则访问 A/B 分区时**可带、可不带** slot 后缀，框架层会自动探测当前系统使用哪个 slot。例如：上述情况可直接使用 `"boot"`。

```
commit c6666740ee3b51c3e102bfbaf1ab95b78df29246
Author: Joseph Chen <chenjh@rock-chips.com>
Date: Thu Oct 24 15:48:46 2019 +0800

	common: android/rkimg: remove/clean android a/b (slot) code
	- the partition disk layer takes over the responsibility of slot suffix appending, we remove relative code to make file clean;
	- put android a/b code together and name them to be eary understood, this makes file esay to read.

	Change-Id: Id8c838da682ce6098bd7192d7d7c64269f4e86ba
	Signed-off-by: Joseph Chen <chenjh@rock-chips.com>
```

## 三、Android BCB

### 3.1 概述与数据结构

**BCB**（Bootloader Control Block）是 Android 为控制系统启动流程而设计的一种和 Bootloader 交互的机制。数据结构定义在 **misc** 分区偏移 16KB 或 0 位置。

数据结构：

```
struct android_bootloader_message {
    char command[32];
    char status[32];
    char recovery[768];

    /* The 'recovery' field used to be 1024 bytes. It has only ever
     * been used to store the recovery command line, so 768 bytes
     * should be plenty. We carve off the last 256 bytes to store the
     * stage string (for multistage packages) and possible future
     * expansion.
     */
    char stage[32];

    /* The 'reserved' field used to be 224 bytes when it was initially
     * carved off from the 1024-byte recovery field. Bump it up to
     * 1184-byte so that the entire bootloader_message struct rounds up
     * to 2048-byte.
     */
    char reserved[1184];
};
```

### 3.2 Command 参数

**`command`** 字段定义启动命令，目前支持以下三个：

| 参数 | 功能 |
|------|------|
| `bootonce-bootloader` | 启动进入 U-Boot Fastboot |
| `boot-recovery` | 启动进入 Recovery |
| `boot-fastboot` | 启动进入 Recovery Fastboot（简称 Fastbootd） |

### 3.3 Recovery 参数

**`recovery`** 字段为进入 Recovery Mode 的附带命令，开头为 `"recovery\n"`，后面可以带多个参数，以 `"--"` 开头，以 `"\n"` 结尾，例如：

```
recovery\n--wipe_ab\n--wipe_package_size=345\n--reason=wipePackage\n
```

支持的参数列表：

| 参数 | 功能 |
|------|------|
| `update_package` | OTA 升级 |
| `retry_count` | 进 Recovery 升级次数，比如升级时意外掉电，依据该值重新进入 Recovery 升级 |
| `wipe_data` | 擦除 User Data（和 Cache），然后重启 |
| `wipe_cache` | 擦除 Cache（但不擦 User Data），然后重启 |
| `show_text` | 显示 Recovery 文本菜单，部分 Bootloader 使用 |
| `sideload` | - |
| `sideload_auto_reboot` | 仅在 user-debug 版本中可用，无需等待直接重启设备 |
| `just_exit` | 不做任何操作，退出并重启 |
| `locale` | 将 locale 保存到 Cache，Recovery 重启后从 Cache 加载 |
| `shutdown_after` | 返回 shutdown |
| `wipe_all` | 擦除整个 Userdata 分区 |
| `wipe_ab` | 擦除当前 A/B 设备，安全擦除 `RECOVERY_WIPE` 中的所有分区 |
| `wipe_package_size` | 擦除包大小 |
| `prompt_and_wipe_data` | 提示用户数据已损坏，经用户同意后擦除 User Data（和 Cache），然后重启 |
| `fw_update` | SD 卡固件升级 |
| `factory_mode` | 工厂模式，主要用于设备测试（如 PCBA 测试） |
| `pcba_test` | 进入 PCBA 测试 |
| `resize_partition` | 重新规划分区大小，Android Q 的动态分区支持 |
| `rk_fwupdate` | 指定 RK SD/USB 固件升级，作用域仅限于 U-Boot |

> U-Boot 阶段一般不需要用到和关心上述参数，仅供用户学习参考。

## 四、AVB 安全启动

### 4.1 概述

**AVB**（Android Verified Boot）是 Google 设计的一套固件校验流程，主要用于校验 **boot**、**system** 等固件。Rockchip Secure Boot 参考通信中的校验方式及 AVB，实现了一套完整的 Secure Boot 校验方案。

**Feature 列表：**

- 安全校验
- 完整性校验
- 防回滚保护
- **Persistent Partition** 支持
- **Chained Partitions** 支持：可以与 boot、system 签名私钥一致，也可以由 OEM 自己保存私钥，但必须由 PRK 签名

### 4.2 配置

开启 AVB 需要 **Trust** 支持：

```
CONFIG_OPTEE_CLIENT=y
CONFIG_OPTEE_V1=y
CONFIG_OPTEE_ALWAYS_USE_SECURITY_PARTITION=y   // 安全数据存储到 Security 分区
```

| 配置项 | 说明 |
|--------|------|
| **`CONFIG_OPTEE_V1`** | 适用平台：312x、322x、3288、3228H、3368、3399 |
| **`CONFIG_OPTEE_V2`** | 适用平台：3326、3308 |
| **`CONFIG_OPTEE_ALWAYS_USE_SECURITY_PARTITION`** | eMMC 的 RPMB 不能用时才开这个宏，默认不开 |

开启 AVB 相关配置：

```
CONFIG_AVB_LIBAVB=y
CONFIG_AVB_LIBAVB_AB=y
CONFIG_AVB_LIBAVB_ATX=y
CONFIG_AVB_LIBAVB_USER=y
CONFIG_RK_AVB_LIBAVB_USER=y

// 上面几个为必选，下面选择为支持 AVB 与 A/B 特性，两个特性可以分开使用
CONFIG_ANDROID_AB=y        // 支持 A/B
CONFIG_ANDROID_AVB=y       // 支持 AVB

// 仅有 eFuse 的平台使用
CONFIG_ROCKCHIP_PRELOADER_PUB_KEY=y

// 需要严格 Unlock 校验时打开
CONFIG_RK_AVB_LIBAVB_ENABLE_ATH_UNLOCK=y

// 安全校验开启
CONFIG_AVB_VBMETA_PUBLIC_KEY_VALIDATE=y

// 如果需要 CPUID 作为 Challenge Number，开启以下宏
CONFIG_MISC=y
CONFIG_ROCKCHIP_EFUSE=y
CONFIG_ROCKCHIP_OTP=y
```

### 4.3 参考

> 因为 AVB 涉及的内容比较多，其余原理、配置请参考 **进阶原理章节**。

## 五、Cmdline

### 5.1 概述

**Cmdline** 是 U-Boot 向 Kernel 传递参数的一个重要手段，用于传递启动存储、设备状态等信息。目前 Cmdline 参数有多个来源，由 U-Boot 进行拼接、过滤重复数据之后再传给 Kernel。

U-Boot 阶段的 Cmdline 被保存在 **`bootargs`** 环境变量中，最终通过修改 Kernel DTB 里的 **`/chosen/bootargs`** 实现传递。

### 5.2 数据来源

Cmdline 参数的数据来源有以下几处：

**1. `parameter.txt` 文件**

- 如果是 **GPT** 格式的分区表，在 `parameter.txt` 里存放 Cmdline 信息是无效的
- 如果是 **RK** 格式的分区表，可以在 `parameter.txt` 里存放 Cmdline 信息，例如：

```
CMDLINE: console=ttyFIQ0 androidboot.baseband=N/A androidboot.selinux=permissive androidboot.hardware=rk30board androidboot.console=ttyFIQ0 init=/init mtdparts=rk29xxnand:0x00002000@0x00002000(uboot),0x00002000@0x00004000(trust),
```

**2. Kernel DTS 的 `/chosen/bootargs`**，例如：

```
chosen {
    bootargs = "earlyprintk=uart8250,mmio32,0xff30000 swiotlb=1 console=ttyFIQ0
        androidboot.baseband=N/A androidboot.veritymode=enforcing
        androidboot.hardware=rk30board androidboot.console=ttyFIQ0 init=/init kpti=0";
};
```

**3. U-Boot 动态追加**：根据当前运行的状态，U-Boot 会动态追加一些内容到 Cmdline，比如：

```
storagemedia=emmc androidboot.mode=emmc ......
```

**4. `boot.img` / `recovery.img`** 固件头里通常也会有 Cmdline 字段信息。

### 5.3 参数含义

下面列出 RK 平台常用的 Cmdline 参数含义：

| 参数 | 含义 |
|------|------|
| `sdfwupdate` | SD 升级卡标志，Recovery 程序需要 |
| `root=PARTUUID` | 指定 rootfs（system）分区的 UUID，仅 GPT 表支持 |
| `skip_initramfs` | Kernel 不使用 U-Boot 加载的 Ramdisk，而使用 rootfs（system）里的 Ramdisk |
| `storagemedia` | 存储启动类型 |
| `console` | Kernel 打印口的配置信息 |
| `earlycon` | 在串口节点未建立之前，指定串口及其配置 |
| `loop.max_part` | 设定每个 Loop 设备所能支持的分区数目 |
| `rootwait` | 用于文件系统不能立即可用的情况（例如 eMMC 初始化未完成），等待 Driver 加载完成后再 Mount |
| `ro` / `rw` | 加载 rootfs 的属性：只读 / 读写 |
| `firmware_class.path` | 指定驱动位置，如 WIFI、BT、GPU 等 |
| `dm="..."` | Device Mapper 线性目标配置，参考 [Android Boot DM 文档](https://android.googlesource.com/kernel/common/+/android-3.18/Documentation/device-mapper/boot.txt) |
| `androidboot.slot_suffix` | AB System 时为 Kernel 指定从哪个 Slot 启动 |
| `androidboot.serialno` | 为 Kernel 及上层提供序列号，例如 ADB 的序列号等 |
| `androidboot.verifiedbootstate` | 为上层提供 U-Boot 校验固件的状态，共三种 |
| `androidboot.hardware` | 启动设备，如 `rk30board` |
| `androidboot.verifymode` | 指定验证分区的真实模式/状态（即验证固件的完整性） |
| `androidboot.selinux` | SELinux 模式设定 |
| `androidboot.mode` | Android 启动方式 |
| `androidboot.wificountrycode` | 设置 WIFI 国家码，如 `US`、`CN` |
| `androidboot.baseband` | 配置基带，RK 无此功能，设置为 `N/A` |
| `androidboot.console` | Android 信息输出口配置 |
| `androidboot.vbmeta.device=PARTUUID` | 指定 VBMeta 在存储中的位置 |
| `androidboot.vbmeta.hash_alg` | 设置 VBMeta Hash 算法，如 `sha512` |
| `androidboot.vbmeta.size` | 指定 VBMeta 的 Size |
| `androidboot.vbmeta.digest` | 给 Kernel 上传 VBMeta 的 Digest，Kernel 加载 VBMeta 后计算 Digest 并与此对比 |
| `androidboot.vbmeta.device_state` | AVB 2.0 指定系统 Lock 与 Unlock |

**`androidboot.verifiedbootstate`** 的三种状态：

| 状态 | 颜色 | 含义 |
|------|------|------|
| **Green** | 绿 | 处于 LOCKED 状态，且用于验证的密钥非最终用户设置 |
| **Yellow** | 黄 | 处于 LOCKED 状态，且用于验证的密钥由最终用户设置 |
| **Orange** | 橙 | 处于 UNLOCKED 状态 |

**`androidboot.selinux`** 的三种模式：

| 模式 | 含义 |
|------|------|
| `enforcing` | 强制模式：SELinux 运作中，已正确限制 Domain/Type 的存取 |
| `permissive` | 宽容模式：SELinux 运作中，仅输出警告信息，不实际限制存取（可用于 Debug） |
| `disabled` | 关闭：SELinux 未实际运作 |

**`androidboot.mode`** 的两种方式：

| 模式 | 含义 |
|------|------|
| `normal` | 正常开机启动 |
| `charger` | 关机后接电源开机，由 U-Boot 检测电源充电后设置到 `bootargs` 环境变量 |

> 更多参数可参考内核文档：`Documentation/admin-guide/kernel-parameters.txt`。

## 六、DFU 更新固件

### 6.1 功能概述

**DFU**（Device Firmware Update）用于更新设备固件。

> 目前已支持 DFU 的平台请参考 **平台定义章节**。

### 6.2 配置

要开启 DFU 功能，需要开启以下宏：

```
CONFIG_CMD_DFU=y
CONFIG_USB_FUNCTION_DFU=y
```

根据使用的存储介质的不同，可选择打开以下开关：

| 配置项 | 存储介质 |
|--------|----------|
| `CONFIG_DFU_MMC` | MMC（eMMC / SD） |
| `CONFIG_DFU_MTD` | MTD |
| `CONFIG_DFU_NAND` | NAND Flash |
| `CONFIG_DFU_RAM` | RAM |
| `CONFIG_DFU_SF` | SPI Flash |

### 6.3 使用方法

支持 DFU 的平台通常会提供独立的 **config** 配置文件。例如，编译带 DFU 支持的 RV1126 固件可通过执行以下编译命令进行：

```
./make.sh rv1126-dfu
```

将固件烧录进开发板，并将 OTG 接口连接至 PC，在 U-Boot 命令行执行：

```
dfu 0 $devtype $devnum
```

其中 `devtype` 可以是 **mmc** 或 **mtd**。此时在 PC 上会发现一个 **USB Download Gadget** 设备，使用 **Zadig** 替换设备驱动，替换成功后的截图如下所示：

![DFU Zadig](../images/dfu-zadig.png)

使用上位机软件在 Windows 命令行执行：

```
./dfu-util.exe -l
```

此时设备将上传分区表，该分区表定义在 **`include/configs/evb_rv1126.h`**：

```
F:\Prj\20210901-Hisense-AB\dfu-util-0.9-win64>dfu-util.exe -l
dfu-util 0.9

Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
Copyright 2010-2016 Tormod Volden and Stefan Schmidt
This program is Free Software and has ABSOLUTELY NO WARRANTY
Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=5, name="userdata", serial="UNKNOWN"
Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=4, name="rootfs", serial="UNKNOWN"
Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=3, name="boot", serial="UNKNOWN"
Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=2, name="uboot", serial="UNKNOWN"
Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=1, name="loader", serial="UNKNOWN"
Found DFU: [2207:0107] ver=0223, devnum=16, cfg=1, intf=0, path="1-12", alt=0, name="gpt", serial="UNKNOWN"
```

**烧写命令格式：**

```
dfu-util.exe VID:PID -a <分区名> -D <文件名> -R <重启选项>
```

在 Windows 命令行执行以下命令传输文件到开发板：

```
F:\Prj\20210901-Hisense-AB\dfu-util-0.9-win64>dfu-util.exe -d 2207:0107 -a system_b -D rootfs.img -R
```

烧录成功的日志如下：

```
dfu-util 0.9

Copyright 2005-2009 Weston Schmidt, Harald Welte and OpenMoko Inc.
Copyright 2010-2016 Tormod Volden and Stefan Schmidt
This program is Free Software and has ABSOLUTELY NO WARRANTY
Please report bugs to http://sourceforge.net/p/dfu-util/tickets/

Invalid DFU suffix signature
A valid DFU suffix will be required in a future dfu-util release!!!
Opening DFU capable USB device...
ID 2207:0107
Run-time device DFU version 0110
Claiming USB DFU Interface...
Setting Alternate Setting #8 ...
Determining device status: state = dfuIDLE, status = 0
dfuIDLE, continuing
DFU mode device DFU version 0110
Device returned transfer size 4096
Copying data from PC to DFU device
Download [=========================] 100% 49938432 bytes
Download done.
state(7) = dfuMANIFEST, status(0) = No error condition is present
state(2) = dfuIDLE, status(0) = No error condition is present
Done!
can't detach
Resetting USB to switch back to runtime mode
```

> 若需要烧录其它分区，只需要将烧录命令 `-a` 选项后的分区名和 `-D` 选项后的文件名替换即可；烧录命令后面追加 `-R` 参数表示烧录完毕后，开发板将重启。

## 七、DTBO / DTO

### 7.1 术语关系

为了便于用户理解，先明确以下专业术语：

| 术语 | 全称 | 说明 |
|------|------|------|
| **DTS** | Device Tree Source | 设备树源文件 |
| **DTB** | Device Tree Blob | 设备树二进制文件（主） |
| **DTBO** | Device Tree Blob Overlay | 设备树二进制文件（次/叠加层） |
| **DTC** | Device Tree Compiler | 设备树编译器 |
| **DTO** | Device Tree Overlay | 设备树叠加操作 |
| **FDT** | Flattened Device Tree | 扁平设备树 |

它们之间的关系可以描述为：

- DTS 是用于描述 **FDT** 的文件
- DTS 经过 **DTC** 编译后可生成 **DTB** / **DTBO**
- DTB 和 DTBO 通过 **DTO** 操作可合并成一个新的 DTB

> 很多用户习惯把 "DTO" 这个词的动作含义用 "DTBO" 来替代。下文明确：**DTO** 是一个动词概念，代表的是操作；**DTBO** 是一个名词概念，指的是用于叠加的次 DTB。

> 更多知识可参考：<https://source.android.google.cn/devices/architecture/dto>

### 7.2 原理介绍

**DTO**（Device Tree Overlay）是 Android P 后引入且必须强制启用的功能，可让次设备树 Blob（**DTBO**）叠加在已有的主设备树 Blob（**DTB**）上。DTO 可以维护 SoC 设备树，并动态叠加针对特定设备的设备树，从而向树中添加节点并对现有树中的属性进行更改。

主 DTB 一般由 **Vendor** 厂商提供，次 DTBO 可由 **ODM / OEM** 等厂商提供，最后通过 Bootloader 合并后再传递给 Kernel，如下图：

![DTO 架构](../images/dto-architecture.png)

> 图片来自：<https://source.android.google.cn/devices/architecture/dto>

**语法注意事项**：DTO 操作使用的 DTB 和 DTBO 的编译跟普通的 DTB 编译有区别——使用 DTC 编译 `.dts` 时，必须添加选项 **`-@`** 以在生成的 `.dtbo` 中添加 **`_symbols_`** 节点。`_symbols_` 节点包含带标签的所有节点的列表，DTO 库可使用这个列表作为参考。

**编译示例：**

1. 编译主 `.dts` 的命令：

```
dtc -@ -O dtb -o my_main_dt.dtb my_main_dt.dts
```

2. 编译叠加层 DT `.dts` 的命令：

```
dtc -@ -O dtb -o my_overlay_dt.dtbo my_overlay_dt.dts
```

### 7.3 DTO 启用

**1. 配置使能：**

```
CONFIG_CMD_DTIMG=y
CONFIG_OF_LIBFDT_OVERLAY=y
```

**2. `board_select_fdt_index()` 函数的实现。**

这是一个 **`__weak`** 函数，用户可以根据实际情况重新实现它。函数作用是在多份 DTBO 中获取用于执行 DTO 操作的那份 DTBO（返回 Index 索引，最小从 **0** 开始），默认的 weak 函数返回的 Index 为 0。

```
/*
 * Default return index 0.
 */
__weak int board_select_fdt_index(ulong dt_table_hdr)
{
    /*
     * User can use "dt_for_each_entry(entry, hdr, idx)" to iterate
     * over all dt entry of DT image and pick up which they want.
     *
     * Example:
     * 	struct dt_table_entry *entry;
     * 	int index;
     *
     * dt_for_each_entry(entry, dt_table_hdr, index) {
     *
     * 	.... (use entry)
     * }
     *
     * return index;
     */
    return 0;
}
```

### 7.4 DTO 结果

**1. 执行结果打印**

DTO 执行完成后，在 U-Boot 的开机信息中可以看到结果：

```
// 成功时的打印
ANDROID: fdt overlay OK

// 失败时的打印
ANDROID: fdt overlay failed, ret=-19
```

> 通常引起失败的原因一般都是因为主/次设备树 Blob 的内容存在不兼容引起，用户需要对它们的生成语法和兼容性比较清楚。

**2. Cmdline 追加信息**

DTO 执行成功后，会在给 Kernel 的 Cmdline 里追加如下信息，表明当前使用哪份 DTBO 进行 DTO 操作：

```
androidboot.dtbo_idx=1   // idx 从 0 开始，这里表示选取 idx=1 的那份 DTBO 进行 DTO 操作
```

**3. 结果验证**

DTO 执行成功后，可以在 U-Boot 命令行使用 **`fdt`** 命令查看 DTB 内容，确认改动是否生效。

## 八、ENV 环境变量

### 8.1 框架支持

**ENV** 是 U-Boot 框架中非常重要的一种数据管理方式，通过 **Hash Table** 构建"键值"和"数据"进行映射管理，支持"增 / 删 / 改 / 查"操作。通常，我们把它管理的键值和数据统称为：**环境变量**。

U-Boot 支持把 ENV 数据保存在各种存储介质：

| 配置项 | 存储介质 |
|--------|----------|
| `CONFIG_ENV_IS_NOWHERE` | 内存（默认，不持久化） |
| `CONFIG_ENV_IS_IN_MMC` | eMMC / SD |
| `CONFIG_ENV_IS_IN_NAND` | NAND Flash |
| `CONFIG_ENV_IS_IN_EEPROM` | EEPROM |
| `CONFIG_ENV_IS_IN_FAT` | FAT 文件系统 |
| `CONFIG_ENV_IS_IN_FLASH` | NOR Flash |
| `CONFIG_ENV_IS_IN_NVRAM` | NVRAM |
| `CONFIG_ENV_IS_IN_ONENAND` | OneNAND |
| `CONFIG_ENV_IS_IN_REMOTE` | 远程存储 |
| `CONFIG_ENV_IS_IN_SPI_FLASH` | SPI Flash |
| `CONFIG_ENV_IS_IN_UBI` | UBI |
| **`CONFIG_ENV_IS_IN_BLK_DEV`** | **任意已接入 BLK 框架层的存储介质（mmc 除外），RK 平台推荐使用！** |

框架代码：

```
./env/nowhere.c
./env/env_blk.c
./env/mmc.c
./env/nand.c
./env/eeprom.c
./env/embedded.c
./env/ext4.c
./env/fat.c
./env/flash.c
......
```

### 8.2 相关接口

**获取环境变量：**

```
char *env_get(const char *varname);
ulong env_get_ulong(const char *name, int base, ulong default_val);
ulong env_get_hex(const char *varname, ulong default_val);
```

**修改或创建环境变量**（value 为 NULL 时等同于删除操作）：

```
int env_set(const char *varname, const char *value);
int env_set_ulong(const char *varname, ulong value);
int env_set_hex(const char *varname, ulong value);
```

**保存与加载：**

```
int env_load(void);   // 把保存在存储介质上的 ENV 信息全部加载出来
int env_save(void);   // 把当前所有 ENV 信息保存到存储介质上
```

- **`env_load()`**：用户不需要调用，U-Boot 框架会在合适的启动流程里调用
- **`env_save()`**：用户在需要的时刻主动调用，会把所有的 ENV 信息保存到 `CONFIG_ENV_IS_NOWHERE_XXX` 指定的存储介质

### 8.3 高级接口

RK 提供了两个统一处理 ENV 的高级接口，具有**创建、追加、替换**的功能。主要是为了处理 `bootargs` 环境变量，但同样适用于其他环境变量操作。

```
/**
 * env_update() - update sub value of an environment variable
 *
 * This add/append/replace the sub value of an environment variable.
 *
 * @varname:  Variable to adjust
 * @varvalue: Value to add/append/replace
 * @return 0 if OK, 1 on error
 */
int env_update(const char *varname, const char *varvalue);

/**
 * env_update_filter() - update sub value of an environment variable but
 * ignore some key word
 *
 * This add/append/replace/ignore the sub value of an environment variable.
 *
 * @varname:  Variable to adjust
 * @varvalue: Value to add/append/replace
 * @ignore:   Value to be ignored that in varvalue
 * @return 0 if OK, 1 on error
 */
int env_update_filter(const char *varname, const char *varvalue, const char *ignore);
```

**`env_update()` 使用规则：**

| 操作 | 条件 | 行为 |
|------|------|------|
| **创建** | `varname` 不存在 | 创建 `varname` 和 `varvalue` |
| **追加** | `varname` 已存在，`varvalue` 不存在 | 追加 `varvalue` |
| **替换** | `varname` 已存在，`varvalue` 已存在 | 用当前的 `varvalue` 替换原来的值 |

例如：原来存在 `"storagemedia=emmc"`，当前传入 `varvalue` 为 `"storagemedia=rknand"`，则最终更新为 `"storagemedia=rknand"`。

**`env_update_filter()`** 是 `env_update()` 的扩展版本：在更新 ENV 的同时把 `varvalue` 里的某个关键字剔除。

> **特别注意**：`env_update()` 和 `env_update_filter()` 都是以**空格**和 **`=`** 作为分隔符对 ENV 内容进行单元分割，所以操作单元是：
> - **单个词**：`sdfwupdate`、……
> - **"key=value"组合词**：`storagemedia=emmc`、`init=/init`、`androidboot.console=ttyFIQ0`、……
> - 上述两个接口**无法处理长字符串单元**。比如无法把 `"console=ttyFIQ0 androidboot.baseband=N/A androidboot.selinux=permissive"` 作为一个整体单元进行操作。

### 8.4 存储位置

`env_save()` 可以把 ENV 保存到存储介质，RK 平台的 ENV 存储位置和大小定义如下：

```
if ARCH_ROCKCHIP
config ENV_OFFSET
    hex
    depends on !ENV_IS_IN_UBI
    depends on !ENV_IS_NOWHERE
    default 0x3f8000
    help
    	Offset from the start of the device (or partition)

config ENV_SIZE
    hex
    default 0x8000
    help
    	Size of the environment storage area
endif
```

> 通常，**`ENV_OFFSET`** 和 **`ENV_SIZE`** 都不建议修改。

### 8.5 通用选项

目前常用的存储介质一般有：**eMMC** / **sdmmc** / **Nandflash** / **Norflash** 等。但 U-Boot 原生的 NAND、NOR 类 ENV 驱动都走 **MTD** 框架，而 RK 所有已支持的存储都是走 **BLK** 框架层，因此这些 ENV 驱动无法使用。

为此，RK 为接入 BLK 框架层的存储提供 **`CONFIG_ENV_IS_IN_BLK_DEV`** 配置选项：

| 存储类型 | 推荐配置 |
|----------|----------|
| eMMC / sdmmc | 依然选择 `CONFIG_ENV_IS_IN_MMC` |
| NAND / NOR | 选择 `CONFIG_ENV_IS_IN_BLK_DEV` |

相关子配置（通常不需要修改）：

```
// 已经默认被指定好，不需要修改
CONFIG_ENV_OFFSET
CONFIG_ENV_SIZE

// 通常不需要使用到
CONFIG_ENV_OFFSET_REDUND       (optional)
CONFIG_ENV_SIZE_REDUND         (optional)
CONFIG_SYS_MMC_ENV_PART        (optional)
```

> 无论选择哪个 `CONFIG_ENV_IS_IN_XXX` 配置，请先阅读 Kconfig 中的定义说明，里面都有子配置说明。

## 九、fw_printenv 工具

### 9.1 简介

**`fw_printenv`** 是 U-Boot 提供的一个给 Linux 使用的 ENV 工具。通过这个工具，用户可以在 Linux 上访问、修改 ENV 的内容。

> 使用该工具要求 ENV 区域必须位于一个 Kernel 可见的分区上（建议独立分区），本质上是通过 Kernel sysfs 下的存储节点访问到 ENV 区域。

### 9.2 获取与使用

工具获取方式：

```
./make.sh env
```

执行完命令后获得：

| 文件 | 说明 |
|------|------|
| `./tools/env/fw_printenv` | ENV 读写工具 |
| `./tools/env/fw_env.config` | ENV 配置文件 |
| `./tools/env/README` | ENV 读写工具说明文档 |

> 使用方法请参考 **README** 文档。

## 十、ENVF 环境变量片段

### 10.1 设计目的

U-Boot 原生的 ENV 功能是把所有环境变量都保存到指定存储区域，外部可任意修改。如果系统相关的变量被错误修改，则会导致系统无法正常启动、或者被恶意攻击。例如：把启动命令 **`bootcmd`** 抹除或指向到恶意的启动流程。

因此 RK 新增 **ENV Fragment（ENVF）** 功能，核心设计是：

1. 划分开 U-Boot **系统环境变量**和**外来用户环境变量**
2. 用户专门定义一个 **env** 分区用于存放自定义的环境变量
3. 在 U-Boot 里设置好**白名单**
4. U-Boot 只允许从 env 分区里**导入 / 导出 / 修改**白名单内的环境变量

### 10.2 ENVF 流程

1. 用户按需创建 **`env.txt`** 并指定内容
2. 使用 **`mkenvimage`** 生成并烧写 `env.img` 到存储 0 地址
3. 启动时 Loader 和 U-Boot 加载并解析 `env.img` 内容
4. 根据 **`CONFIG_ENVF_LIST`** 白名单导入合法的环境变量

> 针对不同的存储类型，需要制作不同大小的 `env.img`。

### 10.3 配置

```
CONFIG_ENVF=y
CONFIG_SPL_ENVF=y
CONFIG_ENVF_LIST="blkdevparts mtdparts sys_bootargs app reserved"

// eMMC：
// 指定 Primary env.img 的存储地址。单位：字节。
CONFIG_ENV_OFFSET=0x0
// 指定 Backup env.img 的存储地址，无备份时跟 CONFIG_ENV_OFFSET 保持一致。单位：字节。
CONFIG_ENV_OFFSET_REDUND=0x0
// Primary 和 Backup env.img 的大小。单位：字节。
CONFIG_ENV_SIZE=0x8000

// SPI NOR：用法同上。
CONFIG_ENV_NOR_OFFSET=0x0
CONFIG_ENV_NOR_OFFSET_REDUND=0x0
CONFIG_ENV_NOR_SIZE=0x10000

// SPI NAND / SLC NAND：用法同上。
CONFIG_ENV_NAND_OFFSET=0x0
CONFIG_ENV_NAND_OFFSET_REDUND=0x0
CONFIG_ENV_NAND_SIZE=0x40000
```

相关代码与工具：

| 类别 | 路径 |
|------|------|
| 代码 | `./env/envf.c` |
| 工具 | `./tools/mkenvimage.c`（默认参与 U-Boot 的编译并生成 `tools/mkenvimage`） |

### 10.4 PC 端开发流程

**步骤 1：创建 `env.txt`**

必须定义系统分区表，否则无法正常启动。例如：

```
// 必须定义系统分区表，否则无法正常启动。例如：
blkdevparts=mmcblk0:4M@8M(uboot),4M(trust),32M(boot),32M(recovery),32M(backup),-(rootfs)
sys_bootargs=rootwait earlycon=uart8250,mmio32,0xff570000 console=ttyFIQ0
......
```

**格式要求：**

- 采用 `"key=value"` 键值对形式
- 键值对中的 `=` 左右不留空格、不使用单/双引号
- 使用换行表示一个键值对的结束

**关键字段说明：**

- **`sys_bootargs`**：效果等同于内核 DTS 中的 `bootargs`。如果指定了该字段，则 U-Boot 会使用 `sys_bootargs` 对内核 DTS 的 `bootargs` 做 Overlay，存在相同项时 `sys_bootargs` 的优先级更高
- **分区表**：支持内核标准的 **`mtdparts`** 和 **`blkdevparts`** 分区表格式，请按需选择（二选一）

不同存储的分区格式参考如下：

```
// eMMC：
blkdevparts=mmcblk0:32K(env),512K@32K(idblock),256K(uboot),32M(boot),2G(rootfs),1G(oem),2G(userdata),-(media)

// SPI NOR：
mtdparts=sfc_nor:64K(env),128K@64K(idblock),128K(uboot),2M(boot),4M(rootfs),6M(oem),-(userdata)

// SPI NAND / SLC NAND：
mtdparts=rknand:256K(env),256K@256K(idblock),256K(uboot),8M(boot),64M(rootfs),32M(userdata),-(media)
```

**步骤 2：生成 `env.img`**

```
# eMMC:
./tools/mkenvimage -s 0x8000 -p 0x0 -o env.img env.txt

# SPI NOR:
./tools/mkenvimage -s 0x10000 -p 0x0 -o env.img env.txt

# SPI NAND / SLC NAND：
./tools/mkenvimage -s 0x40000 -p 0x0 -o env.img env.txt
```

**步骤 3：`env.img` 烧写到存储 0 地址。**

### 10.5 U-Boot 端开发流程

**步骤 1：使能并按需配置**

```
// 使能 ENVF
CONFIG_ENVF=y
CONFIG_SPL_ENVF=y
CONFIG_ENVF_LIST="blkdevparts mtdparts sys_bootargs app reserved"

// eMMC：
CONFIG_ENV_SIZE=0x8000
CONFIG_ENV_OFFSET=0x0
CONFIG_ENV_OFFSET_REDUND=0x0

// SPI NOR:
CONFIG_ENV_NOR_OFFSET=0x0
CONFIG_ENV_NOR_OFFSET_REDUND=0x0
CONFIG_ENV_NOR_SIZE=0x10000

// SPI NAND / SLC NAND：
CONFIG_ENV_NAND_OFFSET=0x0
CONFIG_ENV_NAND_OFFSET_REDUND=0x0
CONFIG_ENV_NAND_SIZE=0x40000
```

**步骤 2：重新编译并烧写 `uboot.img`。**

**步骤 3：开机信息确认**

```
......
dwmmc@ffc50000: 0, dwmmc@ffc60000: 1
Bootdev(atags): mmc 0
MMC0: HS200, 200Mhz
// 有如下打印
ENVF: Primary 0x00000000 - 0x00008000
ENVF: OK
PartType: ENV
DM: v1
boot mode: normal
FIT: no signed, no conf required
DTB: rk-kernel.dtb
......
```

**步骤 4：U-Boot 命令行保存 ENV**

用户可以通过如下命令保存 ENV，或者代码上使用 **`env_save()`**：

```
=> env save
Saving Environment to env...   // 导出并保存白名单里的环境变量
```

## 十一、Fastboot

### 11.1 概述

**Fastboot** 是 Android 提供的一种借助 USB 和 U-Boot 进行交互的方式，一般用于获取设备信息、烧写固件等。

### 11.2 配置选项

```
// 使能配置
CONFIG_FASTBOOT=y
CONFIG_FASTBOOT_FLASH=y
CONFIG_USB_FUNCTION_FASTBOOT=y

// 参数配置
CONFIG_FASTBOOT_BUF_ADDR
CONFIG_FASTBOOT_BUF_SIZE
CONFIG_FASTBOOT_FLASH_MMC_DEV
CONFIG_FASTBOOT_USB_DEV
```

### 11.3 触发方式

Fastboot 默认使用 Google ADB 的 VID/PID，有如下几种触发方式：

| 方式 | 说明 |
|------|------|
| Kernel 命令行执行 | `reboot fastboot` |
| U-Boot 命令行执行 | `fastboot usb 0` |
| 开机长按组合键 | `Ctrl + F` |

### 11.4 命令支持

```
fastboot flash <partition> [ <filename> ]
fastboot erase <partition>
fastboot getvar <variable> | all
fastboot set_active <slot>
fastboot reboot
fastboot reboot-bootloader
fastboot flashing unlock
fastboot flashing lock
fastboot stage [ <filename> ]
fastboot get_staged [ <filename> ]
fastboot oem fuse at-perm-attr-data
fastboot oem fuse at-perm-attr
fastboot oem at-get-ca-request
fastboot oem at-set-ca-response
fastboot oem at-lock-vboot
fastboot oem at-unlock-vboot
fastboot oem at-disable-unlock-vboot
fastboot oem fuse at-bootloader-vboot-key
fastboot oem format
fastboot oem at-get-vboot-unlock-challenge
fastboot oem at-reset-rollback-index
```

### 11.5 命令详解

#### fastboot flash

**功能**：分区烧写。

```
fastboot flash boot boot.img   # 示例：烧写 boot 分区
```

#### fastboot erase

**功能**：擦除分区。

```
fastboot erase boot             # 示例：擦除 boot 分区
```

#### fastboot getvar

**功能**：获取设备信息。

```
fastboot getvar version-bootloader   # 示例：获取 Bootloader 版本
```

支持的 `<variable>` 参数：

| 参数 | 说明 |
|------|------|
| `version` | Fastboot 版本 |
| `version-bootloader` | U-Boot 版本 |
| `version-baseband` | 基带版本 |
| `product` | 产品信息 |
| `serialno` | 序列号 |
| `secure` | 是否开启安全校验 |
| `max-download-size` | Fastboot 支持单次传输最大字节数 |
| `logical-block-size` | 逻辑块大小 |
| `erase-block-size` | 擦除块大小 |
| `partition-type:<partition>` | 分区类型 |
| `partition-size:<partition>` | 分区大小 |
| `unlocked` | 设备 Lock 状态 |
| `off-mode-charge` | 关机充电状态 |
| `battery-voltage` | 电池电压 |
| `variant` | 变体信息 |
| `battery-soc-ok` | 电池电量是否正常 |
| `slot-count` | Slot 数目 |
| `has-slot:<partition>` | 查看 Slot 内是否有该分区名 |
| `current-slot` | 当前启动的 Slot |
| `slot-suffixes` | 当前设备具有的 Slot，打印其 Name |
| `slot-successful:<_a\|_b>` | 查看分区是否正确校验启动过 |
| `slot-unbootable:<_a\|_b>` | 查看分区是否被设置为 Unbootable |
| `slot-retry-count:<_a\|_b>` | 查看分区的 Retry-Count 次数 |
| `at-attest-dh` | - |
| `at-attest-uuid` | - |
| `at-vboot-state` | - |

#### fastboot getvar all

**功能**：获取所有设备信息。

#### fastboot set_active

**功能**：设置重启的 Slot。

```
fastboot set_active _a           # 示例：设置重启 Slot 为 _a
```

#### fastboot reboot

**功能**：重启设备，正常启动。

#### fastboot reboot-bootloader

**功能**：重启设备，进入 Fastboot 模式。

#### fastboot flashing unlock

**功能**：解锁设备，允许烧写固件。

#### fastboot flashing lock

**功能**：锁定设备，禁止烧写。

#### fastboot stage

**功能**：下载数据到设备端内存，内存起始地址为 **`CONFIG_FASTBOOT_BUF_ADDR`**。

```
fastboot stage permanent_attributes.bin
```

#### fastboot get_staged

**功能**：从设备端获取数据。

```
fastboot get_staged raw_unlock_challenge.bin
```

#### fastboot oem fuse at-perm-attr

**功能**：烧写 `permanent_attributes.bin` 及 Hash。

```
fastboot stage permanent_attributes.bin
fastboot oem fuse at-perm-attr
```

#### fastboot oem fuse at-perm-attr-data

**功能**：只烧写 `permanent_attributes.bin` 到安全存储区域（RPMB）。

```
fastboot stage permanent_attributes.bin
fastboot oem fuse at-perm-attr-data
```

#### fastboot oem at-lock-vboot

**功能**：锁定设备。

```
fastboot oem at-lock-vboot
```

#### fastboot oem at-unlock-vboot

**功能**：解锁设备，现支持 **Authenticated Unlock**。

```
fastboot oem at-get-vboot-unlock-challenge
fastboot get_staged raw_unlock_challenge.bin
./make_unlock.sh              # 参考 make_unlock.sh
fastboot stage unlock_credential.bin
fastboot oem at-unlock-vboot
```

> 📝 可以参考 `how-to-generate-keys-about-avb.md`。

#### fastboot oem fuse at-bootloader-vboot-key

**功能**：烧写 Bootloader Key Hash。

```
fastboot stage bootloader-pub-key.bin
fastboot oem fuse at-bootloader-vboot-key
```

#### fastboot oem format

**功能**：重新格式化分区，分区信息依赖于 **`$partitions`**。

```
fastboot oem format
```

#### fastboot oem at-get-vboot-unlock-challenge

**功能**：Authenticated Unlock，需要获得 Unlock Challenge 数据。

> 📝 参见 `fastboot oem at-unlock-vboot` 命令。

#### fastboot oem at-reset-rollback-index

**功能**：复位设备的 Rollback 数据。

```
fastboot oem at-reset-rollback-index
```

#### fastboot oem at-disable-unlock-vboot

**功能**：使 `fastboot oem at-unlock-vboot` 命令失效。

```
fastboot oem at-disable-unlock-vboot
```

## 十二、文件系统

### 12.1 框架支持

**FAT** 和 **EXT2/4** 是常用的文件系统格式。其中 FAT 采用的是 DOS（MBR）分区表，常见设备有：SD 卡、U 盘。目前在 U-Boot 中一般访问这两种文件系统比较多。

**FAT 配置：**

```
CONFIG_DOS_PARTITION=y
CONFIG_FS_FAT=y
CONFIG_FAT_WRITE=y
CONFIG_FS_FAT_MAX_CLUSTSIZE=65536
CONFIG_CMD_FAT=y
CONFIG_CMD_FS_GENERIC=y
```

FAT 命令：

| 命令 | 功能 |
|------|------|
| `fatinfo` | 查看 FAT 文件系统信息 |
| `fatload` | 从 FAT 加载文件 |
| `fatls` | 列出 FAT 文件 |
| `fatsize` | 获取 FAT 文件大小 |
| `fatwrite` | 写入 FAT 文件 |

**EXT2/4 配置：**

```
CONFIG_CMD_EXT2=y
CONFIG_CMD_EXT4=y
CONFIG_CMD_FS_GENERIC=y
```

EXT2/4 命令：

| 命令 | 功能 |
|------|------|
| `ext2load` / `ext4load` | 从 EXT2/4 加载文件 |
| `ext2ls` / `ext4ls` | 列出 EXT2/4 文件 |
| `ext4size` | 获取 EXT4 文件大小 |

### 12.2 相关接口

**FAT 函数**（头文件 `./include/fat.h`）：

```
int file_fat_detectfs(void);
int fat_exists(const char *filename);
int fat_size(const char *filename, loff_t *size);
int file_fat_read_at(const char *filename, loff_t pos, void *buffer, loff_t maxsize, loff_t *actread);
int file_fat_read(const char *filename, void *buffer, int maxsize);
int fat_set_blk_dev(struct blk_desc *rbdd, disk_partition_t *info);
int fat_register_device(struct blk_desc *dev_desc, int part_no);
int file_fat_write(const char *filename, void *buf, loff_t offset, loff_t len, loff_t *actwrite);
int fat_read_file(const char *filename, void *buf, loff_t offset, loff_t len, loff_t *actread);
int fat_opendir(const char *filename, struct fs_dir_stream **dirsp);
int fat_readdir(struct fs_dir_stream *dirs, struct fs_dirent **dentp);
void fat_closedir(struct fs_dir_stream *dirs);
void fat_close(void);
```

**EXT2/4 函数**（头文件 `./include/ext4fs.h`）：

```
struct ext_filesystem *get_fs(void);
int ext4fs_open(const char *filename, loff_t *len);
int ext4fs_read(char *buf, loff_t offset, loff_t len, loff_t *actread);
int ext4fs_mount(unsigned part_length);
void ext4fs_close(void);
void ext4fs_reinit_global(void);
int ext4fs_ls(const char *dirname);
int ext4fs_exists(const char *filename);
int ext4fs_size(const char *filename, loff_t *size);
void ext4fs_free_node(struct ext2fs_node *node, struct ext2fs_node *currroot);
int ext4fs_devread(lbaint_t sector, int byte_offset, int byte_len, char *buf);
void ext4fs_set_blk_dev(struct blk_desc *rbdd, disk_partition_t *info);
long int read_allocated_block(struct ext2_inode *inode, int fileblock);
int ext4fs_probe(struct blk_desc *fs_dev_desc, disk_partition_t *fs_partition);
int ext4_read_file(const char *filename, void *buf, loff_t offset, loff_t len, loff_t *actread);
int ext4_read_superblock(char *buffer);
int ext4fs_uuid(char *uuid_str);
```

### 12.3 命令示例

以下为 FAT 命令的操作示例：

```
// 确认 SD 卡可识别（如果是 U 盘则用 usb 命令进行识别，设备编号一般是：usb 0）
=> mmc dev 1
switch to partitions #0, OK
mmc1 is current device

// 查看信息
=> fatinfo mmc 1
Interface: MMC
    Device 1: Vendor: Man 000003 Snr e81ec501 Rev: 1.9 Prod: SC16G
    Type: Removable Hard Disk
    Capacity: 15193.5 MB = 14.8 GB (31116288 x 512)
Filesystem: FAT32 "NO NAME "

// 查看文件
=> fatls mmc 1
		System Volume Information/
    23	hello.txt
    23	linux.txt

2 file(s), 1 dir(s)

// 读取 hello.txt 文件的大小（结果默认被保存到变量 filesize 中）
=> fatsize mmc 1 hello.txt
=> echo $filesize
0x17

// 读取 hello.txt 文件到 0x2000000 地址
=> fatload mmc 1 0x2000000 hello.txt
reading hello.txt
23 bytes read in 2 ms (10.7 KiB/s)

// 查看读取的 hello.txt 内容
=> md.l 0x2000000
02000000: 6c6c6568 65682d6f 2d6f6c6c 6c6c6568 hello-hello-hell
02000010: 65682d6f ff6f6c6c ffffffff ffffffff o-hello.........

// 新建文件：hello-copy.txt。把 0x2000000~0x2000017 的地址内容写入 hello-copy.txt。
=> fatwrite mmc 1 0x2000000 hello-copy.txt 0x17
writing hello-copy.txt
23 bytes written

// 看到新文件：hello-copy.txt
=> fatls mmc 1
		System Volume Information/
    23	hello.txt
    23	linux.txt
    23	hello-copy.txt

3 file(s), 1 dir(s)
```

> EXT2/4 和 FAT 命令的使用方法类似，故不做具体说明。

## 十三、HW-ID DTB

### 13.1 设计原理

RK 平台的 U-Boot 支持检测硬件上的 **GPIO** 或 **ADC** 状态动态加载不同的 Kernel DTB，暂称为 **HW-ID DTB**（Hardware ID DTB）功能。

通常硬件设计会经常更新版本和一些元器件，比如：屏幕、WIFI 模组等。如果每一个硬件版本都要对应一套软件，维护起来就比较麻烦。所以需要 **HW_ID** 功能实现一套软件可以适配不同版本的硬件。

**工作流程：**

1. 针对不同硬件版本，软件上需要提供对应的 DTB 文件
2. 同时提供 ADC/GPIO 硬件唯一值用于表征当前硬件版本（比如：固定的 ADC 值、固定的某 GPIO 电平）
3. 用户把这些和硬件版本对应的 DTB 文件全打包进同一个 **`resource.img`**
4. U-Boot 引导 Kernel 时会检测硬件唯一值，从 `resource.img` 里找出和当前硬件版本匹配的 DTB 传给 Kernel

### 13.2 硬件参考

目前支持 **ADC** 和 **GPIO** 两种方式确定硬件版本。

#### 13.2.1 ADC 参考设计

RK3326-EVB / PX30-EVB 主板上有预留分压电阻，不同的电阻分压有不同的 ADC 值，这样可以确定不同硬件版本：

![ADC 主板](../images/hwid-adc-mainboard.png)

配套使用的 MIPI 屏小板预留有另外一颗下拉电阻：

![ADC 小板](../images/hwid-adc-panel.png)

不同的 MIPI 屏会配置不同的阻值，配合 EVB 主板确定一个唯一的 ADC 参数值。

目前 V1 版本的 ADC 计算方法：ADC 参数最大值为 **1024**，对应着 `ADC_IN0` 引脚被直接上拉到供电电压 1.8V。MIPI 屏上有一颗 10K 的下拉电阻，接通 EVB 板后：

```
ADC = 1024 × 10K / (10K + 51K) = 167.8
```

#### 13.2.2 GPIO 参考设计

目前没有 GPIO 的硬件参考设计，用户可自己定制。

### 13.3 DTB 命名

用户需要将 ADC/GPIO 的硬件唯一值信息体现在 DTB 文件名里。命名规则如下：

#### 13.3.1 ADC 作为 HW_ID

| 规则 | 说明 |
|------|------|
| 文件名 | 以 `.dtb` 结尾 |
| HW_ID 格式 | `#[controller]_ch[channel]=[adcval]`，称为一个完整单元 |
| `[controller]` | DTS 里面 ADC 控制器的节点名字 |
| `[channel]` | ADC 通道 |
| `[adcval]` | ADC 的中心值，实际有效范围是：`adcval ± 30` |
| 大小写 | 每个完整单元必须使用**小写字母**，内部不能有空格 |
| 数量限制 | 多个单元之间通过 `#` 进行分隔，最多支持 **10** 个单元 |

范例：

```
rk3326-evb-lp3-v10#saradc_ch2=111#saradc_ch1=810.dtb
rk3326-evb-lp3-v10#_saradc_ch2=569.dtb
```

#### 13.3.2 GPIO 作为 HW_ID

| 规则 | 说明 |
|------|------|
| 文件名 | 以 `.dtb` 结尾 |
| HW_ID 格式 | `#gpio[pin]=[level]`，称为一个完整单元 |
| `[pin]` | GPIO 脚，如 `0a2` 表示 `gpio0a2` |
| `[level]` | GPIO 引脚电平 |
| 大小写 | 每个完整单元必须使用**小写字母**，内部不能有空格 |
| 数量限制 | 多个单元之间通过 `#` 进行分隔，最多支持 **10** 个单元 |

范例：

```
rk3326-evb-lp3-v10#gpio0a2=0#gpio0c3=1.dtb
```

### 13.4 DTB 打包

#### 13.4.1 打包脚本

Kernel 仓库：**`scripts/mkmultidtb.py`**。通过该脚本可以把多个 DTB 打包进同一个 `resource.img`。

用户需要打开脚本文件把要打包的 DTB 文件写到 **`DTBS`** 字典里面，并填上对应的 ADC/GPIO 的配置信息：

```
...
DTBS = {}
DTBS['PX30-EVB'] = OrderedDict([
    ('rk3326-evb-lp3-v10', '#_saradc_ch0=166'),
    ('px30-evb-ddr3-lvds-v10', '#_saradc_ch0=512')
])
...
```

上例中，执行 `scripts/mkmultidtb.py PX30-EVB` 就会生成包含 **3** 份 DTB 的 `resource.img`：

| DTB 文件 | 说明 |
|----------|------|
| `rk-kernel.dtb` | RK 默认的 DTB，不体现在上述字典中。所有 DTB 都没匹配成功时默认被使用。打包脚本会使用 **DTBS 的第一个 DTB** 作为默认的 DTB |
| `rk3326-evb-lp3-v10#_saradc_ch0=166.dtb` | 包含 ADC 信息的 rk3326 DTB 文件 |
| `px30-evb-ddr3-lvds-v10#_saradc_ch0=512.dtb` | 包含 ADC 信息的 px30 DTB 文件 |

#### 13.4.2 功能启用

**配置选项：**

```
CONFIG_ROCKCHIP_HWID_DTB=y
```

**驱动代码：**

```
./arch/arm/mach-rockchip/resource_img.c   // 具体实现：rockchip_read_hwid_dtb()
```

**DTS 配置：**

如果用 GPIO 作为硬件识别，必须在 `rkxxx-u-boot.dtsi` 中保留对应的 **pinctrl** 和 **gpio** 节点；ADC 默认已使能。

例如：gpio0 和 gpio1 作为识别：

```
...
&pinctrl {
	u-boot,dm-spl;   // 追加该属性，让该节点被保留在 U-Boot DTB 中。下同。
};

&gpio0 {
	u-boot,dm-spl;
};

&gpio1 {
	u-boot,dm-spl;
};
...
```

**加载结果：**

```
......
mmc0(part 0) is current device
boot mode: None
DTB: rk3326-evb-lp3-v10#_saradc_ch0=166.dtb   // 打印匹配的 DTB，否则默认 "rk-kernel.dtb"
Using kernel dtb
......
```

## 十四、SD 卡与 U 盘

### 14.1 机制原理

本章节主要介绍 RK 平台上的 **SD 卡**和 **U 盘**的固件启动、升级。

启动卡和升级卡制作完成后，都会在固件头部的固定存储偏移位置打上固定的 **Tag**，用于标记当前是启动卡还是升级卡。U-Boot 识别到这个标记后就会走启动或升级流程。

| 类型 | 卡内内容 | 行为 |
|------|----------|------|
| **启动卡** | 只有一份完整的固件 | U-Boot 直接使用这份完整固件正常启动系统 |
| **升级卡** | 有两份固件：A 固件（仅含进入 Recovery 模式必须的分区镜像）和 B 固件（完整的 `update.img`） | U-Boot 使用 A 固件引导系统进入 Recovery 模式，然后由 Recovery 程序使用 B 固件完成升级工作 |

> **特别注意**：
> - SD 卡启动 / 升级是从 **BOOTROM** 这一级就开始支持
> - U 盘启动 / 升级仅从 **U-Boot** 这一级开始支持，即用户至少要保证 U-Boot 能正常工作！

### 14.2 固件制作

RK 平台上的 SD 和 U 盘启动卡、升级卡的制作流程**完全一致**，仅需两个步骤：

1. 使用 SDK 目录下的 `RKTools/linux/Linux_Pack_Firmware/rockdev/` 工具生成 **`update.img`**
2. 使用 **SDDiskTool** 工具把 `update.img` 烧录到 SD 或 U 盘

操作如图：

- 选择可移动磁盘
- 选择 **固件升级** 或者 **SD 启动**
- 点击 **开始创建**

![SDDiskTool](../images/sddistool.png)

### 14.3 SD 配置

SD 启动 / 升级：各平台 SDK 发布的 U-Boot 已经**默认使能**该功能，用户不需要额外配置。

### 14.4 USB 配置

U 盘启动 / 升级：各平台 SDK 发布的 U-Boot **默认没有使能**。因为 U-Boot 原生的 USB 扫描命令很耗时，所以用户需要自己按需开启。

**步骤 1：** 烧写升级用的整套固件到本地存储（eMMC / NAND 等），确认这套固件正常可用。

**步骤 2：** 插上 U 盘开机进入 U-Boot 命令行模式。执行 `usb start` 和 `usb info` 命令确认能正常识别 U 盘，否则请先调通 U 盘的识别。

**步骤 3：** 将满足步骤 1 的 Kernel DTB 拷贝一份命名成 **`kern.dtb`** 放到 U-Boot 的 `./dts/` 目录下。这份 `kern.dtb` 会在编译 U-Boot 时被自动打包进 `uboot.img`。

> `kern.dtb` 用途：当本地存储分区的 Kernel DTB 有损坏时，U-Boot 使用 `kern.dtb` 确保 USB 能被正常初始化。

**步骤 4：** U-Boot 使能 U 盘启动 / 升级配置：

```
CONFIG_ROCKCHIP_USB_BOOT=y
```

重新编译烧写 `uboot.img`。

> 如果该过程提示 U-Boot 的固件过大无法打包生成，是因为步骤 3 加入 `kern.dtb` 引起的，请先裁掉一些不用的 U-Boot 配置。

### 14.5 功能生效

如何确认 SD、U 盘启动或升级功能生效：

用户可以擦除本地存储（eMMC、NAND 等）上的 **kernel**、**resource**、**boot**、**recovery** 等关键分区，确认插上 SD / U 盘后能进入 Kernel。

### 14.6 注意事项

- U 盘初始化时会调用 `usb start` 命令，整个过程相对耗时
- 如果启动 / 升级卡要支持 **GPT** 分区表，则 **SDDiskTool** 工具的版本要求 **>= v1.59**
- 如果启动 / 升级卡要支持 **AB 系统**，则 **SDDiskTool** 工具的版本要求 **>= v1.61**
- 因为 U 盘启动 / 升级功能是 **2019.11** 才增加的功能，所以相关仓库需要满足如下条件：

**1. U-Boot 仓库**要更新至如下提交点（建议）：

```
commit 369e944c844f783508b7839ae86a3418e2f63bc7
Author: Joseph Chen <chenjh@rock-chips.com>
Date: Thu Dec 12 18:07:07 2019 +0800
    fdt/Makefile: make u-boot-dtb.bin 8-byte aligned

    The dts/kern.dtb is appended after u-boot-dtb.bin for U-disk boot.

    Make sure u-boot-dtb.bin is 8-byte aligned to avoid data-abort on calling: fdt_check_header(gd->fdt_blob_kern).

    Signed-off-by: Joseph Chen <chenjh@rock-chips.com>
    Change-Id: Id5f2daf0c5446e7ea828cb970d3d4879e3acda86
```

或者单独增加如下几个补丁的改动（估计比较困难）：

```
369e944 fdt/Makefile: make u-boot-dtb.bin 8-byte aligned
b3b57ac rockchip: board: fix always entering recovery on normal boot U-disk
e0cee41 rockchip: resource: add sha1/256 verify for kernel dtb
5e817a0 tools: rockchip: resource_tool: add sha1 for file entry
fc474da lib: sha256: add sha256_csum()
0ed06f1 rockchip: support boot from U-disk
01f0422 common: bootm: skip usb_stop() if usb is boot device
5704c89 fdtdec: support pack "kern.dtb" to the end of u-boot.bin
3bdef7e gpt: return 1 directly when test the mbr sector
```

**2. rkbin 仓库**要包含这个提交：

```
commit f9c0b0b72673a65865b00a8824908ca6f12ecc32
Author: Joseph Chen <chenjh@rock-chips.com>
Date: Thu Nov 7 09:21:36 2019 +0800
    tools: resource: add sha1 for file entry

    Base on U-Boot next-dev branch:
    (5e817a0 tools: rockchip: resource_tool: add sha1 for file entry)

    Change-Id: Ife061cabacab488dbecf2a3245d58cc660091dbd
    Signed-off-by: Joseph Chen <chenjh@rock-chips.com>
```

**3. Kernel 仓库**要包含这个提交：

```
commit 078785057478c789bb033ba06925fa3a07e3130a
Author: Tao Huang <huangtao@rock-chips.com>
Date: Thu Nov 7 17:53:38 2019 +0800
    rk: scripts/resource_tool: add sha1 for file entry
    From u-boot 5e817a0ea427 ("tools: rockchip: resource_tool: add sha1 for file entry").
    Merge all C files to one resource_tool.c

    Change-Id: If63ba77d1f5a3660bd6ef87769bb456fa086ae71
    Signed-off-by: Tao Huang <huangtao@rock-chips.com>
```

> 如果用户手上的 SDK 比较旧，除了单独增加上述的补丁，建议跟负责 Recovery 的工程师确认是否 Recovery 有相关补丁。
