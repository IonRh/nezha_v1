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

is_agent_enabled() {
    [ -n "$IDU" ] && [ -n "$NZ_DOMAIN" ]
}

preserve_existing_user_theme() {
    local theme_backup="$WORK_DIR/.preserved-user-dist"

    rm -rf "$theme_backup"
    [ ! -d "$WORK_DIR/user-dist" ] && return 1

    cp -r "$WORK_DIR/user-dist" "$theme_backup"
}

restore_preserved_user_theme() {
    local theme_backup="$WORK_DIR/.preserved-user-dist"

    [ ! -d "$theme_backup" ] && return 0

    rm -rf "$WORK_DIR/user-dist"
    mv "$theme_backup" "$WORK_DIR/user-dist"
    echo "保留现有 user-dist"
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
dashboard_updated=0
agent_updated=0
agent_enabled=0

if [ -z "$DASHBOARD_VERSION" ]; then
    preserve_existing_user_theme || true
    update_component "nezhahq/nezha" "dashboard-linux-${ARCH}.zip" "dashboard" && dashboard_updated=1 || true
fi

if is_agent_enabled; then
    agent_enabled=1
    update_component "nezhahq/agent" "nezha-agent_linux_${ARCH}.zip" "agent" && agent_updated=1 || true
fi

if [ "$dashboard_updated" -eq 1 ] || [ "$agent_updated" -eq 1 ]; then
    if [ "$dashboard_updated" -eq 1 ]; then
        restore_preserved_user_theme
    else
        rm -rf "$WORK_DIR/.preserved-user-dist"
    fi

    chmod +x dashboard-linux-${ARCH} 2>/dev/null || true
    [ -f "nezha-agent" ] && chmod +x nezha-agent
    echo "重启服务..."

    if [ "$dashboard_updated" -eq 1 ]; then
        pkill -f "dashboard-linux-${ARCH}" || true
    fi
    if [ "$agent_enabled" -eq 1 ] && [ "$agent_updated" -eq 1 ]; then
        pkill -f "nezha-agent" || true
    fi

    sleep 1

    if [ "$dashboard_updated" -eq 1 ]; then
        nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &
    fi
    if [ "$agent_enabled" -eq 1 ] && [ "$agent_updated" -eq 1 ]; then
        nohup ./nezha-agent >/dev/null 2>&1 &
    fi

    echo "更新完成"
else
    rm -rf "$WORK_DIR/.preserved-user-dist"
    echo "已是最新版本"
fi
