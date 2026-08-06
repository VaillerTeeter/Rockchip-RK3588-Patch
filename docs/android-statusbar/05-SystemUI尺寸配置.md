# 05 SystemUI 尺寸配置

> 来源文件：`frameworks/base/packages/SystemUI/res/values/dimens.xml`
> 配置类型：`<dimen>` / `<item type="dimen">`

本文档整理 SystemUI 层中所有与顶部状态栏相关的尺寸配置项。与框架层（`core/res`）的基础尺寸不同，SystemUI 层的配置更细粒度，涵盖时钟、电池图标、图标间距、内边距、用户头像芯片等各个子组件的精确尺寸。

---

## 图标尺寸

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_icon_size` | `@*android:dimen/status_bar_icon_size` | 通知图标在状态栏中的高度，引用框架层定义（22dip） |
| `status_bar_icon_drawing_size` | `15dp` | 通知图标在状态栏中实际绘制的尺寸 |
| `status_bar_icon_drawing_size_dark` | `@*android:dimen/notification_header_icon_size_ambient` | 通知图标在 Ambient Display（息屏显示）模式下的绘制尺寸 |
| `status_bar_icon_scale_factor` | `1.0`（float） | 状态栏图标的整体缩放系数，`1.0` 表示不缩放 |
| `status_bar_system_icon_spacing` | `0dp` | 系统图标之间的间距 |
| `status_bar_wifi_signal_size` | `@*android:dimen/status_bar_system_icon_size` | Wi-Fi 信号图标的显示尺寸，引用框架层系统图标尺寸（15dp） |
| `status_bar_connected_device_bt_indicator_size` | `17dp` | 蓝牙连接设备旁边的蓝牙指示图标尺寸 |

---

## 图标透明度与内边距

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_icon_drawing_alpha` | `90%` | 通知图标在状态栏中的绘制透明度 |
| `status_bar_icon_padding` | `0dp` | 通知图标两侧的间隙（gap） |
| `status_bar_horizontal_padding` | `2.5dp` | 系统图标的默认水平内边距 |

---

## 状态栏整体内边距

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_padding_start` | `8dp` | 状态栏起始端（左侧）内边距 |
| `status_bar_padding_end` | `8dp` | 状态栏结束端（右侧）内边距 |
| `status_bar_padding_top` | `0dp` | 状态栏顶部内边距（通常为 0） |

---

## 时钟尺寸

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_clock_size` | `14sp` | 状态栏时钟的字体大小 |
| `status_bar_clock_starting_padding` | `7dp` | 时钟的起始内边距（右对齐时钟） |
| `status_bar_clock_end_padding` | `0dp` | 时钟的结束内边距（右对齐时钟） |
| `status_bar_left_clock_starting_padding` | `0dp` | 左对齐时钟的起始内边距 |
| `status_bar_left_clock_end_padding` | `2dp` | 左对齐时钟的结束内边距 |

---

## 电池图标尺寸

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_battery_icon_height` | `13.0dp` | 电池图标的高度 |
| `status_bar_battery_icon_width` | `7.8dp` | 电池图标的宽度（按 12:20 比例计算：13dp × 12/20） |
| `status_bar_battery_extra_vertical_spacing` | `1dp` | 电池图标额外的垂直间距，用于与其他系统图标底部对齐（其他图标为 15dp 含内嵌 padding，电池图标为 13dp） |

---

## 图标间距（特定图标）

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_wifi_signal_spacer_width` | `2.5dp` | Wi-Fi 信号图标后方的间距（当后面还有其他图标时） |
| `status_bar_airplane_spacer_width` | `4dp` | 飞行模式图标前方的间距（当前面有其他图标时） |
| `status_bar_connected_device_signal_margin_end` | `16dp` | 蓝牙连接设备 RSSI 图标的结束外边距 |

---

## 用户头像芯片（User Chip）

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_user_chip_avatar_size` | `16dp` | 状态栏用户头像芯片中头像的尺寸 |
| `status_bar_user_chip_end_margin` | `12dp` | 用户头像芯片的结束外边距 |
| `status_bar_user_chip_text_size` | `12sp` | 用户头像芯片中文字的字体大小 |

---

## 锁屏与过渡动画

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `status_bar_header_height_keyguard` | `40dp` | 锁屏状态下状态栏头部区域的高度 |
| `car_status_bar_header_height` | `128dp` | 车载设置中状态栏头部区域的高度 |
| `lockscreen_shade_status_bar_transition_distance` | `@dimen/lockscreen_shade_full_transition_distance` | 锁屏到下拉阴影过渡时，状态栏的过渡距离（用于 StatusBar 判断过渡是否进行中） |
| `heads_up_status_bar_padding` | `8dp` | 悬浮通知（Heads-up）与状态栏之间的间距 |

---

## 应用权限指示器（Ongoing AppOps）

| 配置名 | 默认值 | 描述 |
|--------|--------|------|
| `ongoing_appops_chip_animation_in_status_bar_translation_x` | `15dp` | 应用权限指示器芯片在状态栏中**进入**动画的水平位移量 |
| `ongoing_appops_chip_animation_out_status_bar_translation_x` | `7dp` | 应用权限指示器芯片在状态栏中**退出**动画的水平位移量 |

---

## 修改建议

- **车机加大时钟字号**：修改 `status_bar_clock_size`，建议同步调整 `status_bar_height_portrait`（文档 01）保证时钟不被截断
- **调整图标间距**：修改 `status_bar_system_icon_spacing` 和 `status_bar_horizontal_padding` 控制图标密度
- **调整状态栏左右边距**：修改 `status_bar_padding_start` / `status_bar_padding_end`
- **放大电池图标**：同步修改 `status_bar_battery_icon_height` 和 `status_bar_battery_icon_width`，保持 12:20 宽高比
