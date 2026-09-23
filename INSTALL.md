# HiMediaX 安装说明

## 前置条件

目标服务器需要：

- Docker Engine
- Docker Compose v2
- Bash、curl
- 可访问 Docker Hub 或配置的镜像代理

## 执行安装

```bash
sudo mkdir -p /srv/himediax
cd /srv/himediax
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

## 安装目录与配置文件

安装目录就是执行脚本时的当前目录：

- `./himediax.env`：HiMediaX 路径、端口和 JWT 密钥。
- `./controller/controller.env`：Controller Token、公开地址、小雅目录和服务端口。
- `./xiaoya/xiaoya.env`：小雅容器、数据目录和端口；小雅数据根目录默认就是 `./xiaoya/`，不会额外拼接一层 `data`。

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

## 镜像代理

Docker Hub 不可达时使用镜像代理：

```bash
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh \
  | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash
```

也可以设置 `HIMEDIAX_IMAGE_REGISTRY`。两种变量都支持带或不带 `http://`、`https://` 前缀。
