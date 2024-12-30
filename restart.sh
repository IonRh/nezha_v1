#!/bin/bash
stop_services() {
    pkill -f "dashboard-linux-amd64||nginx"
}

start_services() {
    nohup nginx >/dev/null 2>&1 &
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
}
echo "stop dashboard and nginx..."
stop_services
echo "start dashboard and nginx..."
start_services
