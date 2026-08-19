# GeoAPI

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/api/geoapi/）

天气数据是基于地理位置的数据，因此获取天气之前需要先知道具体的位置信息。和风天气提供一个功能强大的位置信息搜索API服务：**GeoAPI**。通过GeoAPI，你可获取到需要查询城市或POI的基本信息，包括查询地区的Location ID、多语言名称、经纬度、时区、海拔、Rank值、归属上级行政区域、所在行政区域等。

除此之外，GeoAPI还可以帮助你：

* 支持名称模糊搜索
* 在应用或网站中根据用户输入的名称返回多个城市结果，便于用户选择准确的城市并返回该城市天气
* 不需要维护城市列表，城市信息更新实时获取

## API

[GET城市搜索](/docs/api/geoapi/city-lookup/)

搜索全球城市或反查经纬度坐标，并返回位置标识、名称、行政区划和时区等信息。

[GET热门城市查询](/docs/api/geoapi/top-city/)

获取全球各国热门城市列表。

[GETPOI搜索](/docs/api/geoapi/poi-lookup/)

使用关键字和坐标查询POI信息。

[GETPOI范围搜索](/docs/api/geoapi/poi-range/)

查询指定区域范围内的全部兴趣点信息。
