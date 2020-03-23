该项目中的大部分代码已经经过生产环境的检验，目前主要用于实现「针对用户个体的服务质量限制」，多用于收费服务场景，具体：

* 限制用户能够同时进行连接的 IP 数量（借助 OpenResty 实现，详情可看 [ip-limit.lua](nginx/ip-limit.lua) ）
* 限制用户的上/下载速度（借助 Linux tc 工具实现，详情可看 [rate-limit.sh](rate-limit.sh) ）

### 配置

以在容器内执行 `./configure.sh -i 5 -u 1000 -d 2000` 为例：

* `-i 5` 表示限制能够同时连接的最大 IP 数量为 5
* `-u 1000` 表示限制最大上传速度为 1000 kbit/s（等于 1 Mbit/s）
* `-d 2000` 表示限制最大下载速度为 2000 kbit/s（等于 2 Mbit/s）

以上三个参数均可分别或同时不传，表示无限制。每次执行 `./configure.sh` 会进行对应配置的无停机优雅更新，不会影响现有连接。

### 持久化

将容器的 `/conf` 目录挂载到本地可以实现配置持久化，下次启动/重启容器时会恢复已持久化的配置。

### 注意

限速功能需要创建 Linux 的虚拟设备来进行流量处理，所以需要：

1. 在容器所在主机执行一遍 `modprobe ifb numifbs=1` 命令
2. 启动容器（Docker Run）时需带上 `--cap-add=NET_ADMIN -v /lib/modules:/lib/modules:ro` 参数
