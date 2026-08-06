# CarHeadunitLauncher

车机 Launcher，用于替代 AOSP Launcher3QuickStep，作为 ATK_DLRK3588 的默认主屏幕。

## 文件结构

```
packages/apps/CarHeadunitLauncher/
├── README.md                           # 本文件
├── Android.bp                          # Soong 编译规则，overrides Launcher3QuickStep
├── AndroidManifest.xml                 # HOME intent filter，横屏 singleTask
├── permissions/
│   └── privapp-permissions-com.carlauncher.xml  # Privileged 权限白名单
├── res/
│   ├── layout/
│   │   └── activity_main.xml           # 主布局：地图+侧边栏 + 一行 4 卡片
│   ├── drawable/
│   │   ├── card_0_bg.xml               # 蓝色圆角卡片背景
│   │   ├── card_1_bg.xml               # 绿色圆角卡片背景
│   │   ├── card_2_bg.xml               # 红色圆角卡片背景
│   │   ├── card_3_bg.xml               # 金色圆角卡片背景
│   │   └── ic_launcher.xml             # 占位图标
│   └── values/
│       ├── strings.xml                 # 字符串资源
│       ├── colors.xml                  # 深色主题色板
│       └── styles.xml                  # 白色不透明状态栏主题
└── src/com/carlauncher/
    └── MainActivity.java               # 主 Activity：横屏锁定
```

## 布局说明

设计分辨率：1920×1080 横屏。地图:侧边栏 = 2:1 (1280px:640px)。

```
┌────────────────────────┬──────┐
│     状态栏（白色不透明）  │      │  ← #FFFFFF，系统 StatusBar
├────────────────────────┴──────┤
│                    │  app     │
│      地图区域        │  侧边栏   │  ← 地图 weight=2 (640dp), 侧边栏 weight=1 (320dp)
│      #2d2d44       │ #1e1e30 │
│                    │          │
├────────────────────┴──────────┤
│ [卡片0] [卡片1] [卡片2] [卡片3] │  ← 140dp 高，4 卡片横向均分
└───────────────────────────────┘
