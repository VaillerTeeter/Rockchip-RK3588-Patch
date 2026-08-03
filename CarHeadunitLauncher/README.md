# CarHeadunitLauncher

车机 Launcher，用于替代 AOSP Launcher3QuickStep，作为 ATK_DLRK3588 的默认主屏幕。

## 文件结构

```
packages/apps/CarHeadunitLauncher/
├── README.md                           # 本文件
├── Android.bp                          # Soong 编译规则，overrides Launcher3QuickStep
├── AndroidManifest.xml                 # HOME intent filter，横屏 singleTask
├── res/
│   ├── layout/activity_main.xml        # 主布局：全屏地图占位 + 一行 3 卡片 + 底部导航
│   ├── drawable/
│   │   ├── card_music_bg.xml           # 蓝色圆角卡片背景
│   │   ├── card_navigation_bg.xml      # 绿色圆角卡片背景
│   │   ├── card_settings_bg.xml        # 红色圆角卡片背景
│   │   └── ic_launcher.xml             # 占位图标
│   └── values/
│       ├── strings.xml                 # 字符串资源
│       ├── colors.xml                  # 深色主题色板
│       └── styles.xml                  # Fullscreen 主题
└── src/com/carlauncher/
    └── MainActivity.java               # 主 Activity，当前仅加载布局
```

## 布局说明

```
┌──────────────────────────────┐
│        地图区域（灰块）        │  ← android:layout_weight=1，占满剩余高度
│        #2d2d44               │
├──────────────────────────────┤
│ [音乐卡片] [导航卡片] [设置卡片] │  ← LinearLayout 横向均分，带圆角有色边框
├──────────────────────────────┤
│      [首页] [应用] [设置]      │  ← 深色底部导航栏 (56dp)
└──────────────────────────────┘