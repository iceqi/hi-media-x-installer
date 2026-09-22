#!/usr/bin/env bash
set -euo pipefail
clear 2>/dev/null || true
if [ -e /dev/tty ]; then exec </dev/tty; fi
if [ -t 1 ]; then C_RESET="\033[0m"; C_CYAN="\033[36m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BOLD="\033[1m"; else C_RESET=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; fi
INSTALL_DIR="$(pwd -P)"
cd "$INSTALL_DIR"
command -v docker >/dev/null 2>&1 || { echo "需要先安装 Docker。" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "需要 Docker Compose v2。" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "需要 openssl。" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "需要 curl。" >&2; exit 1; }
RAW_BASE="https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main"
for file in compose.full.yaml docker-compose.yml compose.controller.yaml; do
  if [ ! -f "$INSTALL_DIR/$file" ]; then
    curl -fsSL "$RAW_BASE/$file" -o "$INSTALL_DIR/$file"
  fi
done
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
printf "%b\n" "${C_CYAN}${C_BOLD}=== HiMediaX 安装向导 ===${C_RESET}"
printf "%b\n" "${C_GREEN}  1) 快速安装 HiMediaX + 小雅控制器${C_RESET}"
printf "%b\n" "${C_GREEN}  2) 只安装 HiMediaX${C_RESET}"
printf "%b\n" "${C_GREEN}  3) 只安装小雅控制器${C_RESET}"
read -r -p "输入选项 [1]: " choice
choice="${choice:-1}"
case "$choice" in 1) mode=3 ;; 2) mode=1 ;; 3) mode=2 ;; *) echo "无效选项。" >&2; exit 1 ;; esac
umask 077
: > "$INSTALL_DIR/.env"
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
  controller_dir=$(prompt "小雅控制器工作目录" "$INSTALL_DIR/controller")
  controller_port=$(prompt "小雅控制器端口" "19090")
  controller_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  controller_ip="${controller_ip:-127.0.0.1}"
  if [ "$mode" = 2 ]; then
    hmx_url=$(prompt "HiMediaX 服务地址" "http://127.0.0.1:18080")
    read -r -s -p "已有的小雅控制器 Token: " controller_token
    echo
    [ -n "$controller_token" ] || { echo "单独安装控制器必须提供已有 Token。" >&2; exit 1; }
  else
    hmx_url="http://hi-media-x:8080"
    controller_token=$(secret_or_generate "小雅控制器 Token")
  fi
  mkdir -p "$xiaoya_data" "$config_dir" "$controller_dir"
  {
    echo "HIMEDIAX_XIAOYA_DATA_DIR=$xiaoya_data"
    echo "HIMEDIAX_XIAOYA_CONFIG_DIR_HOST=$config_dir"
    echo "HIMEDIAX_CONTROLLER_DIR=$controller_dir"
    echo "HIMEDIAX_CONTROLLER_PORT=$controller_port"
    echo "HIMEDIAX_CONTROLLER_TOKEN=$controller_token"
    echo "HIMEDIAX_APP_URL=$hmx_url"
    echo "HIMEDIAX_ADVERTISED_ADDRESSES=http://$controller_ip:$controller_port"
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
