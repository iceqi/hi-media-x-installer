# HiMediaX 安装器

本仓库是 HiMediaX 的公开安装入口，只包含安装脚本、Docker Compose 模板和用户文档，不包含主程序源码。HiMediaX 是基于本地文件系统的媒体库管理、扫描、刮削、播放服务和 TVBox 配置服务；业务数据不依赖 PostgreSQL、SQLite 等数据库。

## 一键安装

建议在专用目录中执行：

```bash
sudo mkdir -p /srv/himediax
cd /srv/himediax
curl -fsSL https://proxy.151513.xyz/raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
```

脚本会刷新本仓库中的 Compose 模板，然后显示五种安装方式：

```text
1) 全新安装：小雅 + HiMediaX + 小雅控制器
2) 只安装 HiMediaX
3) 安装小雅 + 小雅控制器
4) 只安装小雅控制器
5) 只安装小雅
```

脚本不接受命令行参数。可交互修改所有探测值；设置 `HIMEDIAX_ASSUME_YES=1` 时跳过确认提示。

## 安装行为

- 全新安装按“小雅 → HiMediaX → Controller”顺序执行。
- Controller 安装前必须检测到可用的小雅容器、`/data` 挂载、WebDAV 端口和 HiMediaX 健康端点。
- Controller Token 由安装器生成并保存在 `./controller/controller.env`，权限为 `0600`。
- Controller 启动后主动向 HiMediaX 注册；HiMediaX 通过随机挑战反向确认 Controller 和 WebDAV 地址。
- 重复安装会复用已经生成的 JWT 密钥和 Controller Token。
- GuessIt 是可选独立服务，不参与 HiMediaX readiness，也不在五项菜单中自动安装。
- 主程序默认同时暴露管理端口 `18080`、WebDAV 端口 `18081`、TVBox 端口 `18082` 和播放反代端口 `18096`；安装时可以修改这些端口。

默认安装目录就是执行脚本时的当前目录：

| 组件 | 默认目录 | 环境文件 |
| --- | --- | --- |
| HiMediaX | 当前目录 | `himediax.env` |
| Controller | 当前目录/controller | `controller.env` |
| 小雅 | 当前目录/xiaoya | `xiaoya.env` |

## 已有服务场景

选择“只安装小雅控制器”时，脚本会：

1. 枚举当前主机的小雅容器，优先选择 `xiaoya-alist`。
2. 校验容器挂载目录和实际发布的 WebDAV 端口。
3. 自动查找本机 HiMediaX；未找到时要求输入外部 HiMediaX 地址。
4. 要求确认当前主机可供 HiMediaX 访问的 IPv4 地址。
5. 生成 Controller Token、启动 Controller 并等待自动注册。

## 更新

重新运行一键安装脚本并选择对应组件即可。安装器会先拉取：

```text
iceqi/hi-media-x:latest
iceqi/hi-media-x-controller:latest
```

镜像同时支持 `linux/amd64` 和 `linux/arm64`。也可以在组件目录使用其环境文件和本仓库模板手动更新：

```bash
docker compose --env-file ./himediax.env -f docker-compose.yml pull
docker compose --env-file ./himediax.env -f docker-compose.yml up -d

docker compose --env-file ./controller/controller.env -f compose.controller.yaml pull
docker compose --env-file ./controller/controller.env -f compose.controller.yaml up -d
```

## 功能清单

### 媒体库与任务

- 通过小雅 WebDAV 扫描媒体目录，生成和更新本地化 STRM 文件。
- 扫描任务、任务投影和配置全部写入本地文件系统，支持断点状态和失败重试。
- 目录整理、媒体视图和相对软链接受路径逃逸保护，删除视图时不会跟随链接误删规范媒体库。
- 任务列表、定时任务、扫描进度和媒体目录浏览可在管理后台查看。

### 元数据与播放

- 使用 GuessIt 识别标题；GuessIt 为独立可选服务。
- 可配置 TMDB 元数据服务，刮削结果直接原子写入对应目录的 NFO 和图片。
- WebDAV 只读媒体访问、播放服务地址管理和 Emby 兼容反向代理。
- 支持多个播放服务地址，并可在扫描后替换 STRM 中的播放地址。

### 网盘与小雅控制器

- 小雅控制器独立部署，负责小雅生命周期、授权二维码、Token/Cookie 文件和转存配置。
- 支持阿里云盘普通授权、阿里云 Open 手动多行 Token、115 网盘扫码及阿里转 115 加速参数。
- 控制器不参与主程序 readiness，可单独更新和排查；Controller Token 只保存哈希或受限权限配置。

### TVBox 服务

- 管理后台可创建和撤销 TVBox 只读令牌，并限制令牌可访问的媒体目录范围。
- 生成可直接导入 TVBox 的远程配置地址；令牌明文只在创建完成时显示一次。
- 根据媒体库中的 STRM、NFO 和图片生成本地 TVBox 索引，支持手动重建。
- TVBox 播放请求通过配置的播放服务地址转发，不直接暴露宿主机媒体路径。
- 默认访问地址为 `http://服务器地址:18082/config?token=...`；修改 `HIMEDIAX_TVBOX_PORT` 后使用对应端口。

### 安全与运维

- 管理员账号只保存强密码哈希，账号文件权限不宽于 `0600`。
- 安装目录和环境文件采用受限权限；环境文件不应提交到 Git。
- 支持 `linux/amd64` 和 `linux/arm64` 镜像、健康检查、日志查看和镜像代理。

## 可选 GuessIt

```bash
docker compose -f compose.guessit.yaml pull
docker compose -f compose.guessit.yaml up -d
```

默认镜像为 `iceqi/hi-media-x-guessit:latest`。

## 镜像代理

设置 `HIMEDIAX_IMAGE_REGISTRY` 可以替换 Compose 使用的镜像注册表，例如：

```bash
curl -fsSL https://proxy.151513.xyz/raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh \
  | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash
```

也可以设置 `HIMEDIAX_IMAGE_REGISTRY=gh-proxy.org`。脚本会自动去掉 `http://` 或 `https://` 前缀。

## 安全说明

- 不要提交安装生成的 `*.env`、JWT 密钥或 Controller Token。
- 安装目录和环境文件分别限制为 `0700` 和 `0600`。
- Controller 需要挂载 Docker Socket，只应部署在可信主机。
- HiMediaX 主程序与 Controller 可以分开部署；Controller 不参与主程序 readiness。
