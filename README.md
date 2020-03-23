该项目中的大部分代码已经经过生产环境的检验，目前主要用于实现「针对用户个体的服务质量限制」，多用于收费服务场景，具体：

* 限制目标用户能够同时连接 API 的 IP 数量（借助 OpenResty 实现，详情可看 [ip-limit.lua](nginx/ip-limit.lua) ）
* 限制目标用户的最大上/下载速度，单位 kbit/s（借助 Linux [tc](https://en.wikipedia.org/wiki/Tc_(Linux)) 工具实现）

注意：

* 如果需要使用限速功能，需要在容器所在主机先执行 `modprobe ifb numifbs=1`
