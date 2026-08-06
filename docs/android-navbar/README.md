# Android 底部导航栏配置知识库

> 来源：`frameworks/base/core/res/res/values/` 和 `frameworks/base/packages/SystemUI/res/values/`
> 基于 AOSP `android-13.0.0_r84`

本知识库整理了 Android 13 框架层与 SystemUI 层中所有与**底部导航栏（Navigation Bar）**相关的配置项，涵盖尺寸、功能开关、颜色、Window 属性四大类别，供车机定制开发参考。

---

## 文档索引

| 文档 | 内容概述 | 配置项数量 |
|------|----------|-----------|
| [01-尺寸配置-高度与手势区域](./01-尺寸配置-高度与手势区域.md) | 导航栏高度、宽度、手势触发区域、Handle 尺寸、边缘返回面板尺寸 | 30 项 |
| [02-功能配置-开关与行为](./02-功能配置-开关与行为.md) | 导航栏显示开关、交互模式、透明度模式、手势行为、键盘联动等 | 21 项 |
| [03-颜色配置](./03-颜色配置.md) | 导航栏图标颜色、Home Handle 颜色、分割线颜色 | 4 项 |
| [04-Window属性-navigationBarColor等](./04-Window属性-navigationBarColor等.md) | App 可设置的 Window 级导航栏属性（颜色、对比度、浅色模式等） | 4 项 |

---

## 配置文件速查

| 配置文件 | 层级 | 主要内容 |
|----------|------|----------|
| `core/res/res/values/dimens.xml` | Framework | 导航栏高度、Car Mode 高度、手势区域高度 |
| `core/res/res/values/config.xml` | Framework | 显示开关、交互模式、透明度模式、手势行为 |
| `core/res/res/values/attrs.xml` | Framework | Window/Theme 属性定义 |
| `core/res/res/values/colors_device_defaults.xml` | Framework | 设备默认颜色（分割线） |
| `core/res/res/values/themes.xml` | Framework | 主题默认颜色值 |
| `core/res/res/values/themes_device_defaults.xml` | Framework | 设备默认主题颜色值 |
| `packages/SystemUI/res/values/dimens.xml` | SystemUI | 死区尺寸、Handle 尺寸、边缘返回面板尺寸 |
| `packages/SystemUI/res/values/config.xml` | SystemUI | 死区时长、按钮布局字符串、自动降亮 |
| `packages/SystemUI/res/values/colors.xml` | SystemUI | 图标颜色、Handle 颜色 |

---

## 车机定制快速参考

| 需求 | 关键配置项 | 所在文档 |
|------|-----------|----------|
| 修改导航栏高度 | `navigation_bar_height` / `navigation_bar_height_landscape` | 01 |
| 隐藏导航栏 | `config_showNavigationBar` | 02 |
| 切换为纯手势模式 | `config_navBarInteractionMode` = 2 | 02 |
| 软键盘弹出时隐藏导航栏 | `config_hideNavBarForKeyboard` | 02 |
| 修改导航栏背景色 | `navigationBarColor` | 04 |
| 修改图标颜色 | `navigation_bar_icon_color` | 03 |
