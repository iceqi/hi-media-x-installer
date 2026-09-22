# HiMediaX 安装

用户只需要 Docker 和 Docker Compose，不需要安装 Go、Node.js 或 Python。

## 快速开始

```bash
git clone https://github.com/iceqi/hi-media-x-installer.git
cd hi-media-x-installer
cp config.example.yaml config.yaml
# 按需编辑 config.yaml 和 .env
docker compose pull
docker compose up -d
```

主程序镜像：`iceqi/hi-media-x:latest`。Controller 和 GuessIt 使用独立 Compose 文件按需启用。

## 更新

```bash
docker compose pull
docker compose up -d
```

## Self-hosted Runner

在 GitHub 仓库 Settings → Actions → Runners 中添加 Linux x64 runner，并给三 个私有源码仓库配置同名 runner 标签 `self-hosted`, `linux`, `x64`。工作流会自动构建并推送 Docker Hub 镜像。

