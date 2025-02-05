#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用root权限运行此脚本"
    exit 1
fi

# 安装必要的软件包
apt-get update
apt-get install -y jq curl

# 创建工作目录
mkdir -p /hzc

# 创建检查脚本
cat > /hzc/check_qb_upload.sh << 'EOF'
#!/bin/bash

# 使用curl访问qBittorrent的Web API
response=$(curl -s "http://localhost:2333/api/v2/transfer/info")

# 使用jq解析JSON响应，获取总上传量（以字节为单位）
uploaded=$(echo $response | jq -r '.up_info_data')

# 19TB转换为字节 (19 * 1024 * 1024 * 1024 * 1024)
limit=20889931046912

# 检查是否超过19TB
if [ "$uploaded" -gt "$limit" ]; then
    # 如果超过限制，执行关机
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
ExecStart=/bin/bash -c "while true; do /hzc/check_qb_upload.sh; sleep 10; done"
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 设置执行权限
chmod +x /hzc/check_qb_upload.sh

# 重新加载系统服务
systemctl daemon-reload

# 启动并设置开机自启
systemctl enable qb-upload-monitor
systemctl start qb-upload-monitor

echo "安装完成！服务已启动并设置为开机自启。"
echo "可以使用以下命令查看服务状态："
echo "systemctl status qb-upload-monitor" 