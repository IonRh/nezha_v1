#!/bin/bash

# 设置时区为上海
export TZ='Asia/Shanghai'

stop_services() {
    pkill -f "dashboard-linux-amd64|nezha-agent"
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

download_and_update_component() {
    local repo="$1" filename="$2" component="$3"
    
    local local_version=$(get_local_version "$component")
    local remote_version=$(get_remote_version "$repo")
    
    if [ -z "$local_version" ]; then
        wget -q "https://github.com/$repo/releases/latest/download/$filename" -O "$filename"
        if [ $? -eq 0 ]; then
            unzip -qo "$filename" -d "$WORK_DIR" && rm "$filename"
            return 0
        fi
    fi
    
    if [ -z "$remote_version" ]; then
        return 1
    fi
    
    if [ "$local_version" != "$remote_version" ]; then
        wget -q "https://github.com/$repo/releases/latest/download/$filename" -O "$filename"
        if [ $? -eq 0 ]; then
            unzip -qo "$filename" -d "$WORK_DIR" && rm "$filename"
            return 0
        fi
    fi
    
    return 1
}

update(){
for repo_info in "${REPOS[@]}"; do
    IFS=: read -r repo filename component <<< "$repo_info"
    if download_and_update_component "$repo" "$filename" "$component"; then
        updated=1
    fi
done
}



start_services() {
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
    nohup ./nezha-agent >/dev/null 2>&1 &
}
echo "stop dashboard ..."
stop_services
echo "start renew dashboard ..."
update
echo "start dashboard ..."
start_services
