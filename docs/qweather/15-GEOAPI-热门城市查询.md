# 热门城市查询

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/api/geoapi/top-city/）

获取全球各国热门城市列表。

## 请求路径

```
GET /geo/v2/city/top
```

## 参数

#### 查询参数

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
'https://your-api-host/geo/v2/city/top'
```

请将`your_token`替换为你的[JWT身份认证](/docs/configuration/authentication/)，将`your_api_host`替换为你的[API Host](/docs/configuration/api-host/)

## 返回数据

```
{
  "code": "200",
  "topCityList": [
    {
      "name": "北京",
      "id": "101010100",
      "lat": "39.90499",
      "lon": "116.40529",
      "adm2": "北京",
      "adm1": "北京市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "10",
      "fxLink": "https://www.qweather.com/weather/beijing-101010100.html"
    },
    {
      "name": "朝阳",
      "id": "101010300",
      "lat": "39.92149",
      "lon": "116.48641",
      "adm2": "北京",
      "adm1": "北京市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "15",
      "fxLink": "https://www.qweather.com/weather/chaoyang-101010300.html"
    },
    {
      "name": "海淀",
      "id": "101010200",
      "lat": "39.95607",
      "lon": "116.31032",
      "adm2": "北京",
      "adm1": "北京市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "15",
      "fxLink": "https://www.qweather.com/weather/haidian-101010200.html"
    },
    {
      "name": "深圳",
      "id": "101280601",
      "lat": "22.54700",
      "lon": "114.08595",
      "adm2": "深圳",
      "adm1": "广东省",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "13",
      "fxLink": "https://www.qweather.com/weather/shenzhen-101280601.html"
    },
    {
      "name": "上海",
      "id": "101020100",
      "lat": "31.23171",
      "lon": "121.47264",
      "adm2": "上海",
      "adm1": "上海市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "11",
      "fxLink": "https://www.qweather.com/weather/shanghai-101020100.html"
    },
    {
      "name": "浦东新区",
      "id": "101020600",
      "lat": "31.24594",
      "lon": "121.56770",
      "adm2": "上海",
      "adm1": "上海市",
      "country": "中国",
      "tz": "Asia/Shanghai",
      "utcOffset": "+08:00",
      "isDst": "0",
      "type": "city",
      "rank": "15",
      "fxLink": "https://www.qweather.com/weather/pudong-101020600.html"
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
* topCityList

  object

  热门城市/地区列表

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
