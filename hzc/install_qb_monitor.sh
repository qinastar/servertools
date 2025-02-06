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
MAX_LINES=10

# 使用curl访问qBittorrent的Web API
response=$(curl -s "http://localhost:2333/api/v2/transfer/info")

# 使用jq解析JSON响应，获取总上传量（以字节为单位）
uploaded=$(echo $response | jq -r '.up_info_data')

# 转换字节为TB
uploaded_tb=$(echo "scale=3; $uploaded/1024/1024/1024/1024" | bc)

# 获取当前时间
current_time=$(date '+%Y-%m-%d %H:%M:%S')

# 创建新的日志条目
log_entry="[$current_time] 已上传: ${uploaded_tb}TB"

# 如果日志文件不存在，创建它
if [ ! -f "$LOG_FILE" ]; then
    echo "$log_entry" > "$LOG_FILE"
else
    # 将新日志添加到临时文件
    echo "$log_entry" > "$LOG_FILE.tmp"
    # 添加原有日志的前9行（如果存在）
    tail -n 9 "$LOG_FILE" >> "$LOG_FILE.tmp"
    # 替换原有日志文件
    mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

# 19TB转换为字节 (19 * 1024 * 1024 * 1024 * 1024)
limit=20889931046912

# 检查是否超过19TB
if [ "$uploaded" -gt "$limit" ]; then
    echo "[$current_time] 警告：上传量超过19TB，系统将关机" >> "$LOG_FILE"
    shutdown -h now
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