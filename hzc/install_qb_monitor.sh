#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 安装必要的软件包
apt-get update
apt-get install -y jq curl

# 创建检查脚本
cat > /root/check_qb_upload.sh << 'EOF'
#!/bin/bash

# 日志文件路径
LOG_FILE="/root/qb_upload.log"
MAX_LINES=30

# 获取当前时间
current_time=$(date '+%Y-%m-%d %H:%M:%S')

# 使用curl访问qBittorrent的Web API
response=$(curl -s "http://localhost:2333/api/v2/transfer/info")

# 检查是否成功获取数据
if [ -z "$response" ]; then
    log_entry="[$current_time] 错误: 无法连接到qBittorrent Web UI"
else
    # 使用jq解析JSON响应
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        log_entry="[$current_time] 错误: 接收到无效的JSON数据"
    else
        # 获取各项数据
        connection_status=$(echo $response | jq -r '.connection_status')
        uploaded=$(echo $response | jq -r '.up_info_data')
        up_speed=$(echo $response | jq -r '.up_info_speed')
        downloaded=$(echo $response | jq -r '.dl_info_data')
        dl_speed=$(echo $response | jq -r '.dl_info_speed')
        
        # 检查数据是否为null或无效
        if [ "$uploaded" = "null" ] || [ "$up_speed" = "null" ]; then
            log_entry="[$current_time] 错误: API返回null值 (uploaded: $uploaded, speed: $up_speed)"
        else
            # 使用awk进行浮点数计算
            uploaded_tb=$(awk "BEGIN {printf \"%.3f\", $uploaded/1024/1024/1024/1024}")
            up_speed_mb=$(awk "BEGIN {printf \"%.2f\", $up_speed/1024/1024}")
            downloaded_tb=$(awk "BEGIN {printf \"%.3f\", $downloaded/1024/1024/1024/1024}")
            dl_speed_mb=$(awk "BEGIN {printf \"%.2f\", $dl_speed/1024/1024}")
            
            # 检查转换是否成功
            if [ $? -ne 0 ] || [ -z "$uploaded_tb" ] || [ -z "$up_speed_mb" ]; then
                log_entry="[$current_time] 错误: 数据转换失败 (原始数据 - uploaded: $uploaded bytes, speed: $up_speed bytes/s)"
            else
                # 创建新的日志条目
                log_entry="[$current_time] 状态: $connection_status | ⬆️ 上传: ${uploaded_tb}TB (${up_speed_mb}MB/s) | ⬇️ 下载: ${downloaded_tb}TB (${dl_speed_mb}MB/s)"
                
                # 19TB转换为字节 (19 * 1024 * 1024 * 1024 * 1024)
                limit=20889931046912
                
                # 检查是否超过19TB
                if [ "$uploaded" -gt "$limit" ]; then
                    log_entry="[$current_time] ⚠️ 警告: 上传量(${uploaded_tb}TB)超过19TB限制，系统将关机"
                    echo "$log_entry" >> "$LOG_FILE"
                    shutdown -h now
                fi
            fi
        fi
    fi
fi

# 如果日志文件不存在，创建它
if [ ! -f "$LOG_FILE" ]; then
    echo "$log_entry" > "$LOG_FILE"
else
    # 将新日志添加到临时文件
    echo "$log_entry" > "$LOG_FILE.tmp"
    # 添加原有日志的前29行（保留最近30条记录）
    tail -n 29 "$LOG_FILE" >> "$LOG_FILE.tmp"
    # 替换原有日志文件
    mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
EOF

# 创建服务文件
cat > /etc/systemd/system/qb-upload-monitor.service << 'EOF'
[Unit]
Description=qBittorrent Upload Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c "while true; do /root/check_qb_upload.sh; sleep 10; done"
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 设置执行权限
chmod +x /root/check_qb_upload.sh

# 重新加载系统服务
systemctl daemon-reload

# 启动并设置开机自启
systemctl enable qb-upload-monitor
systemctl start qb-upload-monitor

echo "安装完成！服务已启动并设置为开机自启。"
echo "可以使用以下命令查看服务状态："
echo "systemctl status qb-upload-monitor"
echo "使用以下命令查看上传日志："
echo "cat /root/qb_upload.log"