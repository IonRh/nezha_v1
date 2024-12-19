#!/bin/bash

# 安装 tzdata 确保时区支持
apk add --no-cache tzdata

# 设置时区为上海
export TZ='Asia/Shanghai'

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

setup_ssl() {
    openssl genrsa -out $WORK_DIR/nezha.key 2048
    openssl req -new -key $WORK_DIR/nezha.key -out $WORK_DIR/nezha.csr -subj "/CN=$NZ_DOMAIN"
    openssl x509 -req -days 3650 -in $WORK_DIR/nezha.csr -signkey $WORK_DIR/nezha.key -out $WORK_DIR/nezha.pem

    chmod 600 $WORK_DIR/nezha.key 
    chmod 644 $WORK_DIR/nezha.pem
}

create_nginx_config() {
    cat << EOF > /etc/nginx/conf.d/default.conf
server {
    http2 on;

    server_name $NZ_DOMAIN;
    ssl_certificate          $WORK_DIR/nezha.pem;
    ssl_certificate_key      $WORK_DIR/nezha.key;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;

    underscores_in_headers on;
    set_real_ip_from 0.0.0.0/0;
    real_ip_header CF-Connecting-IP;

    location ^~ /proto.NezhaService/ {
        grpc_set_header Host \$host;
        grpc_set_header nz-realip \$http_CF_Connecting_IP;
        grpc_read_timeout 600s;
        grpc_send_timeout 600s;
        grpc_socket_keepalive on;
        client_max_body_size 10m;
        grpc_buffer_size 4m;
        grpc_pass grpc://dashboard;
    }

    location ~* ^/api/v1/ws/(server|terminal|file)(.*)$ {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$http_cf_connecting_ip;
        proxy_set_header Origin https://\$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_pass http://dashboard;
    }

    location / {
        proxy_set_header Host \$host;
        proxy_set_header nz-realip \$http_cf_connecting_ip;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
        proxy_max_temp_file_size 0;
        proxy_pass http://dashboard;
    }
}

upstream dashboard {
    server localhost:8008;
    keepalive 512;
}
EOF
}

check_env_variables() {
    [ -z "$NZ_DOMAIN" ] && { echo "Error: NZ_DOMAIN not set"; exit 1; }
    [ -z "$ARGO_AUTH" ] && { echo "Error: ARGO_AUTH not set"; exit 1; }
    [ -z "$NZ_agentsecretkey" ] && { echo "Error: NZ_agentsecretkey not set"; exit 1; }
}

start_services() {
    nohup nginx >/dev/null 2>&1 &
    nohup ./cloudflared-linux-amd64 tunnel --protocol http2 run --token "$ARGO_AUTH" >/dev/null 2>&1 &
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
    NZ_SERVER=$NZ_DOMAIN:443 NZ_TLS=true NZ_CLIENT_SECRET=$NZ_agentsecretkey nohup ./nezha-agent >/dev/null 2>&1 &
}

stop_services() {
    pkill -f "dashboard-linux-amd64|cloudflared-linux-amd64|nezha-agent|nginx"
}

main() {
    check_env_variables

    [ -f "restore.sh" ] && { chmod +x restore.sh; ./restore.sh; }

    setup_ssl
    create_nginx_config

    for repo_info in "${REPOS[@]}"; do
        IFS=: read -r repo filename component <<< "$repo_info"
        download_and_update_component "$repo" "$filename" "$component"
    done

    [ ! -f "cloudflared-linux-amd64" ] && wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

    chmod +x dashboard-linux-amd64 cloudflared-linux-amd64 nezha-agent

    start_services
}

main

while true; do
    # Alpine 兼容的时间获取方式
    current_hour=$(date +"%H")
    current_minute=$(date +"%M")

    # 检查是否为凌晨4点
    if [ "$current_hour" -eq 4 ] && [ "$current_minute" -eq 0 ]; then
        # 执行备份
        [ -f "backup.sh" ] && { 
            chmod +x backup.sh
            ./backup.sh
            
            # 确保备份脚本执行完成，避免频繁触发
            sleep 3600
        }
    fi

    sleep 1800

    updated=0
    for repo_info in "${REPOS[@]}"; do
        IFS=: read -r repo filename component <<< "$repo_info"
        if download_and_update_component "$repo" "$filename" "$component"; then
            updated=1
        fi
    done

    if [ $updated -eq 1 ]; then
        stop_services
        main
    fi
done
