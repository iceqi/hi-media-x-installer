# HiMediaX 安装说明

## 前置条件

目标服务器需要：

- Docker Engine
- Docker Compose v2
- Bash、curl
- 可访问 Docker Hub 或配置的镜像代理

## 执行安装

```bash
sudo mkdir -p /opt/himediax-installer
cd /opt/himediax-installer
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
```

安装脚本会下载最新 Compose 模板，并提供以下菜单：

1. 全新安装：小雅 + HiMediaX + 小雅控制器
2. 只安装 HiMediaX
3. 安装小雅 + 小雅控制器
4. 只安装小雅控制器
5. 只安装小雅

全新安装时，脚本依次验证小雅、HiMediaX 和 Controller。Controller Token 自动生成，无需预先在 HiMediaX 中手工配置。

## Controller 自动注册

Controller 启动时向 `POST /api/v1/controller/register` 提交自身公开地址，并通过请求头传递安装器生成的 Token。HiMediaX 随后反向调用 Controller 的挑战接口；挑战值、容器信息和 WebDAV 地址全部有效后才原子保存绑定。

重新注册不会覆盖管理员在 HiMediaX 页面修改过的 WebDAV账号密码。更换 Controller 前应先在管理端解除原绑定。

## 配置文件

- `/opt/hi-media-x/himediax.env`：HiMediaX 路径、端口和 JWT 密钥。
- `/opt/hi-media-x-controller/controller.env`：Controller Token、公开地址、小雅目录和服务端口。
- `/opt/xiaoya/xiaoya.env`：小雅容器、数据目录和端口。

环境文件权限为 `0600`。重新运行安装脚本时会复用已有的随机密钥。

## 健康检查

HiMediaX 安装成功必须同时满足：

```text
GET /api/health/live  -> alive
GET /api/health/ready -> ready
```

Controller 独立部署，不参与上述 readiness。

## 更新

重新运行安装脚本，或使用对应环境文件执行 `docker compose pull` 和 `docker compose up -d`。主程序与 Controller 官方镜像均提供 `linux/amd64` 和 `linux/arm64`。

GuessIt 是可选独立服务，使用 `compose.guessit.yaml` 手动部署。
