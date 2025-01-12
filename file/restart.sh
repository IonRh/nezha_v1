#!/bin/bash

stop_services() {
    pkill -f "dashboard-linux-amd64"
}


start_services() {
    nohup ./dashboard-linux-amd64 >/dev/null 2>&1 &
}

echo "stop dashboard ..."
stop_services
echo "start dashboard ..."
start_services
