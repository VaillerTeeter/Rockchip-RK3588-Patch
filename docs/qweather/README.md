# 和风天气（QWeather）开发知识库

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/）
> 适用：RK3588 车机天气服务（`weather-server`）开发与数据源选型

本知识库整理了和风天气开发者文档中与车机天气服务相关的官方资料，按主题分类，方便在天气服务开发和车机天气功能落地时快速查阅。

## 文档索引

| 文件 | 内容简介 |
|------|---------|
| [01-服务与数据-数据品类总览.md](./01-服务与数据-数据品类总览.md) | 官网《服务和数据》原文：和风天气全部数据品类（天气/指数/空气/辐照/预警/天文/海洋/台风）的更新频率、时间范围与地理范围 |
| [02-专用词汇表-核心术语.md](./02-专用词汇表-核心术语.md) | 官网《专用词汇表》原文：Rank、坐标、LocationID、Adcode、ISO 3166、POI、日期时间、Timezone、夏令时、UTC Offset、pubTime/updateTime、QPM、风力等级等 18 个核心术语 |
| [03-错误码-HTTP状态对照.md](./03-错误码-HTTP状态对照.md) | 官网《错误码》原文：17 个错误码（400 参数/位置类、401 认证、403 额度/冻结/权限、404/405、429 限流、500 未知故障）与 HTTP 状态码对照及错误响应 JSON 示例 |
| [04-多语言-lang参数对照.md](./04-多语言-lang参数对照.md) | 官网《多语言》原文：默认语言规则、3 级回退顺序、多语言例外（指数/分钟降水仅中英）、31 种语言代码（API/iOS/Android）对照表 |
| [05-常见城市列表-下载与说明.md](./05-常见城市列表-下载与说明.md) | 官网《常见城市列表》原文：全球 15 万城市/POI 数据服务、LocationList 下载方式、优先使用 GeoAPI 的提示 |
| [06-元数据-metadata对象.md](./06-元数据-metadata对象.md) | 官网《元数据》原文：响应中 metadata 对象的 3 个字段（tag 唯一标识、attributions 归因声明、zeroResult 空结果标记） |
| [07-单位-度量衡对照.md](./07-单位-度量衡对照.md) | 官网《单位》原文：新 API 仅公制；单位列表（°C/m/s/m/hPa/mm/W·m⁻²）；v7 旧版 unit 参数（m/i）与公制/英制对照表 |
| [08-最佳实践-不要假设.md](./08-最佳实践-不要假设.md) | 官网《不要假设》原文：不假定数据完整性/长度/范围，字段缺失与枚举变更适配、空值处理等 6 条健壮性建议 |
| [09-最佳实践-优化请求.md](./09-最佳实践-优化请求.md) | 官网《优化请求》原文：URL 编码规则（特殊字符/空格/中文符号）、安全请求、指数退避算法（避免冲突/截断 c=10）、按需请求 |
| [10-最佳实践-Gzip压缩与Go解压.md](./10-最佳实践-Gzip压缩与Go解压.md) | 官网《处理Gzip》原文（含 C#/Dart/Go/Java/Python/Ruby 官方库链接）+ Go 标准库 `compress/gzip` 精简参考（解压 HTTP 响应最小示例） |
| [11-最佳实践-缓存你的数据.md](./11-最佳实践-缓存你的数据.md) | 官网《缓存你的数据》原文：缓存合理性（间隔最多相差2倍）、弹性策略（跨天/夏令时/时区）、清除缓存、11 类数据推荐缓存时间表、GeoAPI 存储限制 |
| [12-最佳实践-安全指南.md](./12-最佳实践-安全指南.md) | 官网《安全指南》原文：HTTPS、JWT 身份验证、API/应用限制（网址/IP/iOS/Android 白名单）、KMS、多凭据、认证服务器/代理服务器、混淆、凭据不入库 |
| [13-GEOAPI-地理位置查询总览.md](./13-GEOAPI-地理位置查询总览.md) | 官网《GeoAPI》原文：位置信息搜索 API 总览（Location ID/多语言/经纬度/时区/Rank 等能力 + 4 个子 API 入口） |
| [14-GEOAPI-城市搜索.md](./14-GEOAPI-城市搜索.md) | 官网《城市搜索》原文：GET /geo/v2/city/lookup，5 个参数（location/adm/range/number/lang）、curl 示例、完整 JSON 响应与字段说明 |
| [15-GEOAPI-热门城市查询.md](./15-GEOAPI-热门城市查询.md) | 官网《热门城市查询》原文：GET /geo/v2/city/top，3 个参数（range/number/lang）、curl 示例、完整 JSON 响应（含北京/朝阳/深圳/上海等示例数据） |
| [16-GEOAPI-POI搜索.md](./16-GEOAPI-POI搜索.md) | 官网《POI搜索》原文：GET /geo/v2/poi/lookup，5 个参数（location/type/city/number/lang）、curl 示例、完整 JSON 响应与字段说明 |
| [17-GEOAPI-POI范围搜索.md](./17-GEOAPI-POI范围搜索.md) | 官网《POI范围搜索》原文：GET /geo/v2/poi/range，5 个参数（location/type/radius/number/lang）、curl 示例、完整 JSON 响应与字段说明 |
| [18-天气预报-总览.md](./18-天气预报-总览.md) | 官网《天气预报》原文：多模式融合/AI 算法，30 天预报 + 分钟级实况、1km 分辨率；6 个 API（3 v1 经纬度 + 3 v7 城市）与 2 参考入口 |
| [19-天气预报-实时天气.md](./19-天气预报-实时天气.md) | 官网《实时天气》原文：GET /weather/v1/current/{lat}/{lon}，经纬度参数、对应 JSON 响应（condition/temperature/wind/precipitation 等 13 类字段） |
| [20-天气预报-每日预报.md](./20-天气预报-每日预报.md) | 官网《每日天气预报》原文：GET /weather/v1/daily/{lat}/{lon}，days 1-10 参数、astronomy 天文事件、daytime/nighttime 昼夜预报、完整 JSON 响应 |
| [21-天气预报-小时预报.md](./21-天气预报-小时预报.md) | 官网《小时天气预报》原文：GET /weather/v1/hourly/{lat}/{lon}，hours 1-240 参数、逐小时 JSON 响应与字段说明 |
| [22-天气预报-城市实时天气.md](./22-天气预报-城市实时天气.md) | 官网《城市实时天气》(v7) 原文：GET /v7/weather/now，LocationID/经纬度参数、now 对象字段（temp/icon/wind360/humidity 等），注：即将弃用 |
| [23-天气预报-城市每日预报.md](./23-天气预报-城市每日预报.md) | 官网《城市每日预报》(v7) 原文：GET /v7/weather/{days}，3d/7d/10d/15d/30d、daily 数组字段、注：即将弃用 |
| [24-天气预报-城市小时预报.md](./24-天气预报-城市小时预报.md) | 官网《城市小时预报》(v7) 原文：GET /v7/weather/{hours}，24h/72h/168h、hourly 数组字段、注：即将弃用 |
| [25-天气预报-天气现象.md](./25-天气预报-天气现象.md) | 官网《天气现象》原文：SVG 开源图标项目 + 62 个天气现象代码/文本对照表（100 晴~999 未知）+ CSV 下载 |
| [26-天气预报-风向和等级.md](./26-天气预报-风向和等级.md) | 官网《风向和等级》原文：风向角度/16 方位对照表、v7 旧版方位、蒲福风级 0-12 + 扩展 13-17（含台风等级对照）、风速经验方程 |
| [27-分钟预报-总览.md](./27-分钟预报-总览.md) | 官网《分钟预报》原文：中国 1km 精度分钟级降雨临近预报总览 |
| [28-分钟预报-分钟级降水.md](./28-分钟预报-分钟级降水.md) | 官网《分钟级降水》原文：GET /v7/minutely/5m，经纬度参数、summary 降水描述、minutely 数组（5 分钟累计降水量 rain/snow） |
| [29-预警-总览.md](./29-预警-总览.md) | 官网《预警》原文：全球官方极端天气预警总览（severity/urgency/certainty/color 等字段能力 + 5 子页入口） |
| [30-预警-实时天气预警.md](./30-预警-实时天气预警.md) | 官网《实时天气预警》原文：GET /weatheralert/v1/current/{lat}/{lon}，alerts 数组完整字段（messageType/severity/color/instruction 等） |
| [31-预警-关于预警信息.md](./31-预警-关于预警信息.md) | 官网《关于预警信息》原文：多语言/失效判断、issuedTime/effectiveTime/onsetTime/expireTime 时间语义、影响区域（非行政区划绑定） |
| [32-预警-事件列表.md](./32-预警-事件列表.md) | 官网《预警事件列表》原文：数百个预警事件代码/名称对照表（1001 台风~9999 其他预警） |
| [33-预警-覆盖范围.md](./33-预警-覆盖范围.md) | 官网《预警的覆盖范围》原文：58 个支持预警的国家/地区 ISO 3166 代码表 |
| [34-预警-变更.md](./34-预警-变更.md) | 官网《预警的变更》原文：messageType 三种性质（alert 初始/update 更新/cancel 取消）与 supersedes 取代机制（含示例） |
| [35-天气指数-总览.md](./35-天气指数-总览.md) | 官网《天气指数》原文：气象要素计算的生活指数总览（洗车/穿衣/感冒/过敏/紫外线/钓鱼等） |
| [36-天气指数-指数预报.md](./36-天气指数-指数预报.md) | 官网《天气指数预报》原文：GET /v7/indices/{days}，days 1d/3d + type/location/lang 参数、daily 数组字段（type/name/level/category/text） |
| [37-天气指数-指数类型.md](./37-天气指数-指数类型.md) | 官网《指数类型》原文：16 类指数（全球 5 + 中国 11）+ 0 全部，API/iOS/Android type 对照及各等级类别说明 |
| [38-空气质量-总览.md](./38-空气质量-总览.md) | 官网《空气质量》原文：1km 分辨率实时/预报数据+污染物+健康建议总览 |
| [39-空气质量-实时.md](./39-空气质量-实时.md) | 官网《实时空气质量》原文：GET /airquality/v1/current/{lat}/{lon}，indexes/pollutants/stations/health 完整 JSON |
| [40-空气质量-小时预报.md](./40-空气质量-小时预报.md) | 官网《空气质量小时预报》原文：GET /airquality/v1/hourly/...，未来 24 小时逐小时 AQI/污染物/健康建议 |
| [41-空气质量-每日预报.md](./41-空气质量-每日预报.md) | 官网《空气质量每日预报》原文：GET /airquality/v1/daily/...，未来 3 天逐日 AQI/污染物/健康建议 |
| [42-空气质量-AQI指数列表.md](./42-空气质量-AQI指数列表.md) | 官网《支持的空气质量指数》原文：QAQI 与本地 AQI、19 个 AQI 标准（每个独立表格：取值范围/类别/颜色） |
| [43-空气质量-污染物列表.md](./43-空气质量-污染物列表.md) | 官网《污染物列表》原文：首要污染物、污染物分指数（AQI=max 公式）、8 类污染物代码/单位 |
| [44-空气质量-覆盖范围.md](./44-空气质量-覆盖范围.md) | 官网《空气质量覆盖范围》原文：QAQI 全球 + 39 个本地 AQI 国家/地区对照表 |
| [45-空气质量-健康影响和建议.md](./45-空气质量-健康影响和建议.md) | 官网《健康影响和建议》原文：健康/敏感人群区分、敏感人群定义、免责声明 |
| [46-空气质量-中国说明.md](./46-空气质量-中国说明.md) | 官网《中国空气质量说明》原文：HJ 633 规范、暂不支持 QAQI、首要污染物为空条件、数据仅为参考值 |
| [47-时光机-总览.md](./47-时光机-总览.md) | 官网《时光机》原文：最近 10 天历史天气总览 + 2000 年至今历史再分析数据商务获取说明 |
| [48-时光机-天气时光机.md](./48-时光机-天气时光机.md) | 官网《天气时光机》原文：GET /v7/historical/weather，location/date/lang/unit 参数、weatherDaily + weatherHourly 历史数据 |
| [49-热带气旋-总览.md](./49-热带气旋-总览.md) | 官网《热带气旋（台风）》原文：中国地区台风实时位置/路径/预报数据总览 |
| [50-热带气旋-台风预报.md](./50-热带气旋-台风预报.md) | 官网《台风预报》原文：GET /v7/tropical/storm-forecast，stormid 参数、forecast 台风预测位置/等级/气压/风速 |
| [51-热带气旋-台风实况和路径.md](./51-热带气旋-台风实况和路径.md) | 官网《台风实况和路径》原文：GET /v7/tropical/storm-track，isActive/now/track、7/10/12 级风圈半径（windRadius30/50/64） |
| [52-热带气旋-台风列表.md](./52-热带气旋-台风列表.md) | 官网《台风列表》原文：GET /v7/tropical/storm-list，basin(NP)/year 参数、storm 列表（id/name/basin/year/isActive） |
| [53-海洋数据-总览.md](./53-海洋数据-总览.md) | 官网《海洋数据》原文：全球主要港口和城市的潮汐数据总览 |
| [54-海洋数据-潮汐.md](./54-海洋数据-潮汐.md) | 官网《潮汐》原文：GET /v7/ocean/tide，location/date 参数、tideTable 满潮/干潮（H/L）+ tideHourly 逐小时潮汐 |
| [55-太阳辐射-总览.md](./55-太阳辐射-总览.md) | 官网《太阳辐射》原文：全球辐射数据（DNI/DHI/GHI + 相关气象）、15 分钟间隔、1km 分辨率总览 |
| [56-太阳辐射-预报.md](./56-太阳辐射-预报.md) | 官网《太阳辐射预报》原文：GET /solarradiation/v1/forecast/{lat}/{lon}，hours/interval/tilt/azimuth/extra/localTime 参数、solarAngle + DNI/DHI/GHI + weather/poa |
| [57-天文-总览.md](./57-天文-总览.md) | 官网《天文》原文：全球任意地点未来 60 天日出日落/太阳高度角/月升月落/月相总览 |
| [58-天文-日出日落.md](./58-天文-日出日落.md) | 官网《日出日落》原文：GET /v7/astronomy/sun，location/date 参数、sunrise/sunset（高纬可能为空） |
| [59-天文-月升月落和月相.md](./59-天文-月升月落和月相.md) | 官网《月升月落和月相》原文：GET /v7/astronomy/moon，moonrise/moonset + moonPhase 逐小时月相（value/name/illumination/icon） |
| [60-天文-太阳高度角.md](./60-天文-太阳高度角.md) | 官网《太阳高度角》原文：GET /v7/astronomy/solar-elevation-angle，location/date/time/tz/alt 参数、solarElevationAngle/solarAzimuthAngle/solarHour/hourAngle |
| [61-天文-了解太阳数据.md](./61-天文-了解太阳数据.md) | 官网《了解太阳数据》原文：日出日落定义、太阳正午/子夜、三类曙暮光（民用/航海/天文）与事件顺序 |
| [62-天文-了解月亮数据.md](./62-天文-了解月亮数据.md) | 官网《了解月亮数据》原文：月升每月推迟 50 分钟原理、极高纬 null、月亮上/下中天、主导月相、8 月相南北半球示意表 |

> 后续官方文档链接会陆续补充编号文档。
