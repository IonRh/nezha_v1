#!/bin/bash
set -e

WORK_DIR=/app
cd "$WORK_DIR"

# 检测架构
case $(uname -m) in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    s390x)   ARCH="s390x" ;;
    *)       echo "Unsupported arch"; exit 1 ;;
esac

get_local_version() {
    case "$1" in
        dashboard) ./dashboard-linux-${ARCH} -v 2>/dev/null | grep -oE '[0-9.]+' ;;
        agent)     ./nezha-agent -v 2>/dev/null | grep -oE '[0-9.]+' ;;
    esac
}

get_remote_version() {
    curl -sL "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | grep -oE '[0-9.]+'
}

update_component() {
    local repo="$1" filename="$2" component="$3"
    local local_ver=$(get_local_version "$component")
    local remote_ver=$(get_remote_version "$repo")

    [ -z "$remote_ver" ] && return 1
    [ "$local_ver" = "$remote_ver" ] && return 1

    echo "更新 $component: $local_ver -> $remote_ver"
    wget -q "https://github.com/$repo/releases/latest/download/$filename" -O "$filename"
    unzip -qo "$filename" -d "$WORK_DIR" && rm -f "$filename"
}

echo "检查更新..."
updated=0

update_component "nezhahq/nezha" "dashboard-linux-${ARCH}.zip" "dashboard" && updated=1 || true
update_component "nezhahq/agent" "nezha-agent_linux_${ARCH}.zip" "agent" && updated=1 || true

if [ "$updated" -eq 1 ]; then
    chmod +x dashboard-linux-${ARCH} nezha-agent 2>/dev/null || true
    echo "重启服务..."
    pkill -f "dashboard-linux-${ARCH}|nezha-agent" || true
    sleep 1
    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &
    nohup ./nezha-agent >/dev/null 2>&1 &
    echo "更新完成"
else
    echo "已是最新版本"
fi
