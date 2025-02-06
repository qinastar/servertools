# qBittorrent 上传监控工具

这是一个用于监控 qBittorrent 上传流量的自动化工具。当总上传量达到预设限制（19TB）时，系统将自动关机以保护您的账户。

## 功能特点

- 自动监控 qBittorrent 的上传流量
- 当上传量达到19TB时自动关机
- 系统服务自动启动
- 定期检查（每10秒一次）
- 安全可靠的系统服务集成
- 自动记录上传量日志（保留最近10条记录）

## 系统要求

- Linux操作系统（基于Debian/Ubuntu）
- root权限
- qBittorrent Web UI
- 以下依赖包：
  - jq
  - curl

## 安装方法

### 方法一：独立安装
一键安装命令：
```bash
curl -fsSL https://raw.githubusercontent.com/qinastar/servertools/refs/heads/main/hzc/install_qb_monitor.sh | sudo bash
```

```
curl -fsSL http://lyragame.cloud/sh/install_qb_monitor.sh | sudo bash
```

### 卸载方法
一键卸载命令：
```bash
sudo bash -c 'systemctl stop qb-upload-monitor; systemctl disable qb-upload-monitor; rm -f /etc/systemd/system/qb-upload-monitor.service /root/check_qb_upload.sh /root/qb_upload.log; systemctl daemon-reload && echo "监控服务已完全卸载"'
```

### 方法二：通过NC_QB438.sh安装
在安装qBittorrent时会自动安装监控服务：
```bash
bash NC_QB438.sh <user> <password> [port] [qb_up_port]
```

## 文件位置

- 监控脚本：`/root/check_qb_upload.sh`
- 服务配置：`/etc/systemd/system/qb-upload-monitor.service`
- 日志文件：`/root/qb_upload.log`

## 日志说明

系统会自动记录上传量信息，日志位于 `/root/qb_upload.log`，包含：
- 最近30次的状态记录
- 每10秒更新一次
- 记录内容包括：
  - 连接状态
  - 当前上传量（TB）
  - 实时上传速度（MB/s）
- 超过限制时会记录警告信息

查看日志命令：
```bash
cat /root/qb_upload.log
```

日志示例：
```
[2024-01-01 12:34:56] 状态: 已连接 | 上传量: 15.234TB | 上传速度: 12.45MB/s
[2024-01-01 12:34:46] 状态: 已连接 | 上传量: 15.233TB | 上传速度: 11.98MB/s
[2024-01-01 12:34:36] 错误: 无法连接到qBittorrent Web UI
...
```

## 服务管理

服务管理命令：
- 查看状态：`systemctl status qb-upload-monitor`
- 启动服务：`systemctl start qb-upload-monitor`
- 停止服务：`systemctl stop qb-upload-monitor`
- 重启服务：`systemctl restart qb-upload-monitor`
- 禁用自启：`systemctl disable qb-upload-monitor`

## 注意事项

1. 请确保qBittorrent的Web UI已启用并可访问
2. 确保系统时间准确
3. 建议定期检查服务运行状态和日志
4. 达到限制后系统将自动关机，请确保没有其他重要任务在运行

## 问题排查

如果服务无法正常运行，请检查：

1. qBittorrent Web UI是否可访问
2. 系统日志：`journalctl -u qb-upload-monitor`
3. 上传日志：`cat /root/qb_upload.log`
4. 确认脚本权限是否正确
5. 检查依赖包是否正确安装

## 许可证

MIT License 