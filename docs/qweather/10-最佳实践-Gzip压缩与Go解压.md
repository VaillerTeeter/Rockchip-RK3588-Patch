# 处理Gzip

> 来源：和风天气开发者文档（https://dev.qweather.com/docs/best-practices/gzip/）

和风天气的 API 默认采用 [Gzip](https://www.gnu.org/software/gzip/) 进行压缩，这将极大的减少网络流量，加快请求。

> **提示：** 如果使用 iOS SDK 或 Android SDK，不需要考虑处理Gzip。

对于不同开发语言如何处理 Gzip，我们在这里给出一些官方参考文档，这些文档可能与你当前使用的版本不一致，请注意它们的区别。

## C#

<https://learn.microsoft.com/zh-cn/dotnet/api/system.io.compression.gzipstream?view=net-6.0>

## Dart

<https://api.dart.cn/stable/2.17.0/dart-io/GZipCodec-class.html>

## Go

<https://pkg.go.dev/compress/gzip>

## Java

<https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/util/zip/GZIPInputStream.html>

## Python

<https://docs.python.org/zh-cn/3/library/gzip.html>

## Ruby

<https://ruby-doc.org/stdlib-2.7.0/libdoc/zlib/rdoc/Zlib/GzipReader.html>

---

# Go 标准库 compress/gzip 精简参考

> 参考：https://pkg.go.dev/compress/gzip

weather-server（Go）使用标准库 `compress/gzip` 即可完成和风 API 响应的解压，**零第三方依赖**。

## 核心类型

- `gzip.Reader`：gzip 解压流。对应构造器 `gzip.NewReader(io.Reader)`。
- `gzip.Writer`：gzip 压缩流（weather-server 目前无压缩需求，仅列出）。

## 解压 HTTP 响应的最小示例

```go
import (
"compress/gzip"
"io"
"net/http"
)

func readBody(resp *http.Response) ([]byte, error) {
// 和风 API 默认返回 gzip 压缩（Content-Encoding: gzip）
// 检查头并解压；未压缩时直接读原响应体
if resp.Header.Get("Content-Encoding") == "gzip" {
zr, err := gzip.NewReader(resp.Body)
if err != nil {
return nil, err
}
defer zr.Close()
return io.ReadAll(zr)
}
return io.ReadAll(resp.Body)
}
```

## weather-server 应用提示

1. **无需手动设置 Accept-Encoding**：Go 的 `net/http` 默认自动添加 `Accept-Encoding: gzip` 并在传输层透明解压，此时响应头不会出现 `Content-Encoding: gzip`，`resp.Body` 已是解压后的明文。上面的显式解压仅用于**关闭了透明解压**或自定义 Transport 的场景。
2. **配 JSON 解析**：解压后直接 `json.Unmarshal` 即可，与 06 号文档 `metadata` 对象、03 号文档错误码配合。
3. **与 09 号文档衔接**：请求 URL 需正确处理特殊字符编码；响应处理需按本文解压 gzip。
