# 城市搜索

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/api/geoapi/city-lookup/）

城市搜索API提供全球地理位位置、全球城市搜索服务，支持经纬度坐标反查、多语言、模糊搜索等功能。

天气数据是基于地理位置的数据，因此获取天气之前需要先知道具体的位置信息。使用城市搜索，可获取到该城市的基本信息，包括城市的Location ID，多语言名称、经纬度、时区、海拔、Rank值、归属上级行政区域、所在行政区域等。

## 请求路径

```
GET /geo/v2/city/lookup
```

## 参数

#### 查询参数

* location 必选

  string

  需要查询地区的名称、[LocationID](/docs/resource/glossary/#locationid)或以英文逗号分隔的[经度,纬度坐标](/docs/resource/glossary/#coordinate)（十进制），LocationID可通过[GeoAPI](/docs/api/geoapi/)获取。例如 `location=101010100` 或 `location=116.41,39.92`
* adm

  string

  城市的上级行政区划，可设定只在某个行政区划范围内进行搜索，用于排除重名城市或对结果进行过滤。例如 `adm=beijing`
* range

  string

  搜索范围，可设定只在某个国家或地区范围内进行搜索，国家和地区名称需使用[ISO 3166 所定义的国家代码](/docs/resource/glossary/#iso-3166)。如果不设置此参数，搜索范围将在所有城市。例如 `range=cn`
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
'https://your-api-host/geo/v2/city/lookup?location=116.41%2C39.92'
```

请将`your_token`替换为你的[JWT身份认证](/docs/configuration/authentication/)，将`your_api_host`替换为你的[API Host](/docs/configuration/api-host/)

## 返回数据

```
{
  "code": "200",
  "location": [
    {
      "name": "东城",
      "id": "101011600",
      "lat": "39.91755",
      "lon": "116.41876",
      "adm2": "北京",
      "adm1": "北京市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "35",
      "fxLink": "https://www.qweather.com/weather/dongcheng-101011600.html"
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
* location

  array

  地区/城市信息列表

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
