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
│   │   └── activity_main.xml           # 主布局：地图 + 侧边栏(4行) + 4 卡片，背景由代码动态设置
│   ├── drawable/
│   │   ├── beetle_side.png             # 甲壳虫侧视图 (1914×743)
│   │   ├── beetle_front.png            # 甲壳虫正视图 (1352×1080)
│   │   ├── card_0_bg.xml               # 蓝色圆角卡片背景
│   │   ├── card_1_bg.xml               # 绿色圆角卡片背景
│   │   ├── card_2_bg.xml               # 红色圆角卡片背景
│   │   ├── card_3_bg.xml               # 金色圆角卡片背景
│   │   └── ic_launcher.xml             # 占位图标
│   └── values/
│       ├── strings.xml                 # 字符串资源
│       ├── colors.xml                  # 深色主题色板
│       └── styles.xml                  # Theme.CarLauncher（无硬编码背景，由 CarWallpaper 控制）
└── src/com/carlauncher/
    ├── MainActivity.java               # 主 Activity：横屏锁定，悬浮窗权限自动授权，动态壁纸背景
    ├── CarChassisView.java             # 胎压环形仪表 — 四象限 270° 弧 gauge
    ├── CompassView.java                # 指南针表盘 — 30°+5° 刻度 + 中文方向标签
    └── CarAttitudeView.java            # 车身姿态 — 甲壳虫 Bitmap 旋转可视化
```

## 整体页面布局

设计分辨率：1920×1080 横屏。地图:侧边栏 = 2:1（`weight=2` : `weight=1`）。

```
┌────────────────────────┬──────┐
│     状态栏 (系统)       │      │
├────────────────────────┴──────┤
│                    │  侧边栏  │
│      地图区域        │  4 行   │  ← weight=2 / weight=1
│                    │          │
├────────────────────┴──────────┤
│ [卡片0] [卡片1] [卡片2] [卡片3] │  ← 140dp 高，均分
│    ← 间距 A 24dp → │…│ ← B → │
│    ═══ 导航栏 72dp ═══════════ │
└───────────────────────────────┘
```

| 间距 | 值 | 说明 |
|------|-----|------|
| A | 24dp | 地图下沿 → 卡片上沿 (`shortcuts_row` `marginTop`) |
| B | 24dp | 卡片下沿 → 导航栏上沿 (`shortcuts_row` `marginBottom`) |
| 卡片左右留白 | 24dp | `paddingStart` / `paddingEnd` |
| 卡片间距 | 8dp | 相邻卡片 `marginHorizontal` |

## 侧边栏布局

```
行1 ┌──────────────────────────────────┐
    │  ⛽ 68%   │  B 85  急加速 0  急刹 1│  80dp  42sp/14sp
    │  ██████░░ │  ████░░ 急转弯 0  颠簸 3│  weight 对半分
    │                                   │
行2 │  🌡️ 90°C │  🔋 13.8V             │  80dp  42sp
    │  ██████░░ │  ████████░░           │  weight 对半分
    │                                   │
行3 │  ◯ 2.3         ◯ 2.3            │  300dp
    │   35°C         36°C               │  CarChassisView (左)
    │  ◯ 2.1         ◯ 2.2            │  四象限 270° 弧 gauge
    │   37°C         36°C               │  压力 32dp / 温度 22dp
    │     🚗 侧视图    🚗 正视图      │  CarAttitudeView (右)
    │       +15°      -12°             │  角度 22dp
    │                                   │
行4 │       北                         │  剩余高度 (weight=1)
    │   西   ▲   东                     │  CompassView (左)
    │       南                         │  radius = min(w,h×0.80)×0.42
    │   北 128°  1280m                  │  cy = h×0.46
    │  本次  1.2h / 35km               │  行程统计 + 保养 (右)
    │  本周  4.8h / 142km              │  22sp, gravity=top|start
    │  本月  18h / 560km               │
    │  总里程  2,340km                  │
    │  距下次保养  2,340km              │
└──────────────────────────────────┘
```

**所有模块间无分隔线。** 各列宽度通过 `layout_weight="1"` 自动对半分。

## 尺寸规范

| 行 | 项目 | 高度 | 宽度 | 大字 | 小字 |
|----|------|------|------|------|------|
| 1 | 油量 | 80dp | weight=1 半宽 | 42sp | — |
| 1 | 驾驶评分 | 80dp | weight=1 半宽 | 42sp | 14sp |
| 2 | 水温 | 80dp | weight=1 半宽 | 42sp | — |
| 2 | 电瓶电压 | 80dp | weight=1 半宽 | 42sp | — |
| 3 | 胎压 (CarChassisView) | 300dp | weight=1 半宽 | 32dp | 22dp |
| 3 | 车身姿态 (CarAttitudeView) | 300dp | weight=1 半宽 | 22dp | — |
| 4 | 指南针 (CompassView) | weight=1 自动 | weight=1 半宽 | 22dp | — |
| 4 | 行程统计 / 保养 | 同指南针行高 | weight=1 半宽 | 22sp | — |
| — | 底部卡片 | 140dp | weight=1 均分 4 等份 | — | — |

- 进度条统一 12dp 高，`#333355` 底色 + 前景色覆盖
- Canvas 字体使用 `density × dp` 转为物理像素
- CompassView 半径 `radius = min(w, h×0.80) × 0.42`，中心 `cy = h × 0.46`

## 自定义 View

| 类名 | 功能 | 关键参数 |
|------|------|----------|
| `CarChassisView` | 四象限 270° 弧环形仪表，无十字线 | `gaugeRadius = min(quadW,quadH) × 0.40` |
| `CompassView` | 30°粗+5°细白色刻度，中文方位(北/東/南/西)带方向旋转，固定红三角指针+底部信息栏 | `cy = h×0.46`, `radius = min(w, h×0.80)×0.42` |
| `CarAttitudeView` | 左半侧视图(pitch) + 右半正视图(roll)，Bitmap 绕中心旋转，两图等高 | `textSize = 22dp`, 无中间竖线 |

## 默认值规则

无数据时：数值显示 `--`，进度条宽度为 0（仅剩灰色背景）。环形仪表灰底弧全亮，无彩色前景弧。

## 数据来源

| 数据 | 来源 | 实现方式 | 状态 |
|------|------|----------|------|
| 油量 | 原车油位传感器 | ADS1115 ADC + 电压分压 + 标定 | 🟢 硬件可做 |
| 驾驶评分 | SH3001 IMU | 加速度/陀螺仪数学运算 | 🟡 依赖 IMU |
| 水温 | OBD-II PID 0x05 | K-line / CAN 适配器 | 🟡 硬件待调 |
| 电瓶电压 | OBD-II PID 0x42 | K-line / CAN 适配器 | 🟡 硬件待调 |
| 胎压监测 | BLE / 433MHz TPMS | Android BLE API | 🔴 后期 |
| 车身姿态 | SH3001 IMU (I2C 0x36) | IIO sysfs / Sensor HAL | 🟡 驱动待补 |
| 指南针+海拔 | USB GPS (NMEA) | NMEA $GPRMC / $GPGGA | 🟡 依赖 GPS |
| 行程统计 | 应用层 | SharedPreferences + SystemClock | 🟢 现在可做 |
| 保养提醒 | 总里程 | 基于总里程 + 保养间隔 | 🟡 等总里程 |

## 壁纸支持

| 壁纸 | 说明 | 状态 |
|------|------|------|
| 纯黑 | 默认背景，无配置时使用 | 🟢 已完成 |
| 纯白 | 可选纯白背景 | 🟢 已完成 |
| 自定义图片 | 通过 CarWallpaper App 扩展 | 🟢 已完成 |
