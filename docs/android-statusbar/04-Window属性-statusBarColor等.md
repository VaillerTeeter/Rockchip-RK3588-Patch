# 04 Window 属性 — statusBarColor 等

> 来源文件：`frameworks/base/core/res/res/values/attrs.xml`
> 配置类型：`<attr>`（Window / Theme 级别属性）

本文档整理 `attrs.xml` 中所有与顶部状态栏相关的 Window 属性（`attr`）。这些属性作用于 **Window 或 Theme 级别**，由 App 或系统主题通过 XML 或代码设置，控制状态栏的颜色、对比度强制、亮色/暗色图标模式等行为。

---

## 配置项列表

### Window 级别属性（`<declare-styleable name="Window">`）

| 属性名 | 格式 | 描述 |
|--------|------|------|
| `statusBarColor` | `color` | 设置状态栏的背景颜色。若颜色不透明，建议同时设置 `SYSTEM_UI_FLAG_LAYOUT_STABLE` 和 `SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN`。生效前提：窗口必须设置 `windowDrawsSystemBarBackgrounds=true`，且状态栏未被 `windowTranslucentStatus` 设为半透明。对应 API：`Window#setStatusBarColor(int)` |
| `windowDrawsSystemBarBackgrounds` | `boolean` | 若为 `true`，该窗口负责绘制系统栏（状态栏 + 导航栏）的背景；系统栏将以透明背景绘制，窗口对应区域填充 `statusBarColor` 和 `navigationBarColor` 指定的颜色。对应 Flag：`FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS` |
| `windowTranslucentStatus` | `boolean` | 若为 `true`，状态栏将以半透明方式绘制，此时 `statusBarColor` 不生效 |
| `enforceStatusBarContrast` | `boolean` | 若为 `true`，当 App 请求完全透明的状态栏背景时，系统会自动判断是否需要添加遮罩（scrim）以保证状态栏内容与 App 内容之间有足够的对比度。对应 API：`Window#setStatusBarContrastEnforced` |
| `windowLightStatusBar` | `boolean` | 若为 `true`，状态栏图标和文字将切换为**深色**（适用于浅色背景）；若为 `false`，使用默认的白色图标（适用于深色背景）。对应 Flag：`View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR` |

### Theme 级别属性（`<declare-styleable name="Theme">`）

| 属性名 | 格式 | 描述 |
|--------|------|------|
| `colorPrimaryDark` | `color` | 主品牌色的深色变体，默认用于状态栏背景色（通过 `statusBarColor`）和导航栏背景色（通过 `navigationBarColor`） |

### TaskDescription 属性（`@hide`，系统内部使用）

| 属性名 | 描述 |
|--------|------|
| `statusBarColor`（TaskDescription） | 隐藏属性，来自 `Theme.statusBarColor`，用于 `TaskDescription` 中记录任务的状态栏颜色 |
| `enforceStatusBarContrast`（TaskDescription） | 隐藏属性，来自 `Window.enforceStatusBarContrast`，用于 `TaskDescription` |

---

## 原始 XML 片段

```xml
<!-- core/res/res/values/attrs.xml -->

<!-- Window 属性：是否由窗口绘制系统栏背景 -->
<attr name="windowDrawsSystemBarBackgrounds" format="boolean" />

<!-- Window 属性：状态栏颜色 -->
<!-- 生效前提：windowDrawsSystemBarBackgrounds=true 且未设置 windowTranslucentStatus -->
<attr name="statusBarColor" format="color" />

<!-- Window 属性：强制状态栏对比度 -->
<attr name="enforceStatusBarContrast" format="boolean" />

<!-- Window 属性：亮色状态栏（深色图标模式） -->
<attr name="windowLightStatusBar" format="boolean" />

<!-- Theme 属性：主色深色变体，默认用于状态栏背景 -->
<attr name="colorPrimaryDark" format="color" />
```

---

## 使用示例

### 在 Theme 中设置状态栏颜色

```xml
<!-- res/values/themes.xml -->
<style name="AppTheme" parent="Theme.Material3.DayNight">
    <!-- 状态栏背景色 -->
    <item name="android:statusBarColor">#FF1A1A2E</item>
    <!-- 使用白色图标（深色状态栏背景时使用） -->
    <item name="android:windowLightStatusBar">false</item>
    <!-- 强制对比度保障 -->
    <item name="android:enforceStatusBarContrast">true</item>
</style>
```

### 在代码中动态设置

```java
// 设置状态栏颜色
getWindow().setStatusBarColor(Color.BLACK);

// 切换为亮色图标模式（深色背景）
getWindow().getDecorView().setSystemUiVisibility(0);

// 切换为深色图标模式（浅色背景）
getWindow().getDecorView().setSystemUiVisibility(
    View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR);

// 强制对比度
getWindow().setStatusBarContrastEnforced(true);
```

---

## 修改建议

- **车机全局深色状态栏**：在系统主题中设置 `android:statusBarColor` 为黑色或深色，`android:windowLightStatusBar` 为 `false`
- **车机浅色状态栏**：设置 `android:statusBarColor` 为浅色，同时 `android:windowLightStatusBar` 设为 `true` 使图标变深色
- **透明状态栏**：设置 `android:statusBarColor` 为 `@android:color/transparent`，并设置 `android:enforceStatusBarContrast` 为 `true` 保证可读性
