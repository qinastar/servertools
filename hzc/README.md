# qBittorrent 上传监控工具

这是一个用于监控 qBittorrent 上传流量的自动化工具。当总上传量达到预设限制（19TB）时，系统将自动关机以保护您的账户。

## 功能特点

- 自动监控 qBittorrent 的上传流量
- 当上传量达到19TB时自动关机
- 系统服务自动启动
- 定期检查（每10秒一次）
- 安全可靠的系统服务集成

## 系统要求

- Linux操作系统（基于Debian/Ubuntu）
- root权限
- qBittorrent Web UI（默认端口2333）
- 以下依赖包：
  - jq
  - curl

## 安装方法

一键安装命令：
```bash
curl -fsSL https://raw.githubusercontent.com/qinastar/servertools/main/hzc/install_qb_monitor.sh | sudo bash
```

或者使用wget：
```bash
wget -qO- https://raw.githubusercontent.com/qinastar/servertools/main/hzc/install_qb_monitor.sh | sudo bash
```

## 服务管理

安装完成后，您可以使用以下命令管理服务：

- 查看服务状态：
```bash
systemctl status qb-upload-monitor
```

- 停止服务：
```bash
systemctl stop qb-upload-monitor
```

- 启动服务：
```bash
systemctl start qb-upload-monitor
```

- 禁用开机自启：
```bash
systemctl disable qb-upload-monitor
```

## 配置说明

- 监控脚本位置：`/hzc/check_qb_upload.sh`
- 服务配置文件：`/etc/systemd/system/qb-upload-monitor.service`
- 默认qBittorrent Web UI地址：`http://localhost:2333`
- 上传限制：19TB

## 注意事项

1. 请确保qBittorrent的Web UI已启用并可访问
2. 确保系统时间准确
3. 建议定期检查服务运行状态
4. 达到限制后系统将自动关机，请确保没有其他重要任务在运行

## 问题排查

如果服务无法正常运行，请检查：

1. qBittorrent Web UI是否可访问
2. 系统日志：
```bash
journalctl -u qb-upload-monitor
```
3. 确认脚本权限是否正确
4. 检查依赖包是否正确安装

## 许可证

MIT License 