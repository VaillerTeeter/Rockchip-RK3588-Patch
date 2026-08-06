# 04 Window 属性 — navigationBarColor 等

> 来源文件：
> - `frameworks/base/core/res/res/values/attrs.xml`（属性定义）
> - `frameworks/base/core/res/res/values/themes.xml`（基础主题默认值）
> - `frameworks/base/core/res/res/values/themes_device_defaults.xml`（设备默认主题值）
>
> 配置类型：`<attr>`（Window/Theme 属性）

本文档整理 Android Window 和 Theme 中与底部导航栏相关的属性，这些属性既可在主题（Theme）中全局配置，也可由 App 在运行时通过 `Window` API 动态设置。

---

## 属性定义

来源：`core/res/res/values/attrs.xml`

| 属性名 | 格式 | 描述 |
|--------|------|------|
| `navigationBarColor` | `color` | 导航栏的背景颜色。App 可通过 `Window.setNavigationBarColor(int)` 动态设置；主题中通过 `<item name="navigationBarColor">` 配置默认值 |
| `navigationBarDividerColor` | `color` | 导航栏顶部分割线的颜色。App 可通过 `Window.setNavigationBarDividerColor(int)` 动态设置 |
| `enforceNavigationBarContrast` | `boolean` | 是否强制导航栏对比度：当导航栏背景透明时，系统自动添加半透明遮罩以确保导航按钮可见。对应 `Window.setNavigationBarContrastEnforced(boolean)` |
| `windowLightNavigationBar` | `boolean` | 是否启用浅色导航栏模式：`true` 时导航栏图标/按钮变为深色（适合浅色背景），`false` 时为白色图标（适合深色背景）。对应 `View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR` |

---

## 主题默认值

### `themes.xml` 中的默认值

| 主题 | 属性 | 默认值 | 说明 |
|------|------|--------|------|
| `Theme` | `navigationBarColor` | `@color/black` | 基础主题：导航栏背景为黑色 |
| `Theme.Translucent` | `navigationBarColor` | `@color/transparent` | 半透明主题：导航栏背景透明 |

### `themes_device_defaults.xml` 中的默认值

| 主题 | 属性 | 默认值 | 说明 |
|------|------|--------|------|
| `Theme.DeviceDefault.Settings` | `navigationBarDividerColor` | `@color/navigation_bar_divider_device_default_settings` | 设置页面主题：带分割线 |
| `Theme.DeviceDefault.Settings` | `navigationBarColor` | `@android:color/white` | 设置页面主题：白色导航栏背景 |
| `Theme.DeviceDefault.Settings` | `windowLightNavigationBar` | `true` | 设置页面主题：浅色模式（深色图标） |
| `Theme.DeviceDefault.NoActionBar` | `navigationBarColor` | `@android:color/transparent` | 无 ActionBar 主题：透明导航栏 |
| `Theme.DeviceDefault.NoActionBar` | `windowLightNavigationBar` | `true` | 无 ActionBar 主题：浅色模式 |

---

## 原始 XML 片段

```xml
<!-- core/res/res/values/attrs.xml -->

<!-- 导航栏背景颜色 -->
<attr name="navigationBarColor" format="color" />

<!-- 导航栏顶部分割线颜色 -->
<attr name="navigationBarDividerColor" format="color" />

<!-- 是否强制导航栏对比度（透明时自动加遮罩） -->
<attr name="enforceNavigationBarContrast" format="boolean" />

<!-- 是否使用浅色导航栏模式（图标变深色） -->
<attr name="windowLightNavigationBar" format="boolean" />
```

```xml
<!-- core/res/res/values/themes.xml -->

<!-- 基础主题：黑色导航栏 -->
<item name="navigationBarColor">@color/black</item>

<!-- 半透明主题：透明导航栏 -->
<item name="navigationBarColor">@color/transparent</item>
```

```xml
<!-- core/res/res/values/themes_device_defaults.xml -->

<!-- 设置页面主题 -->
<item name="navigationBarDividerColor">@color/navigation_bar_divider_device_default_settings</item>
<item name="navigationBarColor">@android:color/white</item>
<item name="windowLightNavigationBar">true</item>

<!-- 无 ActionBar 主题 -->
<item name="navigationBarColor">@android:color/transparent</item>
<item name="windowLightNavigationBar">true</item>
```

---

## 运行时 API 对应关系

| 属性 | 对应 Java API | 说明 |
|------|--------------|------|
| `navigationBarColor` | `Window.setNavigationBarColor(int color)` | 设置导航栏背景色 |
| `navigationBarDividerColor` | `Window.setNavigationBarDividerColor(int color)` | 设置导航栏分割线颜色 |
| `enforceNavigationBarContrast` | `Window.setNavigationBarContrastEnforced(boolean)` | 设置是否强制对比度 |
| `windowLightNavigationBar` | `View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR`（已废弃）/ `WindowInsetsController.setSystemBarsAppearance()` | 切换浅色/深色导航栏图标 |

---

## 修改建议

- **车机全局透明导航栏**：在系统主题中设置 `<item name="navigationBarColor">@android:color/transparent</item>`，并配合 `enforceNavigationBarContrast` = `false` 关闭自动遮罩
- **车机深色主题**：设置 `navigationBarColor` 为深色，`windowLightNavigationBar` = `false`（白色图标）
- **车机浅色主题**：设置 `navigationBarColor` 为浅色，`windowLightNavigationBar` = `true`（深色图标）
- **去除分割线**：将 `navigationBarDividerColor` 设为 `@android:color/transparent`
- **防止 App 覆盖导航栏颜色**：可在 SystemUI 层拦截 `navigationBarColor` 的设置，强制使用系统颜色（需修改 `NavigationBarController` 相关逻辑）
