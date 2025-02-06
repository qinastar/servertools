#!/usr/bin/env bash

QB_USER="q7nana"
QB_PASS="qwq12345"
QB_HOST="localhost"
QB_PORT="2333"
DOWNLOAD_DIR="/home/q7nana/qbittorrent/Downloads"

# 将日志文件记录在当前目录下
LOG_FILE="./qb_orphan_cleanup.log"
TEST_MODE=true

CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

# 从 qBittorrent API 获取当前种子信息JSON
TORRENTS_JSON=$(curl -s --header "Referer: http://$QB_HOST:$QB_PORT/" \
                      --user $QB_USER:$QB_PASS \
                      "http://$QB_HOST:$QB_PORT/api/v2/torrents/info")

if [ -z "$TORRENTS_JSON" ] || [ "$TORRENTS_JSON" = "[]" ]; then
    # 未获取到任何种子信息
    TORRENT_COUNT=0
    TOTAL_SIZE_BYTES=0
    echo "$CURRENT_TIME 未获取到种子信息，请检查qBittorrent是否正常运行。" >> "$LOG_FILE"
else
    # 使用 jq 解析出当前种子数量和总大小
    TORRENT_COUNT=$(echo "$TORRENTS_JSON" | jq 'length')
    TOTAL_SIZE_BYTES=$(echo "$TORRENTS_JSON" | jq '[.[].total_size] | add')
fi

# 将活跃种子路径列表写入临时文件
echo "$TORRENTS_JSON" | jq -r '.[].save_path' | sort -u > /tmp/active_paths.txt

ORPHAN_FOUND=false

# 遍历下载目录
while IFS= read -r -d '' item; do
    if grep -Fxq "$(dirname "$item")/" /tmp/active_paths.txt; then
        # 属于活跃种子路径
        if [ "$TEST_MODE" = true ]; then
            echo "[TEST_MODE] 正常文件/目录: $item"
        fi
    else
        # 残留文件/目录
        ORPHAN_FOUND=true
        if [ "$TEST_MODE" = true ]; then
            echo "$CURRENT_TIME [TEST_MODE] 残留文件/目录: $item" | tee -a "$LOG_FILE"
        else
            rm -rf "$item"
            echo "$CURRENT_TIME 删除残留文件/目录: $item" >> "$LOG_FILE"
        fi
    fi
done < <(find "$DOWNLOAD_DIR" -mindepth 1 -maxdepth 1 -print0)

# 将总大小转化为人类可读格式（可选）
TOTAL_SIZE_HUMAN=$(numfmt --to=iec --suffix=B $TOTAL_SIZE_BYTES 2>/dev/null)

if [ "$ORPHAN_FOUND" = false ]; then
    # 无残留文件的情况，也写日志并显示种子统计信息
    echo "$CURRENT_TIME 无残留文件。检测了${TORRENT_COUNT}个种子，总大小：${TOTAL_SIZE_HUMAN}" >> "$LOG_FILE"
else
    # 有残留文件时在日志中附加一条统计信息
    echo "$CURRENT_TIME 共检测了${TORRENT_COUNT}个种子，总大小：${TOTAL_SIZE_HUMAN}" >> "$LOG_FILE"
fi

# 在终端打印统计信息（可选）
echo "检测完成：共${TORRENT_COUNT}个种子, 总大小为${TOTAL_SIZE_HUMAN}"
