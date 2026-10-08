# Dell PowerEdge R720 Fan Speed Control (Docker)

通过 IPMI over LAN 控制 R720 风扇转速的 Docker 容器。容器以一次性执行模式运行（通过 Docker `restart: unless-stopped` 自动恢复）。

## 原理

1. 通过 IPMI over LAN 连接 R720 BMC
2. 发送 Dell OEM 命令将风扇切换为手动控制模式
3. 写入固定转速百分比
4. 容器退出，Docker 在宿主机重启或容器异常时自动重新执行

## 环境变量

| 变量 | 说明 | 默认值 | 示例 |
|---|---|---|---|
| `BMC_IP` | BMC 地址 | 必填 | `192.168.1.100` |
| `BMC_USER` | BMC 用户名 | 必填 | `root` |
| `BMC_PASS` | BMC 密码 | 必填 | `calvin` |
| `FAN_SPEED` | 风扇百分比 (0-100) | 必填 | `30` |
| `RETRY_COUNT` | BMC 不可达时的重试次数 | `10` | `15` |
| `RETRY_INTERVAL` | 重试间隔（秒） | `5` | `10` |

## 部署

### 方式 1: Docker Compose（推荐）

```bash
docker compose up -d --build
```

### 方式 2: Docker CLI

```bash
docker build -t dell-fan-control .
docker run -d \
  --restart unless-stopped \
  -e BMC_IP=192.168.1.100 \
  -e BMC_USER=root \
  -e BMC_PASS=calvin \
  -e FAN_SPEED=30 \
  dell-fan-control
```

### 方式 3: systemd 托管（确保宿主机开机启动）

```bash
sudo mkdir -p /opt/dell-fan-control
sudo cp -r * /opt/dell-fan-control/
sudo cp dell-fan-control.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now dell-fan-control.service
```

## 日志

```bash
docker logs -f dell-fan-control
```

## IPMI 命令说明

使用 Dell 12G/13G 服务器典型 OEM raw command：

- 手动模式：`ipmitool raw 0x30 0x30 0x01 0x00`
- 设置转速：`ipmitool raw 0x30 0x30 0x02 0xff <hex_speed>`

容器会自动尝试加密接口（`lanplus`），若失败则降级为未加密接口（`lan`）。

## 风险注意

1. **命令兼容性**：上述 raw command 为已知 12G/13G 实现，**尚未在 R720 实机上验证**，投入使用前务必先测试。
2. **过热风险**：固定低速风扇在高温负载下可能导致服务器过热，建议初始测试使用较高速度（如 50%）。
3. **凭据安全**：环境变量通过 `docker inspect` 可见，生产环境建议使用 Docker secrets。
4. **BMC 固件**：较旧 BMC 固件可能不支持加密 IPMI，容器已自动降级处理。

## 修改配置后生效

```bash
docker compose up -d --force-recreate dell-fan-control
# 或
docker restart dell-fan-control
```
