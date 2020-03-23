#!/bin/bash
set -ex

while getopts i:u:d: arg; do
  case "$arg" in
  i) IP_LIMIT="$OPTARG" ;;
  u) UP_RATE_LIMIT="$OPTARG" ;;
  d) DOWN_RATE_LIMIT="$OPTARG" ;;
  esac
done

# 配置 ip-limit
rm -f /conf/ip-limit
if [[ -n ${IP_LIMIT} ]]; then
  echo "set \$_pool_max_size ${IP_LIMIT};" >>/conf/ip-limit
fi

# 配置 rate-limit
rm -f /conf/rate-limit
if [[ -n ${UP_RATE_LIMIT} ]]; then
  echo "UP_RATE=${UP_RATE_LIMIT}" >>/conf/rate-limit
fi
if [[ -n ${DOWN_RATE_LIMIT} ]]; then
  echo "DOWN_RATE=${DOWN_RATE_LIMIT}" >>/conf/rate-limit
fi

# 重载所有配置
./rate-limit.sh
openresty -c /nginx/nginx.conf -p /nginx -s reload
