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

    echo "Downloading dashboard..."
    wget -q "$dash_url" -O "$dash_file" || { echo "Error downloading dashboard"; exit 1; }
    unzip -qo "$dash_file" -d "$WORK_DIR" && rm -f "$dash_file"

    # 仅在同时设置了 IDU 与 NZ_DOMAIN 时下载 agent
    if [ -n "$IDU" ] && [ -n "$NZ_DOMAIN" ]; then
        echo "Downloading agent..."
        wget -q "https://github.com/nezhahq/agent/releases/latest/download/$agent_file" -O "$agent_file" || { echo "Error downloading agent"; exit 1; }
        unzip -qo "$agent_file" -d "$WORK_DIR" && rm -f "$agent_file"
    else
        echo "未设置 IDU 或 NZ_DOMAIN，跳过 agent 安装"
    fi
    echo "下载完成"
}

setup_ssl() {
    openssl genrsa -out "$WORK_DIR/nezha.key" 2048
    openssl req -new -key "$WORK_DIR/nezha.key" -out "$WORK_DIR/nezha.csr" -subj "/CN=$NZ_DOMAIN"
    openssl x509 -req -days 3650 -in "$WORK_DIR/nezha.csr" -signkey "$WORK_DIR/nezha.key" -out "$WORK_DIR/nezha.pem"
    chmod 600 "$WORK_DIR/nezha.key"
    chmod 644 "$WORK_DIR/nezha.pem"
}

create_nginx_config() {
    cat << 'EOF' > /etc/nginx/conf.d/default.conf
map $http_x_forwarded_for $xff_first_ip {
    default "";
    "~^(?P<first>[^,]+)" $first;
}

map $http_cf_connecting_ip $real_ip {
    default $xff_first_ip;
    "~.+"   $http_cf_connecting_ip;
}

map $real_ip $final_ip {
    default $remote_addr;
    "~.+"   $real_ip;
}

server {
    listen 80;
    http2 on;

    underscores_in_headers on;

    location ^~ /proto.NezhaService/ {
        grpc_set_header Host $host;
        grpc_set_header nz-realip $final_ip;
        grpc_set_header CF-Connecting-IP $final_ip;
        grpc_read_timeout 600s;
        grpc_send_timeout 600s;
        grpc_socket_keepalive on;
        client_max_body_size 10m;
        grpc_buffer_size 4m;
        grpc_pass grpc://dashboard;
    }

    location ~* ^/api/v1/ws/(server|terminal|file)(.*)$ {
        proxy_set_header Host $host;
        proxy_set_header nz-realip $final_ip;
        proxy_set_header CF-Connecting-IP $final_ip;
        proxy_set_header Origin https://$host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass http://127.0.0.1:8008;
    }

    location / {
        proxy_set_header Host $host;
        proxy_set_header nz-realip $final_ip;
        proxy_set_header CF-Connecting-IP $final_ip;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_max_temp_file_size 0;
        proxy_pass http://127.0.0.1:8008;
    }
}

upstream dashboard {
    server 127.0.0.1:8008;
    keepalive 512;
}
EOF

    # 443 端口配置（agent 通过 CF Tunnel 连接）
    cat << SSLEOF > /etc/nginx/conf.d/ssl.conf
server {
    listen 443 ssl;
    http2 on;

    ssl_certificate     $WORK_DIR/nezha.pem;
    ssl_certificate_key $WORK_DIR/nezha.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    underscores_in_headers on;

    set \$real_ip \$remote_addr;
    if (\$http_x_forwarded_for ~* "^([^,]+)") {
        set \$real_ip \$1;
    }
    if (\$http_x_real_ip) {
        set \$real_ip \$http_x_real_ip;
    }
    if (\$http_cf_connecting_ip) {
        set \$real_ip \$http_cf_connecting_ip;
    }

    location ^~ /proto.NezhaService/ {
        grpc_set_header Host \$host;
        grpc_set_header nz-realip \$real_ip;
        grpc_set_header CF-Connecting-IP \$real_ip;
        grpc_read_timeout 600s;
        grpc_send_timeout 600s;
        grpc_socket_keepalive on;
        client_max_body_size 10m;
        grpc_buffer_size 4m;
        grpc_pass grpc://dashboard;
    }

    location ~* ^/api/v1/ws/(server|terminal|file)(.*)\$ {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$real_ip;
        proxy_set_header CF-Connecting-IP \$real_ip;
        proxy_set_header Origin https://\$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass http://127.0.0.1:8008;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$real_ip;
        proxy_set_header CF-Connecting-IP \$real_ip;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_max_temp_file_size 0;
        proxy_pass http://127.0.0.1:8008;
    }
}
SSLEOF
}

check_env_variables() {
    [ -z "$NZ_agentsecretkey" ] && { echo "Error: NZ_agentsecretkey not set"; exit 1; }
}

start_services() {
    nohup nginx >/dev/null 2>&1 &

    # 仅在设置了 ARGO_AUTH 时启动 cloudflared
    if [ -n "$ARGO_AUTH" ]; then
        local cf_bin="cloudflared-linux-${ARCH}"
        nohup ./$cf_bin tunnel --protocol http2 run --token "$ARGO_AUTH" >/dev/null 2>&1 &
    fi

    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &

    # 仅在同时设置了 IDU 与 NZ_DOMAIN 时启动 agent
    if [ -n "$IDU" ] && [ -n "$NZ_DOMAIN" ]; then
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
    fi
}

stop_services() {
    pkill -f "dashboard-linux-|cloudflared-linux-|nezha-agent|nginx" || true
}

main() {
    check_env_variables

    [ -f "restore.sh" ] && ./restore.sh

    setup_ssl
    create_nginx_config
    download_agent_dashboard

    # 仅在设置了 ARGO_AUTH 时下载 cloudflared
    if [ -n "$ARGO_AUTH" ]; then
        local cf_bin="cloudflared-linux-${ARCH}"
        [ ! -f "$cf_bin" ] && wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/$cf_bin"
        chmod +x "$cf_bin"
    fi

    chmod +x "dashboard-linux-${ARCH}"
    [ -f "nezha-agent" ] && chmod +x nezha-agent

    start_services
    change_config
    # 重启 dashboard 使 config 生效
    pkill -f "dashboard-linux-${ARCH}" || true
    sleep 1
    nohup ./dashboard-linux-${ARCH} >/dev/null 2>&1 &
}

main

while true; do
    # 仅在配置了 GitHub 备份相关变量时执行备份逻辑
    if [ -n "$GITHUB_USERNAME" ] && [ -n "$REPO_NAME" ] && [ -n "$GITHUB_TOKEN" ] && [ -n "$ZIP_PASSWORD" ]; then
        current_date=$(date +"%Y-%m-%d")
        current_hour=$(date +"%H")

        readme_content=$(curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3.raw" \
            "https://api.github.com/repos/$GITHUB_USERNAME/$REPO_NAME/contents/README.md" 2>/dev/null)

        file_date=$(echo "$readme_content" | sed -n 's/^data-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)-.*\.zip$/\1/p')

        if { [ "$file_date" != "$current_date" ] && [ "$current_hour" -eq 4 ]; } || [ "$readme_content" = "backup" ]; then
            [ -f "backup.sh" ] && ./backup.sh
            [ -z "$DASHBOARD_VERSION" ] && ./renew.sh
        fi
    else
        # 没有备份配置时仍检查更新
        [ -z "$DASHBOARD_VERSION" ] && ./renew.sh
    fi

    sleep 3600
done
