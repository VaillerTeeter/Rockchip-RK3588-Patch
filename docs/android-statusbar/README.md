# Android 顶部状态栏配置知识库

> 来源：`frameworks/base`（AOSP `android-13.0.0_r84`）
> 适用平台：正点原子 RK3588 / 二代甲壳虫车机

本知识库整理了 `frameworks/base` 中所有与顶部状态栏（Status Bar）相关的配置项，按配置类型分类，方便在车机移植和定制开发时快速查阅与修改。

---

## 文档索引

| 文件 | 内容简介 |
|------|---------|
| [01-尺寸配置-高度与图标大小.md](./01-尺寸配置-高度与图标大小.md) | 状态栏高度、图标尺寸、内边距、时钟字号等所有 `dimen` 配置项 |
| [02-颜色配置-背景与文字色.md](./02-颜色配置-背景与文字色.md) | 状态栏背景色、时钟颜色、梦境叠加层文字阴影色等 `color` 配置项 |
| [03-功能配置-图标列表与开关.md](./03-功能配置-图标列表与开关.md) | 系统图标槽位列表、通知数字上限、强制绘制背景、图标排除/屏蔽列表等 `config` 配置项 |
| [04-Window属性-statusBarColor等.md](./04-Window属性-statusBarColor等.md) | Window 级别的状态栏颜色、对比度强制、亮色模式等 `attr` 配置项 |
| [05-SystemUI尺寸配置.md](./05-SystemUI尺寸配置.md) | SystemUI 内部的状态栏专属 `dimen` 配置项（时钟、电池图标、图标间距等） |
| [06-SystemUI样式配置.md](./06-SystemUI样式配置.md) | SystemUI 内部的状态栏文字样式（`TextAppearance.StatusBar.*`）及颜色配置 |

---

## 配置文件位置速查

```text
frameworks/base/
  ├── core/res/res/values/
  │   ├── config.xml          → 图标槽位列表、通知数字上限、强制绘制背景
  │   ├── dimens.xml          → 状态栏高度、图标尺寸（框架层）
  │   ├── colors.xml          → 状态栏背景色（框架层）
  │   └── attrs.xml           → Window 属性：statusBarColor、windowLightStatusBar 等
  │
  └── packages/SystemUI/res/values/
      ├── dimens.xml          → 时钟、电池图标、内边距等（SystemUI 层）
      ├── colors.xml          → 时钟颜色、梦境叠加层阴影色（SystemUI 层）
      ├── styles.xml          → TextAppearance.StatusBar.* 文字样式
      └── config.xml          → 图标排除列表、折叠/锁屏图标屏蔽列表
```

---

## 快速修改指引

| 需求 | 修改位置 | 配置项 |
|------|---------|--------|
| 修改状态栏高度 | `core/res/res/values/dimens.xml` | `status_bar_height_portrait` |
| 修改状态栏背景色 | `core/res/res/values/colors.xml` | `status_bar_closed_default_background` / `status_bar_opened_default_background` |
| 隐藏某个系统图标 | `packages/SystemUI/res/values/config.xml` | `config_statusBarIconsToExclude` |
| 修改时钟字号 | `packages/SystemUI/res/values/dimens.xml` | `status_bar_clock_size` |
| 修改通知数字上限 | `core/res/res/values/config.xml` | `status_bar_notification_info_maxnum` |
| 强制 App 绘制状态栏背景 | `core/res/res/values/config.xml` | `config_forceWindowDrawsStatusBarBackground` |
| 设置 Window 状态栏颜色 | `core/res/res/values/attrs.xml` | `statusBarColor` |
| 切换亮色/暗色图标模式 | `core/res/res/values/attrs.xml` | `windowLightStatusBar` |
