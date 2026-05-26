#!/bin/bash

# 检测架构
case $(uname -m) in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    s390x)   ARCH="s390x" ;;
    *)       ARCH="amd64" ;;
esac

stop_services() {
    pkill -f "dashboard-linux-${ARCH}"
}

start_services() {
    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &
}

echo "stop dashboard ..."
stop_services
echo "start dashboard ..."
start_services
