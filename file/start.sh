#!/bin/bash

chmod +x restart.sh backup.sh restore.sh renew.sh
export TZ='Asia/Shanghai'

WORK_DIR=/app
CONFIG_FILE="/app/data/config.yaml"

# 检测架构
case $(uname -m) in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    s390x)   ARCH="s390x" ;;
    *)       echo "Unsupported architecture"; exit 1 ;;
esac

change_config() {
    [ ! -f "$CONFIG_FILE" ] && return
    if grep -q "^force_auth:" "$CONFIG_FILE"; then
        sed -i "s/^force_auth:.*/force_auth: $Force_Auth/" "$CONFIG_FILE"
    else
        echo "force_auth: $Force_Auth" >> "$CONFIG_FILE"
    fi
    echo "force_auth 已设置为 $Force_Auth"
}

download_agent_dashboard() {
    local dash_file="dashboard-linux-${ARCH}.zip"
    local agent_file="nezha-agent_linux_${ARCH}.zip"

    # 确定 dashboard 版本下载 URL
    if [ -z "$DASHBOARD_VERSION" ]; then
        local dash_url="https://github.com/nezhahq/nezha/releases/latest/download/$dash_file"
    else
        local dash_url="https://github.com/nezhahq/nezha/releases/download/$DASHBOARD_VERSION/$dash_file"
    fi

    echo "Downloading dashboard & agent..."
    wget -q "$dash_url" -O "$dash_file" || { echo "Error downloading dashboard"; exit 1; }
    unzip -qo "$dash_file" -d "$WORK_DIR" && rm -f "$dash_file"

    wget -q "https://github.com/nezhahq/agent/releases/latest/download/$agent_file" -O "$agent_file" || { echo "Error downloading agent"; exit 1; }
    unzip -qo "$agent_file" -d "$WORK_DIR" && rm -f "$agent_file"
    echo "下载完成"
}

setup_ssl() {
    openssl genrsa -out "$WORK_DIR/nezha.key" 2048
    openssl req -new -key "$WORK_DIR/nezha.key" -out "$WORK_DIR/nezha.csr" -subj "/CN=$NZ_DOMAIN"
    openssl x509 -req -days 3650 -in "$WORK_DIR/nezha.csr" -signkey "$WORK_DIR/nezha.key" -out "$WORK_DIR/nezha.pem"
    chmod 600 "$WORK_DIR/nezha.key"
    chmod 644 "$WORK_DIR/nezha.pem"
}

create_caddy_config() {
    mkdir -p /etc/caddy
    cat << 'CADDYEOF' > /etc/caddy/Caddyfile
:80 {
    map {http.request.header.CF-Connecting-IP} {real_ip} {
        ~.+ {http.request.header.CF-Connecting-IP}
        default {remote_host}
    }

    reverse_proxy /proto.NezhaService/* {
        header_up Host {host}
        header_up nz-realip {real_ip}
        header_up CF-Connecting-IP {real_ip}
        transport http {
            versions h2c
            read_buffer 4096
        }
        to localhost:8008
    }

    reverse_proxy {
        header_up Host {host}
        header_up Origin https://{host}
        header_up nz-realip {real_ip}
        header_up CF-Connecting-IP {real_ip}
        transport http {
            read_buffer 16384
        }
        to localhost:8008
    }
}
CADDYEOF

    # 443 块需要引用变量，单独写入
    cat << EOF >> /etc/caddy/Caddyfile

:443 {
    tls $WORK_DIR/nezha.pem $WORK_DIR/nezha.key
EOF
    cat << 'CADDYEOF' >> /etc/caddy/Caddyfile

    map {http.request.header.CF-Connecting-IP} {real_ip} {
        ~.+ {http.request.header.CF-Connecting-IP}
        default {remote_host}
    }

    reverse_proxy /proto.NezhaService/* {
        header_up Host {host}
        header_up nz-realip {real_ip}
        header_up CF-Connecting-IP {real_ip}
        transport http {
            versions h2c
            read_buffer 4096
        }
        to localhost:8008
    }

    reverse_proxy {
        header_up Host {host}
        header_up Origin https://{host}
        header_up nz-realip {real_ip}
        header_up CF-Connecting-IP {real_ip}
        transport http {
            read_buffer 16384
        }
        to localhost:8008
    }
}
CADDYEOF
}

check_env_variables() {
    [ -z "$NZ_DOMAIN" ] && { echo "Error: NZ_DOMAIN not set"; exit 1; }
    [ -z "$ARGO_AUTH" ] && { echo "Error: ARGO_AUTH not set"; exit 1; }
    [ -z "$NZ_agentsecretkey" ] && { echo "Error: NZ_agentsecretkey not set"; exit 1; }
}

start_services() {
    nohup caddy run --config /etc/caddy/Caddyfile >/dev/null 2>&1 &

    # cloudflared 也需要按架构选择
    local cf_bin="cloudflared-linux-${ARCH}"
    nohup ./$cf_bin tunnel --protocol http2 run --token "$ARGO_AUTH" >/dev/null 2>&1 &

    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &

    cat << EOF > config.yml
client_secret: $NZ_agentsecretkey
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 4
server: $NZ_DOMAIN:443
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: true
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: $IDU
EOF
    nohup ./nezha-agent >/dev/null 2>&1 &
}

stop_services() {
    pkill -f "dashboard-linux-|cloudflared-linux-|nezha-agent|caddy" || true
}

main() {
    check_env_variables

    [ -f "restore.sh" ] && ./restore.sh

    setup_ssl
    create_caddy_config
    download_agent_dashboard

    # 下载 cloudflared
    local cf_bin="cloudflared-linux-${ARCH}"
    [ ! -f "$cf_bin" ] && wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/$cf_bin"

    chmod +x "dashboard-linux-${ARCH}" "$cf_bin" nezha-agent

    start_services
    change_config
    # 重启 dashboard 使 config 生效
    pkill -f "dashboard-linux-${ARCH}" || true
    sleep 1
    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &
}

main

while true; do
    current_date=$(date +"%Y-%m-%d")
    current_hour=$(date +"%H")

    readme_content=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
        "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME/contents/README.md" 2>/dev/null)

    file_date=$(echo "$readme_content" | sed -n 's/^data-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*\.zip$/\1/p')

    if { [ "$file_date" != "$current_date" ] && [ "$current_hour" -eq 4 ]; } || [ "$readme_content" = "backup" ]; then
        [ -f "backup.sh" ] && ./backup.sh
        [ -z "$DASHBOARD_VERSION" ] && ./renew.sh
    fi

    sleep 3600
done
