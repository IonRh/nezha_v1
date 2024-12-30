#!/bin/bash

stop_services() {
    pkill -f "dashboard-linux-amd64"
}
WORK_DIR=/app
REPOS=(
    "nezhahq/nezha:dashboard-linux-amd64.zip:dashboard"
    "nezhahq/agent:nezha-agent_linux_amd64.zip:agent"
)

get_local_version() {
    local component="$1"
    local version=""
    
    case "$component" in
        dashboard)
            version=$(./dashboard-linux-amd64 -v 2>/dev/null)
            ;;
        agent)
            version=$(./nezha-agent -v 2>/dev/null | awk '{print $3}')
            ;;
    esac
    
    echo "$version" | grep -oE '[0-9.]+'
}

get_remote_version() {
    local repo="$1"
    local version=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v?([0-9.]+)".*/\1/')
    
    echo "$version"
}

download_and_extract() {
    local repo="$1" filename="$2"
    
    wget -q "https://github.com/$repo/releases/latest/download/$filename" -O "$filename"
    if [ $? -eq 0 ]; then
        unzip -qo "$filename" -d "$WORK_DIR" && rm "$filename"
        return 0
    fi
    return 1
}

update_dashboard() {
    local repo="nezhahq/nezha"
    local filename="dashboard-linux-amd64.zip"
    local component="dashboard"
    
    local local_version=$(get_local_version "$component")
    local remote_version=$(get_remote_version "$repo")
    
    if [ -z "$local_version" ] || [ "$local_version" != "$remote_version" ]; then
        echo "$component Existence Update..."
        download_and_extract "$repo" "$filename"
    else
        echo "$component Does not exist Update..."
    fi
}

update_agent() {
    local repo="nezhahq/agent"
    local filename="nezha-agent_linux_amd64.zip"
    local component="agent"
    
    local local_version=$(get_local_version "$component")
    local remote_version=$(get_remote_version "$repo")
    
    if [ -z "$local_version" ] || [ "$local_version" != "$remote_version" ]; then
        download_and_extract "$repo" "$filename"
    else
        echo "$component Does not exist Update..."
    fi
}

start_services() {
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
}
echo "stop dashboard ..."
stop_services
echo "start renew dashboard ..."
update_dashboard
update_agent
echo "start dashboard ..."
start_services
