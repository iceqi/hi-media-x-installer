# HiMediaX

HiMediaX 是文件系统驱动的媒体本地化服务。扫描器直接生成可播放的 STRM，刮削结果直接写入 NFO 和图片，媒体视图使用可重建的相对软连接，不依赖业务数据库。

## 快速开始

1. 复制 `config.example.yaml` 并按环境设置 `HIMEDIAX_*` 变量。
2. 设置 `HIMEDIAX_DATA_DIR_HOST` 和 `HIMEDIAX_LIBRARY_DIR_HOST` 后执行 `docker compose up --build`；管理端默认发布在宿主机 `18080`，扫描产物直接写入 `HIMEDIAX_LIBRARY_DIR_HOST`。
3. 首次访问 `http://主机:18080/login` 创建管理员，随后配置小雅 WebDAV 与本地播放服务地址。

健康端点为 `/api/health/live` 和 `/api/health/ready`。登录后可通过 `/xiaoya` 配置服务，通过 `/media/xiaoya` 浏览和扫描；WebDAV 默认只读监听 `8081`。

Docker 构建默认通过 `proxy.151513.xyz` 拉取基础镜像，并使用 `https://goproxy.cn` 下载 Go 模块。需要切换时可在执行 Compose 前设置 `DOCKER_REGISTRY` 和 `GOPROXY`。

## 小雅 Controller

Controller 是部署在小雅所在宿主机上的独立服务，不由 Supervisor 或 HiMediaX 主程序托管。它需要同时挂载小雅安装目录和 Docker Socket：

```bash
HIMEDIAX_CONTROLLER_TOKEN='change-me' \
HIMEDIAX_XIAOYA_DATA_DIR=/srv/xiaoya-data \
HIMEDIAX_XIAOYA_CONFIG_DIR_HOST=/srv/hi-media-x/config \
HIMEDIAX_CONTROLLER_DIR=/srv/hi-media-x/controller \
docker compose -f compose.controller.yaml up --build -d
```

Controller 默认监听宿主机 `19090`，目标容器为 `xiaoya-alist`。它提供小雅容器状态、启动/停止/重启、日志、Token、允许的配置文件、凭据、二维码登录和转存目录接口；所有 `/v1/xiaoya/*` 请求都必须携带 `X-HiMediaX-Controller-Token`。

小雅独立服务部署文件为 `xiaoya.yml`。它固定使用容器内部 `80` 端口作为 WebDAV 服务，默认映射宿主机 `5678`，并保留 `2345`、`2346` 管理端口。部署时设置 `HIMEDIAX_XIAOYA_DATA_DIR`，不会自动删除或初始化已有小雅数据。

小雅 WebDAV 默认凭据为用户名 `guest`、密码 `guest_Api789`；HiMediaX 仅在本地 JSON 中保存密码，管理页面始终只显示“已配置”状态。

Controller compose 支持 `HIMEDIAX_APP_URL`，默认回调同一 Docker 网络内的 `http://hi-media-x:8080`；同时通过 `HIMEDIAX_ADVERTISED_ADDRESSES` 指定宿主机可访问的主网络地址，例如 `http://192.168.1.242:5678`。Controller 启动后会自动回调 HiMediaX 注册接口，HiMediaX 再把该地址写入小雅 WebDAV 配置。

挂载层级必须保持分离：`HIMEDIAX_XIAOYA_DATA_DIR` 是小雅实际数据目录，映射到容器 `/xiaoya`；`HIMEDIAX_XIAOYA_CONFIG_DIR_HOST` 是安装器的配置目录，映射到 `/etc/himedia/config`；`HIMEDIAX_CONTROLLER_DIR` 是 Controller 专用目录，映射到 `/controller`。不要把包含这三个目录的安装根目录整体映射到 `/xiaoya`。
