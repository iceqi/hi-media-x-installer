#!/usr/bin/env bash
set -euo pipefail
if [ -t 1 ]; then C_RESET="\033[0m"; C_CYAN="\033[36m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BOLD="\033[1m"; else C_RESET=""; C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_BOLD=""; fi
INSTALL_DIR="$(pwd -P)"
cd "$INSTALL_DIR"
command -v docker >/dev/null 2>&1 || { echo "需要先安装 Docker。" >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "需要 Docker Compose v2。" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "需要 openssl。" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "需要 curl。" >&2; exit 1; }
RAW_BASE="https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main"
for file in compose.full.yaml docker-compose.yml compose.controller.yaml xiaoya.yml; do
  if [ ! -f "$INSTALL_DIR/$file" ]; then
    curl -fsSL "$RAW_BASE/$file" -o "$INSTALL_DIR/$file"
  fi
done
prompt() {
  local label="$1" default="${2:-}" value
  read -r -p "$label [$default]: " SECRET_VALUE </dev/tty
  printf "%s" "${value:-$default}"
}
read_secret() {
  local label="$1"
  printf "%s" "$label（留空自动生成）: " >/dev/tty
  IFS= read -r -s SECRET_VALUE </dev/tty
  printf "\n" >/dev/tty
  if [ -z "$SECRET_VALUE" ]; then SECRET_VALUE=$(openssl rand -hex 32); fi

}
printf "%b\n" "${C_GREEN}  1) 先安装小雅${C_RESET}"
printf "%b\n" "${C_GREEN}  2) 快速安装 HiMediaX + 小雅控制器${C_RESET}"
printf "%b\n" "${C_GREEN}  3) 只安装 HiMediaX${C_RESET}"
printf "%b\n" "${C_GREEN}  4) 只安装小雅控制器${C_RESET}"
read -r -p "输入选项 [1]: " choice </dev/tty
choice="${choice:-1}"
case "$choice" in 1) mode=4 ;; 2) mode=3 ;; 3) mode=1 ;; 4) mode=2 ;; *) echo "无效选项。" >&2; exit 1 ;; esac
if [ "$choice" = 1 ]; then
  xiaoya_dir=$(prompt "小雅安装目录" "$INSTALL_DIR/xiaoya")
  xiaoya_web_port=$(prompt "小雅 WebDAV 端口" "5678")
  xiaoya_alist_port=$(prompt "小雅管理端口" "2345")
  mkdir -p "$xiaoya_dir"
  { echo "HIMEDIAX_XIAOYA_DATA_DIR=$xiaoya_dir"; echo "HIMEDIAX_XIAOYA_WEB_PORT=$xiaoya_web_port"; echo "HIMEDIAX_XIAOYA_ALIST_PORT=$xiaoya_alist_port"; } >> "$INSTALL_DIR/.env"
  docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/xiaoya.yml" pull
  docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/xiaoya.yml" up -d
  docker compose --env-file "$INSTALL_DIR/.env" -f "$INSTALL_DIR/xiaoya.yml" ps
  echo "小雅安装完成，请再次运行脚本安装 HiMediaX。"
  exit 0
fi
umask 077
: > "$INSTALL_DIR/.env"
if [ "$mode" = 1 ] || [ "$mode" = 3 ]; then
  data_dir=$(prompt "数据目录" "$INSTALL_DIR/data")
  library_dir=$(prompt "媒体库目录" "$INSTALL_DIR/library")
  http_port=$(prompt "管理端口" "18080")
  webdav_port=$(prompt "WebDAV 端口" "18081")
  proxy_port=$(prompt "播放代理端口" "18096")
  read_secret "JWT 密钥"; jwt_secret="$SECRET_VALUE"
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
  xiaoya_data=$(prompt "小雅安装目录" "$INSTALL_DIR/xiaoya-data")
  config_dir=$(prompt "HiMediaX 配置目录" "$INSTALL_DIR/config")
  controller_port=$(prompt "小雅控制器端口" "19090")
  controller_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || true)
  controller_ip="${controller_ip:-127.0.0.1}"
  if [ "$mode" = 2 ]; then
    hmx_url=$(prompt "HiMediaX 服务地址" "http://127.0.0.1:18080")
    read -r -s -p "已有的小雅控制器 Token: " controller_token </dev/tty
    echo
    [ -n "$controller_token" ] || { echo "单独安装控制器必须提供已有 Token。" >&2; exit 1; }
  else
    hmx_url="http://hi-media-x:8080"
    read_secret "小雅控制器 Token"; controller_token="$SECRET_VALUE"
  fi
  [ -d "$xiaoya_data" ] || { echo "小雅安装目录不存在，请先完成小雅服务安装后再运行此选项。" >&2; exit 1; }
  mkdir -p "$config_dir"
  {
    echo "HIMEDIAX_XIAOYA_DATA_DIR=$xiaoya_data"
    echo "HIMEDIAX_XIAOYA_CONFIG_DIR_HOST=$config_dir"
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
