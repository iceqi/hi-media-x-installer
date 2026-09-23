# HiMediaX 安装器

本仓库是 HiMediaX 的公开安装入口，只包含安装脚本、Docker Compose 模板和用户文档，不包含主程序源码。

## 一键安装

建议在专用目录中执行：

```bash
sudo mkdir -p /srv/himediax
cd /srv/himediax
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh | sudo bash
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

## 可选 GuessIt

```bash
docker compose -f compose.guessit.yaml pull
docker compose -f compose.guessit.yaml up -d
```

默认镜像为 `iceqi/hi-media-x-guessit:latest`。

## 镜像代理

设置 `HIMEDIAX_IMAGE_REGISTRY` 可以替换 Compose 使用的镜像注册表，例如：

```bash
curl -fsSL https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main/install.sh \
  | sudo env HIMEDIAX_MIRROR=https://gh-proxy.org bash
```

也可以设置 `HIMEDIAX_IMAGE_REGISTRY=gh-proxy.org`。脚本会自动去掉 `http://` 或 `https://` 前缀。

## 安全说明

- 不要提交安装生成的 `*.env`、JWT 密钥或 Controller Token。
- 安装目录和环境文件分别限制为 `0700` 和 `0600`。
- Controller 需要挂载 Docker Socket，只应部署在可信主机。
- HiMediaX 主程序与 Controller 可以分开部署；Controller 不参与主程序 readiness。
