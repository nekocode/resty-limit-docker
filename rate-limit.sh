#!/bin/bash
set -o errtrace -o pipefail

if [[ ${RATE_LIMIT} != "true" ]]; then
  echo "限速功能已关闭，无法进行限速"
  exit 0
fi

TC=$(command -v tc)
ETHTOOL=$(command -v ethtool)
IP=$(command -v ip)
MODPROBE=$(command -v modprobe)

get_htb_quantum() {
  # Takes input rate in kbit/s as parameter
  local RATE=$1
  local QUANTUM=8000

  if [[ ${RATE} -lt 40000 ]]; then
    QUANTUM=1514
  fi

  echo ${QUANTUM}
}

get_target() {
  # Takes input rate in kbit/s and mtu as parameter
  local RATE=$1
  local MTU=$2
  local KBYTES=$((${RATE} / 8))
  local MS=$((${MTU} / ${KBYTES}))
  local TARGET=5

  if [[ ${MS} -gt 5 ]]; then
    TARGET=$((${MS} + 1))
  fi

  echo "${TARGET}.0ms"
}

get_fq_codel_quantum() {
  # Takes input rate in kbit/s as parameter
  local RATE=$1

  if [[ ${RATE} -lt 100000 ]]; then
    echo "quantum 300"
  fi
}

get_ecn() {
  # Takes input rate in kbit/s as parameter
  local RATE=$1
  local ECN_MINRATE=$2

  [[ -n ${ECN_MINRATE} ]] || ECN_MINRATE=0

  if [[ ${RATE} -ge ${ECN_MINRATE} ]]; then
    echo "ecn"
  else
    echo "noecn"
  fi
}

get_mtu() {
  # Takes interface as parameter
  cat /sys/class/net/${1}/mtu
}

get_tx_offloads() {
  # Takes rate in kbit/s as parameter
  local RATE=$1

  if [[ ${RATE} -lt 40000 ]]; then
    echo "tso off gso off"
  else
    echo "tso on gso on"
  fi
}

get_rx_offloads() {
  # Takes rate in kbit/s as parameter
  local RATE=$1

  if [[ ${RATE} -lt 40000 ]]; then
    echo "gro off"
  else
    echo "gro on"
  fi
}

get_limit() {
  # Takes rate in kbit/s as parameter
  local RATE=$1
  local LIMIT=10000

  if [[ ${RATE} -le 10000 ]]; then
    LIMIT=600
  elif [[ ${RATE} -le 100000 ]]; then
    LIMIT=800
  elif [[ ${RATE} -le 1000000 ]]; then
    LIMIT=1200
  fi

  echo ${LIMIT}
}

clear_all() {
  ${TC} qdisc del dev ${IF_NAME} root >/dev/null 2>&1 || true
  ${TC} qdisc del dev ${IF_NAME} ingress >/dev/null 2>&1 || true

  if [[ -n ${IFB_IF_NAME} ]]; then
    ${TC} qdisc del dev ${IFB_IF_NAME} root >/dev/null 2>&1 || true
  fi

  ${ETHTOOL} --offload ${IF_NAME} gro on tso on gso on \
    >/dev/null 2>&1 || true
}

add_prio_classes() {
  local IF_NAME=$1
  local MAX_RATE=$2
  local ECN_MINRATE=$3

  # Default values
  local DEFAULT_CLASS=99
  local DEFAULT_RATE=${MAX_RATE}
  local DEFAULT_PRIO=4

  # Add root handle and set default leaf
  ${TC} qdisc add dev ${IF_NAME} root handle 1: htb default ${DEFAULT_CLASS}

  # Set the overall shaped rate of the interface
  ${TC} class add dev ${IF_NAME} parent 1: classid 1:1 htb \
    rate ${MAX_RATE}kbit \
    quantum $(get_htb_quantum ${MAX_RATE})

  # Create class for the default priority
  ${TC} class add dev ${IF_NAME} parent 1:1 classid 1:${DEFAULT_CLASS} htb \
    rate ${DEFAULT_RATE}kbit \
    ceil ${MAX_RATE}kbit prio ${DEFAULT_PRIO} \
    quantum $(get_htb_quantum ${MAX_RATE})

  # Set qdisc to fq_codel
  ${TC} qdisc replace dev ${IF_NAME} parent 1:${DEFAULT_CLASS} handle ${DEFAULT_CLASS}: fq_codel \
    limit $(get_limit ${MAX_RATE}) \
    target $(get_target ${MAX_RATE} $(get_mtu ${IF_NAME})) \
    $(get_fq_codel_quantum ${MAX_RATE}) \
    $(get_ecn ${MAX_RATE} ${ECN_MINRATE})
}

apply_egress_shaping() {
  # Disable tso and gso for lower bandwiths
  ${ETHTOOL} --offload ${IF_NAME} $(get_tx_offloads ${UP_RATE}) \
    >/dev/null 2>&1 || true

  add_prio_classes \
    ${IF_NAME} \
    ${UP_RATE} \
    4000
}

apply_ingress_shaping() {
  # Disable gro for lower bandwiths
  ${ETHTOOL} --offload ${IF_NAME} $(get_rx_offloads ${DOWN_RATE}) \
    >/dev/null 2>&1 || true

  # Create ingress on interface
  ${TC} qdisc add dev ${IF_NAME} handle ffff: ingress

  # Ensure the ifb interface is up
  ${MODPROBE} ifb
  ${IP} link set dev ${IFB_IF_NAME} up

  # Enabling ECN is recommended for ingress, so ECN_MINRATE is set to 0
  add_prio_classes \
    ${IFB_IF_NAME} \
    ${DOWN_RATE} \
    0

  # Redirect all ingress traffic to IFB egress. Use prio 99 to make it
  # possible to insert filters earlier in the chain.
  ${TC} filter add dev ${IF_NAME} parent ffff: protocol all prio 99 \
    u32 \
    match u32 0 0 \
    action mirred egress redirect dev ${IFB_IF_NAME}
}

####################################

IF_NAME=eth0
IFB_IF_NAME=ifb0

# 从文件中读取 UP_RATE 和 DOWN_RATE 配置
if [[ ! -f "conf/rate-limit" ]]; then
  clear_all
  echo "Config cleared"
  exit 0
fi

# 读取配置
source conf/rate-limit

clear_all

if [[ -n ${UP_RATE} ]]; then
  apply_egress_shaping
fi

if [[ -n ${DOWN_RATE} ]]; then
  apply_ingress_shaping
fi
