#!/bin/bash
set -ex

# 添加虚拟网络设备，用于实现限速
if [[ ${RATE_LIMIT} == "true" ]]; then
  (modprobe ifb numifbs=1 && ip link add ifb0 type ifb) || (
    echo "添加 IFB 失败"
    exit 1
  )
  echo "添加 IFB 成功"
fi

# 配置 nginx 日志的 logrotate
cat >/etc/logrotate.d/nginx <<'EOF'
/nginx/logs/*.log {
  daily
  size 50M
  missingok
  rotate 5
  compress
  delaycompress
  notifempty
  copytruncate
}
EOF

# 配置一遍限速
./rate-limit.sh

# 启动服务
forego start
