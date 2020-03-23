该项目中的大部分代码已经经过生产环境的检验，目前主要用于实现「针对用户个体的服务质量限制」，多用于收费服务场景，具体：

* 限制目标用户能够同时连接 API 的 IP 数量（借助 OpenResty 实现，详情可看 [ip-limit.lua](nginx/ip-limit.lua) ）
* 限制目标用户的最大上/下载速度（借助 Linux [tc](https://en.wikipedia.org/wiki/Tc_(Linux)) 工具实现）

注意：

* 如果需要使用限速功能，需要在容器所在主机先执行 `modprobe ifb numifbs=1`


### 配置

以在容器内执行 `./configure.sh -i 5 -u 1000 -d 2000` 为例：

* `-i 5` 表示限制能够同时连接的最大 IP 数量为 5
* `-u 1000` 表示限制最大上传速度为 1000 kbit/s（等于 1 Mbit/s）
* `-d 2000` 表示限制最大下载速度为 2000 kbit/s（等于 2 Mbit/s）

以上三个参数均可分别或同时不传，表示无限制。
