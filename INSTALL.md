# HiMediaX 安装说明

## 一键安装

在目标服务器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
```

脚本默认使用当前执行目录作为安装目录。建议先进入专用目录：

```bash
sudo mkdir -p /opt/himediax
cd /opt/himediax
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
```

脚本会自动下载 Compose 模板，然后显示菜单：

1. 快速安装 HiMediaX + 小雅控制器
2. 只安装 HiMediaX
3. 只安装小雅控制器

默认直接回车选择第 1 项。

## 配置说明

脚本会交互询问：

- 数据目录和媒体库目录
- 管理端、WebDAV、播放代理端口
- 小雅数据目录、配置目录和小雅控制器工作目录
- HiMediaX 服务地址（单独安装小雅控制器时）
- JWT 密钥和小雅控制器 Token

留空密钥时会使用 `openssl rand -hex 32` 自动生成。生成的 `.env` 位于当前安装目录，并设置为仅当前用户可读写。

单独安装小雅控制器时，必须输入已经运行的 HiMediaX 服务地址和已有的小雅控制器 Token。脚本会自动探测控制器服务器 IP，并写入回调地址。

## 可选 GuessIt

GuessIt 暂不默认安装。如需启用：

```bash
docker compose -f compose.guessit.yaml pull
docker compose -f compose.guessit.yaml up -d
```

## 更新

```docker compose --env-file .env -f compose.full.yaml pull
docker compose --env-file .env -f compose.full.yaml up -d
```

镜像同时提供 `linux/amd64` 和 `linux/arm64`。


安装脚本会自动生成缓存版本并刷新 Compose 模板，不需要手动添加 v 参数。

Docker Hub 安装：
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash

镜像代理安装：
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash
