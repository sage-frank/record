#!/bin/bash
set -e

BIN="$(pwd)/target/release/record-api"
LOG="/root/record-log.log"

echo "=== Restarting record-api ==="

# 1. 停止旧进程
PID=$(ps -ef | grep "$BIN" | grep -v grep | awk '{print $2}')
if [ -n "$PID" ]; then
    echo "Killing PID=$PID ..."
    kill "$PID" 2>/dev/null || kill -9 "$PID" 2>/dev/null
    sleep 1

    # 确认已停止
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Force killing PID=$PID ..."
        kill -9 "$PID"
        sleep 1
    fi
    echo "Stopped"
else
    echo "No running process found"
fi

# 2. 构建 release
echo "Building release..."
cargo build --release

# 3. 启动
echo "Starting..."
nohup "$BIN" >> "$LOG" 2>&1 &

sleep 1
NEW_PID=$!
if ps -p "$NEW_PID" > /dev/null 2>&1; then
    echo "Started PID=$NEW_PID"
    echo "Logs: tail -f $LOG"
else
    echo "ERROR: Failed to start!"
    tail -20 "$LOG"
    exit 1
fi
