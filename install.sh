#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR="$(pwd -P)"
cd "$INSTALL_DIR"
command -v docker >/dev/null 2>&1 || { echo "需要先安装 Docker。" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "需要 Docker Compose v2。" >&2; exit 1; }
prompt() {
  local label="$1" default="${2:-}" value
  read -r -p "$label [${default}]: " value
  printf "%s" "${value:-$default}"
}
echo "HiMediaX 安装目录：$INSTALL_DIR"
data_dir=$(prompt "数据目录" "$INSTALL_DIR/data")
library_dir=$(prompt "媒体库目录" "$INSTALL_DIR/library")
xiaoya_data=$(prompt "小雅数据目录" "$INSTALL_DIR/xiaoya-data")
config_dir=$(prompt "配置目录" "$INSTALL_DIR/config")
controller_dir=$(prompt "Controller 工作目录" "$INSTALL_DIR/controller")
http_port=$(prompt "管理端口" "18080")
webdav_port=$(prompt "WebDAV 端口" "18081")
proxy_port=$(prompt "播放代理端口" "18096")
controller_port=$(prompt "Controller 端口" "19090")
read -r -s -p "JWT 密钥（留空自动生成）: " jwt_secret; echo
read -r -s -p "Controller Token（留空自动生成）: " controller_token; echo
command -v openssl >/dev/null 2>&1 || { echo "需要 openssl。" >&2; exit 1; }
jwt_secret="${jwt_secret:-$(openssl rand -hex 32)}"
controller_token="${controller_token:-$(openssl rand -hex 32)}"
mkdir -p "$data_dir" "$library_dir" "$xiaoya_data" "$config_dir" "$controller_dir"
umask 077
cat > "$INSTALL_DIR/.env" <<EOF
HIMEDIAX_DATA_DIR_HOST=$data_dir
HIMEDIAX_LIBRARY_DIR_HOST=$library_dir
HIMEDIAX_XIAOYA_DATA_DIR=$xiaoya_data
HIMEDIAX_XIAOYA_CONFIG_DIR_HOST=$config_dir
HIMEDIAX_CONTROLLER_DIR=$controller_dir
HIMEDIAX_HTTP_PORT=$http_port
HIMEDIAX_WEBDAV_PORT=$webdav_port
HIMEDIAX_PROXY_PORT=$proxy_port
HIMEDIAX_CONTROLLER_PORT=$controller_port
HIMEDIAX_JWT_SECRET=$jwt_secret
HIMEDIAX_CONTROLLER_TOKEN=$controller_token
EOF
docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.full.yaml" pull
docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.full.yaml" up -d
docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/compose.full.yaml" ps
echo "安装完成：管理地址 http://<服务器IP>:$http_port"
