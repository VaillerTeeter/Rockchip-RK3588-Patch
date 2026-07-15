# Rockchip U-Boot 知识库

本目录为 Rockchip U-Boot v2017 (next-dev) 的开发文档知识库，内容整理自 Rockchip 官方 PDF 文档。

## 目录结构

```
docs/u-boot/
├── pdf-archive/              ← 原始官方 PDF 存档
│   ├── Rockchip_Developer_Guide_UBoot_Nextdev_CN.pdf
│   ├── Rockchip-Developer-Guide-Linux-AB-System.pdf
│   └── Rockchip-Developer-Guide-Uboot-mmc-device-driver-analysis.pdf
├── images/                   ← 文档截图
├── README.md                 ← 本索引文件
├── 01~11.md                  ← 知识库文档
│   ...
```

## 文档索引

| 序号 | 文档 | 内容概要 | 关键词 |
|------|------|----------|--------|
| 01 | [基础简介-概述与版本说明](./01-基础简介-概述与版本说明.md) | U-Boot 功能特性、版本说明(v2014/v2017)、启动流程、固件格式(RKFW/FIT) | overview, bootflow, firmware format |
| 02 | [平台架构-配置与机制](./02-平台架构-配置与机制.md) | 平台文件结构、defconfig、Kernel DTB 机制、Miniloader/SPL 替换、分区表 | platform, defconfig, kernel dtb, partition |
| 03 | [编译烧写-环境与流程](./03-编译烧写-环境与流程.md) | 工具链配置、defconfig 选择、编译命令、烧写工具与流程 | build, toolchain, flash, rockusb, fastboot |
| 04 | [系统模块-AB-AVB-DFU等](./04-系统模块-AB-AVB-DFU等.md) | AArch32、AB 系统、AVB 安全启动、Cmdline、DFU、DTBO、ENV、文件系统、HW-ID | system modules, secure boot, dfu, dtbo, env |
| 05 | [驱动模块-外设驱动详解](./05-驱动模块-外设驱动详解.md) | AMP/Charge/Clock/Crypto/Display/DVFS/eFuse/Ethernet/GPIO/I2C/PCIe/PMIC/Storage/UART/USB 等 29 个驱动 | drivers, peripherals, dts config |
| 06 | [进阶原理-Kernel-DTB等](./06-进阶原理-Kernel-DTB等.md) | Kernel DTB 与 Live Device Tree、内核传参、AB 系统数据格式/启动流程、AVB 签名验证与解锁、SD 卡启动升级 | advanced, live dt, cmdline, ab system, avb |
| 07 | [调试手段-日志与命令行](./07-调试手段-日志与命令行.md) | DEBUG 打印、Initcall 追踪、命令行工具、配置选项、开机信息分析 | debug, log, command line, troubleshooting |
| 08 | [SPL详解-Secondary-Program-Loader](./08-SPL详解-Secondary-Program-Loader.md) | SPL 功能定位、固件格式支持(FIT/RKFW)、系统/驱动模块配置、编译打包 | spl, secondary loader, fit, rkfw |
| 09 | [TPL详解-Tiny-Program-Loader](./09-TPL详解-Tiny-Program-Loader.md) | TPL 功能定位(DDR 初始化)、平台配置、DTS 配置、编译打包、调试 | tpl, ddr init, sram |
| 10 | [FIT详解-固件打包与校验](./10-FIT详解-固件打包与校验.md) | FIT 基础概念、ITS 语法、安全/非安全启动方案、boot.img/recovery.img 打包 | fit, its, itb, mkimage, boot.img |
| 11 | [开发工具-打包与调试](./11-开发工具-打包与调试.md) | trust_merger、boot_merger、loaderimage、mkimage、mkbootimg 等工具使用 | tools, pack, unpack, debug |

## 来源

- 原始 PDF 文档位于 `pdf-archive/`
- MD 文档已从 PDF 整理转化，并调整了目录编号与命名以便于检索

## 使用建议

- 按编号顺序阅读可获得从基础到深入的学习路径
- 查阅特定主题时，可通过关键词快速定位对应文档
- 文档中的图片引用路径均为 `images/` 目录下的截图