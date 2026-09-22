#!/usr/bin/env bash
set -euo pipefail

# HiMediaX 菜单式安装：主程序、Controller 可分开安装，也可一键全量安装。
INSTALL_DIR="$(pwd -P)"
cd "$INSTALL_DIR"

command -v docker >/dev/null 2>&1 || { echo "需要先安装 Docker。" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "需要 Docker Compose v2。" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "需要 openssl。" >&2; exit 1; }

prompt() {
  local label="$1" default="${2:-}" value
  read -r -p "$label [$default]: " value
  printf "%s" "${value:-$default}"
}
secret_or_generate() {
  local label="$1" value
  read -r -s -p "$label（留空自动生成）: " value
  echo
  printf "%s" "${value:-$(openssl rand -hex 32)}"
}

echo "HiMediaX 安装目录：$INSTALL_DIR"
echo
echo "请选择安装模式："
echo "  1) 只安装 HiMediaX 主程序"
echo "  2) 只安装 HiMediaX Controller"
echo "  3) 一键安装主程序 + Controller"
read -r -p "输入选项 [3]: " mode
mode="${mode:-3}"
case "$mode" in 1|2|3) ;; *) echo "无效选项。" >&2; exit 1 ;; esac

umask 077
if [ "$mode" = 1 ] || [ "$mode" = 3 ]; then
  data_dir=$(prompt "数据目录" "$INSTALL_DIR/data")
  library_dir=$(prompt "媒体库目录" "$INSTALL_DIR/library")
  http_port=$(prompt "管理端口" "18080")
  webdav_port=$(prompt "WebDAV 端口" "18081")
  proxy_port=$(prompt "播放代理端口" "18096")
  jwt_secret=$(secret_or_generate "JWT 密钥")
  mkdir -p "$data_dir" "$library_dir"
  {
    echo "HIMEDIAX_DATA_DIR_HOST=$data_dir"
    echo "HIMEDIAX_LIBRARY_DIR_HOST=$library_dir"
    echo "HIMEDIAX_HTTP_PORT=$http_port"
    echo "HIMEDIAX_WEBDAV_PORT=$webdav_port"
    echo "HIMEDIAX_PROXY_PORT=$proxy_port"
    echo "HIMEDIAX_JWT_SECRET=$jwt_secret"
  } >> "$INSTALL_DIR/.env"
fi

if [ "$mode" = 2 ] || [ "$mode" = 3 ]; then
  xiaoya_data=$(prompt "小雅数据目录" "$INSTALL_DIR/xiaoya-data")
  config_dir=$(prompt "HiMediaX 配置目录" "$INSTALL_DIR/config")
  controller_dir=$(prompt "Controller 工作目录" "$INSTALL_DIR/controller")
  controller_port=$(prompt "Controller 端口" "19090")
  controller_token=$(secret_or_generate "Controller Token")
  mkdir -p "$xiaoya_data" "$config_dir" "$controller_dir"
  {
    echo "HIMEDIAX_XIAOYA_DATA_DIR=$xiaoya_data"
    echo "HIMEDIAX_XIAOYA_CONFIG_DIR_HOST=$config_dir"
    echo "HIMEDIAX_CONTROLLER_DIR=$controller_dir"
    echo "HIMEDIAX_CONTROLLER_PORT=$controller_port"
    echo "HIMEDIAX_CONTROLLER_TOKEN=$controller_token"
  } >> "$INSTALL_DIR/.env"
fi

case "$mode" in
  1) compose_file="$INSTALL_DIR/docker-compose.yml" ;;
  2) compose_file="$INSTALL_DIR/compose.controller.yaml" ;;
  3) compose_file="$INSTALL_DIR/compose.full.yaml" ;;
esac

docker compose --env-file "$INSTALL_DIR/.env" -f "$compose_file" pull
docker compose --env-file "$INSTALL_DIR/.env" -f "$compose_file" up -d
docker compose --env-file "$INSTALL_DIR/.env" -f "$compose_file" ps
echo "安装完成。配置文件：$INSTALL_DIR/.env"
