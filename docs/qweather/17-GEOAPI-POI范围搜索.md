# POI范围搜索

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/api/geoapi/poi-range/）

提供指定区域范围内查询所有POI信息。

## 请求路径

```
GET /geo/v2/poi/range
```

## 参数

#### 查询参数

* location 必选

  string

  需要查询地区的以英文逗号分隔的[经度,纬度坐标](/docs/resource/glossary/#coordinate)（十进制，最多支持小数点后两位）。例如 `location=116.41,39.92`
* type 必选

  string

  POI类型，可选择搜索某一类型的POI。`scenic` 景点，`TSTA` 潮汐站点
* radius

  number

  搜索半径，范围为1-50公里，默认为5公里。
* number

  integer

  返回结果的数量，取值范围1-20，默认返回10个结果。
* lang

  string

  [多语言设置](/docs/resource/language/)

## 请求示例

```
curl -X GET --compressed \
-H 'Authorization: Bearer your_token' \
'https://your-api-host/geo/v2/poi/range?location=116.41%2C39.92&type=scenic'
```

请将`your_token`替换为你的[JWT身份认证](/docs/configuration/authentication/)，将`your_api_host`替换为你的[API Host](/docs/configuration/api-host/)

## 返回数据

```
{
  "code": "200",
  "poi": [
    {
      "name": "中山公园",
      "id": "10101010016A",
      "lat": "39.90999985",
      "lon": "116.38999939",
      "adm2": "北京",
      "adm1": "北京",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "scenic",
      "rank": "86",
      "fxLink": "https://www.qweather.com"
    },
    {
      "name": "故宫博物院",
      "id": "10101010018A",
      "lat": "39.90999985",
      "lon": "116.38999939",
      "adm2": "北京",
      "adm1": "北京",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "scenic",
      "rank": "67",
      "fxLink": "https://www.qweather.com"
    },
    {
      "name": "北京市规划展览馆",
      "id": "10101010002A",
      "lat": "39.88999939",
      "lon": "116.40000153",
      "adm2": "北京",
      "adm1": "北京",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "scenic",
      "rank": "68",
      "fxLink": "https://www.qweather.com"
    },
    {
      "name": "老舍茶馆",
      "id": "10101010021A",
      "lat": "39.88999939",
      "lon": "116.38999939",
      "adm2": "北京",
      "adm1": "北京",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "scenic",
      "rank": "86",
      "fxLink": "https://www.qweather.com"
    },
    {
      "name": "景山公园",
      "id": "10101010012A",
      "lat": "39.91999817",
      "lon": "116.38999939",
      "adm2": "北京",
      "adm1": "北京",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "scenic",
      "rank": "67",
      "fxLink": "https://www.qweather.com"
    }
  ],
  "refer": {
    "sources": [
      "https://developer.qweather.com/attribution.html"
    ],
    "license": [
      "QWeather Developers License"
    ]
  }
}
```

* code

  string

  [状态码](/docs/resource/error-code/)
* poi

  object

  POI 列表

  + name

    string

    位置名称
  + id

    string

    位置ID
  + lat

    string

    纬度
  + lon

    string

    经度
  + adm2

    string

    上级行政区划名称
  + adm1

    string

    一级行政区域名称
  + country

    string

    国家名称
  + tz

    string

    [时区](/docs/resource/glossary/#timezone)
  + utcOffset

    string

    当前位置与[UTC时间偏移的小时数](/docs/resource/glossary/#utc-offset)
  + isDst

    string

    是否处于[夏令时](/docs/resource/glossary/#daylight-saving-time)。`1` 表示当前处于夏令时，`0` 表示当前不是夏令时
  + type

    string

    位置的属性
  + rank

    string

    [位置的评分](/docs/resource/glossary/#rank)
  + fxLink

    uri

    该位置的天气预报网页链接，便于嵌入你的网站或应用
* refer

  object

  数据来源和许可信息

  + sources

    array

    原始数据来源，或数据源说明，可能为空
  + license

    array

    数据许可或版权声明，可能为空
