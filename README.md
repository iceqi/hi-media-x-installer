# HiMediaX 安装器

HiMediaX 是面向媒体本地化和管理的 Docker 化服务。用户只需要准备 Docker，不需要安装 Go、Node.js 或 Python。

本仓库是公开的用户安装入口，不包含 HiMediaX 主程序源码。

## 一键安装

建议在专用目录中执行：

```bash
sudo mkdir -p /opt/himediax
cd /opt/himediax
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
```

安装脚本会自动下载 Compose 模板并显示菜单：

```text
1) 先安装小雅
2) 快速安装 HiMediaX + 小雅控制器
3) 只安装 HiMediaX
4) 只安装小雅控制器
```

直接回车默认选择第 1 项。选择第 1 项只安装小雅，完成后再次运行脚本选择第 2 项安装 HiMediaX 和小雅控制器。

安装目录默认是执行命令时的当前目录。脚本会在该目录生成：

```text
.env
compose.full.yaml
docker-compose.yml
compose.controller.yaml
```

## 安装选项

### 1. 快速安装

一次启动：

- HiMediaX 主程序
- 小雅控制器

脚本会询问数据目录、媒体库目录、端口、JWT 密钥和小雅控制器 Token。密钥留空时自动生成强随机值。

### 2. 只安装 HiMediaX

适合小雅控制器已经部署在其他服务器的场景。主程序使用 `docker-compose.yml`。

### 3. 只安装小雅控制器

脚本会额外询问：

- HiMediaX 服务地址，例如 `http://192.168.1.100:18080`
- 已经在 HiMediaX 中使用的小雅控制器 Token

脚本会自动探测当前服务器 IP，并设置小雅控制器回调地址和对外通告地址。控制器与 HiMediaX 使用相同 Token 时才能完成认证。

## 手动 Compose

默认全量部署：

```bash
docker compose --env-file .env -f compose.full.yaml pull
docker compose --env-file .env -f compose.full.yaml up -d
docker compose --env-file .env -f compose.full.yaml ps
```

只部署主程序：

```bash
docker compose --env-file .env -f docker-compose.yml pull
docker compose --env-file .env -f docker-compose.yml up -d
```

只部署小雅控制器：

```bash
docker compose --env-file .env -f compose.controller.yaml pull
docker compose --env-file .env -f compose.controller.yaml up -d
```

## GuessIt（可选）

GuessIt 暂时不属于默认安装内容。需要时手动执行：

```bash
docker compose -f compose.guessit.yaml pull
docker compose -f compose.guessit.yaml up -d
```

## 更新

在安装目录执行：

```bash
docker compose --env-file .env -f compose.full.yaml pull
docker compose --env-file .env -f compose.full.yaml up -d
docker compose --env-file .env -f compose.full.yaml ps
```

单独部署模式请替换为实际使用的 Compose 文件。

## 端口和目录

默认端口：

| 用途 | 默认端口 |
| --- | ---: |
| HiMediaX 管理页面 | 18080 |
| HiMediaX WebDAV | 18081 |
| HiMediaX 播放代理 | 18096 |
| 小雅控制器 | 19090 |
| GuessIt（可选） | 18084 |

脚本会交互询问宿主机目录。不要把包含敏感配置的 `.env` 提交到公开仓库。

## 镜像架构

官方镜像支持：

```text
linux/amd64
linux/arm64
```

Docker 会根据服务器架构自动拉取对应镜像。

主程序镜像：

```text
iceqi/hi-media-x:latest
```

小雅控制器镜像：

```text
iceqi/hi-media-x-controller:latest
```

GuessIt 镜像：

```text
iceqi/hi-media-x-guessit:latest
```

## 镜像代理

安装脚本支持通过环境变量指定镜像代理，代理地址可以带或不带协议头：

HIMEDIAX_MIRROR=https://gh-proxy.org bash install.sh

也可以使用：

HIMEDIAX_IMAGE_REGISTRY=gh-proxy.org bash install.sh

直接远程安装：

curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash

不设置时默认使用 docker.io。镜像代理必须支持直接访问 iceqi/hi-media-x 和 iceqi/hi-media-x-controller 镜像路径。


安装脚本会自动生成缓存版本并刷新 Compose 模板，不需要手动添加 v 参数。

Docker Hub 安装：
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash

镜像代理安装：
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash
