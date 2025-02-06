#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <user> <password> <port> <qb_up_port>"
    exit 1
fi

USER=$1
PASSWORD=$2
PORT=${3:-8080}
UP_PORT=${4:-23333}
RAM=$(free -m | awk '/^Mem:/{print $2}')
CACHE_SIZE=$((RAM / 8))

bash <(wget -qO- https://raw.githubusercontent.com/jerry048/Dedicated-Seedbox/main/Install.sh) -u $USER -p $PASSWORD -c $CACHE_SIZE -q 4.3.9 -l v1.2.20 -x
apt install -y curl htop vnstat
systemctl stop qbittorrent-nox@$USER
#systemctl disable qbittorrent-nox@$USER
systemARCH=$(uname -m)
if [[ $systemARCH == x86_64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/x86_64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
elif [[ $systemARCH == aarch64 ]]; then
    wget -O /usr/bin/qbittorrent-nox https://raw.githubusercontent.com/guowanghushifu/Seedbox-Components/refs/heads/main/Torrent%20Clients/qBittorrent/ARM64/qBittorrent-4.3.8%20-%20libtorrent-v1.2.14/qbittorrent-nox
fi
chmod +x /usr/bin/qbittorrent-nox
sed -i "s/WebUI\\\\Port=[0-9]*/WebUI\\\\Port=$PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/Connection\\\\PortRangeMin=[0-9]*/Connection\\\\PortRangeMin=$UP_PORT/" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a General\\\\Locale=zh" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a Downloads\\\\PreAllocation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\CSRFProtection=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\HostHeaderValidation=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\LocalHostAuth=false" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\AuthSubnetWhitelist=127.0.0.1" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "/\\[Preferences\\]/a WebUI\\\\AuthSubnetWhitelistEnabled=true" /home/$USER/.config/qBittorrent/qBittorrent.conf
sed -i "s/disable_tso_/# disable_tso_/" /root/.boot-script.sh
echo "systemctl enable qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "systemctl start qbittorrent-nox@$USER" >> /root/BBRx.sh
echo "shutdown -r +1" >> /root/BBRx.sh
tune2fs -m 1 $(df -h / | awk 'NR==2 {print $1}') 

# 安装上传监控服务
echo "正在安装上传监控服务..."
apt-get install -y jq curl

# 创建检查脚本，使用配置的端口
cat > /root/check_qb_upload.sh << EOF
#!/bin/bash

# 日志文件路径
LOG_FILE="/root/qb_upload.log"
MAX_LINES=30

# 获取当前时间
current_time=\$(date '+%Y-%m-%d %H:%M:%S')

# 使用curl访问qBittorrent的Web API，使用配置的端口
response=\$(curl -s "http://localhost:$PORT/api/v2/transfer/info")

# 检查是否成功获取数据
if [ -z "\$response" ]; then
    log_entry="[\$current_time] 错误: 无法连接到qBittorrent Web UI"
else
    # 使用jq解析JSON响应
    if ! echo "\$response" | jq . >/dev/null 2>&1; then
        log_entry="[\$current_time] 错误: 接收到无效的JSON数据"
    else
        # 获取各项数据
        uploaded=\$(echo \$response | jq -r '.up_info_data')
        up_speed=\$(echo \$response | jq -r '.up_info_speed')
        
        # 转换字节为TB和MB/s
        uploaded_tb=\$(echo "scale=3; \$uploaded/1024/1024/1024/1024" | bc)
        up_speed_mb=\$(echo "scale=2; \$up_speed/1024/1024" | bc)
        
        # 创建新的日志条目
        log_entry="[\$current_time] 状态: 已连接 | 上传量: \${uploaded_tb}TB | 上传速度: \${up_speed_mb}MB/s"
        
        # 19TB转换为字节 (19 * 1024 * 1024 * 1024 * 1024)
        limit=20889931046912
        
        # 检查是否超过19TB
        if [ "\$uploaded" -gt "\$limit" ]; then
            log_entry="[\$current_time] 警告: 上传量(\${uploaded_tb}TB)超过19TB限制，系统将关机"
            echo "\$log_entry" >> "\$LOG_FILE"
            shutdown -h now
        fi
    fi
fi

# 如果日志文件不存在，创建它
if [ ! -f "\$LOG_FILE" ]; then
    echo "\$log_entry" > "\$LOG_FILE"
else
    # 将新日志添加到临时文件
    echo "\$log_entry" > "\$LOG_FILE.tmp"
    # 添加原有日志的前29行（保留最近30条记录）
    tail -n 29 "\$LOG_FILE" >> "\$LOG_FILE.tmp"
    # 替换原有日志文件
    mv "\$LOG_FILE.tmp" "\$LOG_FILE"
fi
EOF

# 创建服务文件
cat > /etc/systemd/system/qb-upload-monitor.service << 'EOF'
[Unit]
Description=qBittorrent Upload Monitor Service
After=network.target qbittorrent-nox@USER.service

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

# 将启动监控服务的命令添加到BBRx.sh中，确保在qBittorrent启动后运行
sed -i "/systemctl start qbittorrent-nox@$USER/a systemctl start qb-upload-monitor" /root/BBRx.sh

echo "接下来将自动重启2次，流程预计5-10分钟..."
shutdown -r +1
