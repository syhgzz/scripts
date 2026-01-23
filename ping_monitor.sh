#!/bin/bash
# 使用方法: nohup ./ping_monitor.sh 2> error.log &

# 目标地址
TARGET1="163.com"
TARGET2="192.168.1.1"
TARGET3="10.66.98.1"
TARGET4="10.61.10.10"
TARGET5="10.61.10.11"

# 测试222333444555666

# 日志时间戳函数
timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# 检查目标并输出到错误流
check_ping() {
    local target="$1"
    echo "$(timestamp) INFO: 正在ping $target..." 
    if ! ping -c 1 -W 2 "$target"  2>&1; then
        echo "$(timestamp) ERROR: 无法ping通 $target" >&2
        return 1
    fi
    return 0
}

# 主循环
echo "$(timestamp) INFO: 开始ping监控..." >&2
while true; do
    check_ping "$TARGET1"
    echo ""
    check_ping "$TARGET2"
    echo ""
    check_ping "$TARGET3"
    echo ""
    check_ping "$TARGET4"
    echo ""
    check_ping "$TARGET5"
    sleep 5  # 每5秒检查一次
done