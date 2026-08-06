# 06 SystemUI 样式配置

> 来源文件：`frameworks/base/packages/SystemUI/res/values/styles.xml`
> 配置类型：`<style>`（`TextAppearance.StatusBar.*` 系列）

本文档整理 SystemUI 层中所有与顶部状态栏相关的文字样式（`TextAppearance`）配置。这些样式控制状态栏时钟、用户芯片、展开面板中各文字元素的字号、字体、颜色等视觉属性。

---

## 样式继承关系

```
TextAppearance.StatusBar（框架层基类）
  ├── TextAppearance.StatusBar.Clock          ← 状态栏时钟
  ├── TextAppearance.StatusBar.UserChip       ← 用户头像芯片文字
  └── TextAppearance.StatusBar.Expanded       ← 展开面板基类
        ├── TextAppearance.StatusBar.Expanded.Clock         ← 展开面板时钟
        ├── TextAppearance.StatusBar.Expanded.Date          ← 展开面板日期
        ├── TextAppearance.StatusBar.Expanded.AboveDateTime ← 展开面板日期时间上方文字
        ├── TextAppearance.StatusBar.Expanded.EmergencyCallsOnly ← 仅限紧急呼叫文字
        ├── TextAppearance.StatusBar.Expanded.ChargingInfo  ← 充电信息文字
        └── TextAppearance.StatusBar.Expanded.UserSwitcher  ← 用户切换器文字
              └── TextAppearance.StatusBar.Expanded.UserSwitcher.Activated ← 激活状态
```

---

## 配置项列表

### 状态栏时钟样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Clock` | `TextAppearance.StatusBar.Icon` | `android:textSize` | `@dimen/status_bar_clock_size`（14sp） | 时钟字体大小 |
| | | `android:fontFamily` | `config_headlineFontFamilyMedium` | 时钟字体族（Medium 字重） |
| | | `android:textColor` | `@color/status_bar_clock_color`（#FFFFFFFF） | 时钟文字颜色（白色） |

### 用户头像芯片文字样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.UserChip` | `TextAppearance.StatusBar.Icon` | `android:textSize` | `@dimen/status_bar_user_chip_text_size`（12sp） | 用户芯片文字大小 |
| | | `android:fontFamily` | `config_headlineFontFamilyMedium` | 用户芯片字体族（Medium 字重） |
| | | `android:textColor` | `@color/status_bar_clock_color`（#FFFFFFFF） | 用户芯片文字颜色（与时钟同色） |

### 展开面板基类样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Expanded` | `TextAppearance.StatusBar` | `android:textColor` | `?android:attr/textColorTertiary` | 展开面板文字颜色（跟随主题三级文字色） |

### 展开面板时钟样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Expanded.Clock` | `TextAppearance.StatusBar.Expanded` | `android:textSize` | `@dimen/qs_time_expanded_size` | 展开面板时钟字体大小（快速设置面板中的大时钟） |
| | | `android:fontFamily` | `config_headlineFontFamilyMedium` | 展开面板时钟字体族 |
| | | `android:textColor` | `?android:attr/textColorPrimary` | 展开面板时钟颜色（主题主文字色） |

### 展开面板日期样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Expanded.Date` | `TextAppearance.StatusBar.Expanded` | `android:textSize` | `@dimen/qs_time_expanded_size` | 展开面板日期字体大小 |
| | | `android:textStyle` | `normal` | 日期字体样式（正常，非粗体） |
| | | `android:textColor` | `?android:attr/textColorPrimary` | 日期颜色（主题主文字色） |

### 展开面板日期时间上方文字样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Expanded.AboveDateTime` | `TextAppearance.StatusBar.Expanded` | `android:textSize` | `@dimen/qs_emergency_calls_only_text_size` | 日期时间上方区域文字大小 |
| | | `android:textStyle` | `normal` | 字体样式（正常） |
| | | `android:textColor` | `?android:attr/textColorTertiary` | 颜色（主题三级文字色） |

### 仅限紧急呼叫文字样式

| 样式名 | 父样式 | 描述 |
|--------|--------|------|
| `TextAppearance.StatusBar.Expanded.EmergencyCallsOnly` | `TextAppearance.StatusBar.Expanded.AboveDateTime` | 无 SIM 卡时显示"仅限紧急呼叫"的文字样式，完全继承 `AboveDateTime` |

### 充电信息文字样式

| 样式名 | 父样式 | 描述 |
|--------|--------|------|
| `TextAppearance.StatusBar.Expanded.ChargingInfo` | `TextAppearance.StatusBar.Expanded.AboveDateTime` | 充电状态信息文字样式，完全继承 `AboveDateTime` |

### 用户切换器文字样式

| 样式名 | 父样式 | 配置项 | 值 | 描述 |
|--------|--------|--------|----|------|
| `TextAppearance.StatusBar.Expanded.UserSwitcher` | `TextAppearance.StatusBar.Expanded` | `android:textSize` | `@dimen/kg_user_switcher_text_size` | 用户切换器文字大小 |
| | | `android:textStyle` | `normal` | 字体样式（正常） |
| | | `android:fontFamily` | `config_headlineFontFamily` | 字体族（Regular 字重） |
| `TextAppearance.StatusBar.Expanded.UserSwitcher.Activated` | `UserSwitcher` | `android:fontWeight` | `700` | 激活（选中）用户的文字字重（加粗） |

---

## 原始 XML 片段

```xml
<!-- packages/SystemUI/res/values/styles.xml -->

<!-- 状态栏时钟文字样式 -->
<style name="TextAppearance.StatusBar.Clock"
       parent="@*android:style/TextAppearance.StatusBar.Icon">
    <item name="android:textSize">@dimen/status_bar_clock_size</item>
    <item name="android:fontFamily">@*android:string/config_headlineFontFamilyMedium</item>
    <item name="android:textColor">@color/status_bar_clock_color</item>
</style>

<!-- 用户头像芯片文字样式 -->
<style name="TextAppearance.StatusBar.UserChip"
       parent="@*android:style/TextAppearance.StatusBar.Icon">
    <item name="android:textSize">@dimen/status_bar_user_chip_text_size</item>
    <item name="android:fontFamily">@*android:string/config_headlineFontFamilyMedium</item>
    <item name="android:textColor">@color/status_bar_clock_color</item>
</style>

<!-- 展开面板基类 -->
<style name="TextAppearance.StatusBar.Expanded"
       parent="@*android:style/TextAppearance.StatusBar">
    <item name="android:textColor">?android:attr/textColorTertiary</item>
</style>

<!-- 展开面板时钟 -->
<style name="TextAppearance.StatusBar.Expanded.Clock">
    <item name="android:textSize">@dimen/qs_time_expanded_size</item>
    <item name="android:fontFamily">@*android:string/config_headlineFontFamilyMedium</item>
    <item name="android:textColor">?android:attr/textColorPrimary</item>
</style>
```

---

## 修改建议

- **修改时钟字体**：修改 `TextAppearance.StatusBar.Clock` 中的 `android:fontFamily`，可替换为自定义字体
- **修改时钟颜色**：修改 `TextAppearance.StatusBar.Clock` 中的 `android:textColor`，或直接修改 `status_bar_clock_color`（见文档 02）
- **修改展开面板时钟大小**：修改 `TextAppearance.StatusBar.Expanded.Clock` 中的 `android:textSize`，或修改 `qs_time_expanded_size` dimen 值
- **车机多用户场景**：若需要突出当前用户，可加大 `TextAppearance.StatusBar.Expanded.UserSwitcher.Activated` 的 `android:fontWeight`
