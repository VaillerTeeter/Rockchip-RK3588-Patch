# Rockchip-RK3588-Patch

Rockchip RK3588 平台补丁仓库，包含 U-Boot、rkbin、Kernel 等模块的补丁文件，以及自动化合入脚本。

## 目录结构

```
Rockchip-RK3588-Patch/
├── patches/           # 各模块补丁文件
│   └── u-boot/        # U-Boot 补丁（.patch 文件）
├── scripts/           # 辅助脚本
│   ├── common.sh          # 公共库（日志 + run_cmd）
│   ├── apply-patches.sh   # 补丁合入脚本
│   └── clean-patches.sh   # 补丁清理脚本
├── u-boot/            # [子模块] U-Boot 源码（Rockchip RK3588 移植版）
├── rkbin/             # [子模块] Rockchip 固件 bin（U-Boot 打包依赖）
└── .gitmodules
```

## 克隆仓库

本仓库包含 **git 子模块（submodule）**，clone 时需要同步初始化子模块才能获取完整源码：

```bash
# 方式一：clone 时一步到位
git clone --recurse-submodules https://github.com/VaillerTeeter/Rockchip-RK3588-Patch.git

# 方式二：已 clone 后补全子模块
git clone https://github.com/VaillerTeeter/Rockchip-RK3588-Patch.git
cd Rockchip-RK3588-Patch
git submodule update --init --recursive
```

### 前提条件

在执行任何操作前，请确保子模块已拉取完成：

```bash
git submodule status    # 确认子模块已检出（无 `-` 前缀即为正常）
```

如果子模块未初始化（状态显示 `-`），执行：

```bash
git submodule update --init --recursive
```

## 使用补丁

将补丁合入目标工程：

```bash
bash scripts/apply-patches.sh <目标工程根目录>
```

例如将 U-Boot 补丁应用到子模块源码：

```bash
bash scripts/apply-patches.sh u-boot
```

> 脚本当前为骨架阶段，各模块补丁合入逻辑待实现。