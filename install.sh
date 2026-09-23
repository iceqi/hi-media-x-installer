#!/usr/bin/env bash

set -euo pipefail

# HiMediaX 公开安装入口：安装资产始终从公开仓库下载，不依赖私有源码。
script_dir="$(pwd -P)"
raw_base="https://raw.githubusercontent.com/iceqi/hi-media-x-installer/main"
env_tmp=""
service_host=""
xiaoya_container=""
xiaoya_dir=""
xiaoya_webdav_port=""
himediax_url=""

fail() {
  echo "错误：$*" >&2
  exit 1
}

prompt() {
  local label="$1"
  local default_value="${2:-}"
  local value
  if [[ -n "${default_value}" ]]; then
    read_prompt "${label} [${default_value}]: "
    value="${REPLY}"
    printf '%s' "${value:-${default_value}}"
    return
  fi
  read_prompt "${label}: "
  printf '%s' "${REPLY}"
}

# 管道执行脚本时，标准输入被 curl 消耗；有交互终端时必须从 /dev/tty 读取用户回答。
read_prompt() {
  local message="$1"
  if [[ -r /dev/tty ]]; then
    read -r -p "${message}" REPLY </dev/tty
  else
    read -r -p "${message}" REPLY
  fi
}

confirm() {
  local message="$1"
  [[ "${HIMEDIAX_ASSUME_YES:-0}" == "1" ]] && return 0
  read_prompt "${message} [y/N]: "
  [[ "${REPLY}" =~ ^[Yy]$ ]]
}

valid_ipv4() {
  local address="$1"
  local part
  local -a parts
  IFS='.' read -r -a parts <<<"${address}"
  [[ ${#parts[@]} -eq 4 ]] || return 1
  for part in "${parts[@]}"; do
    [[ "${part}" =~ ^[0-9]{1,3}$ ]] || return 1
    ((10#${part} <= 255)) || return 1
  done
  ((10#${parts[0]} != 0 && 10#${parts[0]} != 127 && 10#${parts[0]} < 224))
}

valid_port() {
  [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535))
}

valid_http_url() {
  [[ "$1" =~ ^https?://[^[:space:]/]+(:[0-9]+)?/?$ ]]
}

valid_xiaoya_dir() {
  local directory="$1"
  [[ "${directory}" = /* && -d "${directory}" ]] || return 1
  [[ -f "${directory}/mytoken.txt" || -f "${directory}/myopentoken.txt" || \
    -f "${directory}/temp_transfer_folder_id.txt" || -d "${directory}/data" ]]
}

require_safe_env_value() {
  [[ "$2" != *$'\n'* && "$2" != *$'\r'* && "$2" != *"'"* ]] || fail "$1 包含不支持的字符"
}

write_env() {
  local key="$1"
  local value="$2"
  require_safe_env_value "${key}" "${value}"
  printf "%s='%s'\n" "${key}" "${value}" >>"${env_tmp}"
}

random_hex_32() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 32
    return
  fi
  od -An -N32 -tx1 /dev/urandom | tr -d ' \n'
}

download_assets() {
  local cache_version
  local file
  local temporary
  cache_version="$(date +%s)"
  for file in docker-compose.yml compose.controller.yaml compose.guessit.yaml xiaoya.yml; do
    temporary="$(mktemp "${script_dir}/.${file}.XXXXXX")"
    if ! curl -fsSL "${raw_base}/${file}?v=${cache_version}" -o "${temporary}"; then
      rm -f "${temporary}"
      fail "下载安装模板 ${file} 失败"
    fi
    chmod 0644 "${temporary}"
    mv -f "${temporary}" "${script_dir}/${file}"
  done
}

resolve_image_registry() {
  local registry="${HIMEDIAX_MIRROR:-${HIMEDIAX_IMAGE_REGISTRY:-docker.io}}"
  registry="${registry%/}"
  registry="${registry#https://}"
  registry="${registry#http://}"
  [[ -n "${registry}" ]] || fail "镜像代理地址不能为空"
  HIMEDIAX_IMAGE_REGISTRY="${registry}"
  export HIMEDIAX_IMAGE_REGISTRY
}

default_service_ipv4() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}'
}

resolve_service_host() {
  local detected
  detected="$(default_service_ipv4)"
  while true; do
    service_host="${HIMEDIAX_SERVICE_HOST:-$(prompt "HiMediaX 可访问的当前服务器 IPv4" "${detected}")}"
    valid_ipv4 "${service_host}" && return
    [[ -n "${HIMEDIAX_SERVICE_HOST:-}" ]] && fail "当前服务器 IPv4 无效"
    echo "请输入非回环且可供 HiMediaX 访问的 IPv4 地址。" >&2
    detected=""
  done
}

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_running() {
  [[ "$(docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]
}

wait_container_running() {
  local container="$1"
  local attempt=0
  while ((attempt < 30)); do
    container_running "${container}" && return 0
    sleep 2
    attempt=$((attempt + 1))
  done
  return 1
}

container_host_port() {
  local container="$1"
  local container_port="$2"
  local port
  port="$(docker inspect --format "{{with index .NetworkSettings.Ports \"${container_port}/tcp\"}}{{range .}}{{.HostPort}}{{println}}{{end}}{{end}}" "${container}" 2>/dev/null | sed -n '1p')"
  if [[ -z "${port}" ]]; then
    port="$(docker inspect --format "{{with index .HostConfig.PortBindings \"${container_port}/tcp\"}}{{range .}}{{.HostPort}}{{println}}{{end}}{{end}}" "${container}" 2>/dev/null | sed -n '1p')"
  fi
  printf '%s' "${port}"
}

container_mount_source() {
  local container="$1"
  local destination="$2"
  docker inspect --format "{{range .Mounts}}{{if eq .Destination \"${destination}\"}}{{.Source}}{{println}}{{end}}{{end}}" "${container}" 2>/dev/null | sed -n '1p'
}

wait_http_service() {
  local url="$1"
  local attempt=0
  local code
  while ((attempt < 60)); do
    code="$(curl --connect-timeout 2 --max-time 5 -sS -o /dev/null -w '%{http_code}' "${url}" 2>/dev/null || true)"
    [[ "${code}" != "000" && -n "${code}" ]] && return 0
    sleep 2
    attempt=$((attempt + 1))
  done
  return 1
}

verify_himediax_url() {
  local url="${1%/}"
  valid_http_url "${url}" || return 1
  curl --connect-timeout 3 --max-time 8 -fsS "${url}/api/health/live" | grep -q '"alive"' || return 1
  curl --connect-timeout 3 --max-time 8 -fsS "${url}/api/health/ready" | grep -q '"ready"' || return 1
}

wait_himediax_ready() {
  local url="$1"
  local attempt=0
  while ((attempt < 60)); do
    verify_himediax_url "${url}" && return 0
    sleep 2
    attempt=$((attempt + 1))
  done
  return 1
}

install_xiaoya() {
  local compose_file="${script_dir}/xiaoya.yml"
  local default_install_dir="${script_dir}/xiaoya"
  # 用户在 xiaoya 目录内执行脚本时直接复用当前目录，避免重复拼接 xiaoya。
  [[ "$(basename "${script_dir}")" == "xiaoya" ]] && default_install_dir="${script_dir}"
  local install_dir="${HIMEDIAX_XIAOYA_INSTALL_DIR:-${default_install_dir}}"
  local env_file="${install_dir}/xiaoya.env"
  local alist_port
  local alist_tls_port

  [[ -f "${compose_file}" ]] || fail "未找到小雅 Compose 文件"
  xiaoya_container="${HIMEDIAX_XIAOYA_CONTAINER:-$(prompt "小雅容器名称" "xiaoya-alist")}"
  if container_exists "${xiaoya_container}"; then
    fail "容器 ${xiaoya_container} 已存在；如需复用已有小雅，请选择只安装小雅控制器"
  fi
  xiaoya_dir="${HIMEDIAX_XIAOYA_DATA_DIR:-$(prompt "小雅程序/数据根目录" "${install_dir}")}"
  xiaoya_webdav_port="${HIMEDIAX_XIAOYA_WEBDAV_PORT:-$(prompt "小雅 WebDAV 端口" "5678")}"
  alist_port="${HIMEDIAX_XIAOYA_ALIST_PORT:-$(prompt "小雅管理端口" "2345")}"
  alist_tls_port="${HIMEDIAX_XIAOYA_ALIST_TLS_PORT:-$(prompt "小雅管理 TLS 端口" "2346")}"

  [[ "${install_dir}" = /* && "${xiaoya_dir}" = /* ]] || fail "小雅安装和数据目录必须是绝对路径"
  if ! valid_port "${xiaoya_webdav_port}" || ! valid_port "${alist_port}" || ! valid_port "${alist_tls_port}"; then
    fail "小雅端口无效"
  fi

  echo
  echo "即将安装小雅："
  echo "  容器：${xiaoya_container}"
  echo "  数据目录：${xiaoya_dir}"
  echo "  WebDAV 端口：${xiaoya_webdav_port}"
  confirm "确认继续？" || fail "已取消"

  mkdir -p "${install_dir}" "${xiaoya_dir}"
  chmod 0700 "${install_dir}"
  env_tmp="$(mktemp "${install_dir}/.xiaoya.env.XXXXXX")"
  trap 'rm -f "${env_tmp}"' EXIT
  chmod 0600 "${env_tmp}"
  write_env HIMEDIAX_XIAOYA_CONTAINER "${xiaoya_container}"
  write_env HIMEDIAX_XIAOYA_DATA_DIR "${xiaoya_dir}"
  write_env HIMEDIAX_XIAOYA_WEB_PORT "${xiaoya_webdav_port}"
  write_env HIMEDIAX_XIAOYA_ALIST_PORT "${alist_port}"
  write_env HIMEDIAX_XIAOYA_ALIST_TLS_PORT "${alist_tls_port}"
  mv -f "${env_tmp}" "${env_file}"
  chmod 0600 "${env_file}"
  trap - EXIT

  docker compose --env-file "${env_file}" -f "${compose_file}" pull
  docker compose --env-file "${env_file}" -f "${compose_file}" up -d
  # 小雅在尚未配置阿里云盘 Token 时可能反复重启；先完成容器部署，交由
  # Controller 写入配置后再恢复服务，不能因为临时 WebDAV 探测失败中断安装。
  if wait_container_running "${xiaoya_container}"; then
    xiaoya_dir="$(container_mount_source "${xiaoya_container}" "/data")"
    xiaoya_webdav_port="$(container_host_port "${xiaoya_container}" "80")"
    if valid_port "${xiaoya_webdav_port}" && ! wait_http_service "http://127.0.0.1:${xiaoya_webdav_port}"; then
      echo "警告：小雅 WebDAV 尚未就绪，完成 Token 配置后会自动恢复。" >&2
    fi
  else
    echo "警告：小雅容器当前未保持运行，可能需要先通过 Controller 配置 Token。" >&2
  fi
  echo "小雅容器部署完成：${xiaoya_container}"
}

select_existing_xiaoya() {
  local -a candidates
  local index
  local choice
  local default_dir
  local default_port

  mapfile -t candidates < <(
    docker ps -a --format '{{.Names}}|{{.Image}}|{{.State}}' | awk -F'|' '
      BEGIN { IGNORECASE = 1 }
      $1 == "xiaoya-alist" { preferred = $0; next }
      $1 ~ /xiaoya/ || $2 ~ /xiaoya/ { others = others $0 ORS }
      END {
        if (preferred != "") print preferred
        printf "%s", others
      }
    '
  )
  [[ ${#candidates[@]} -gt 0 ]] || fail "未检测到已安装的小雅，无法安装小雅控制器"

  echo "已检测到小雅容器："
  for index in "${!candidates[@]}"; do
    IFS='|' read -r candidate_name candidate_image candidate_state <<<"${candidates[$index]}"
    printf '  %d) %s  %s  %s\n' "$((index + 1))" "${candidate_name}" "${candidate_image}" "${candidate_state}"
  done
  choice="${HIMEDIAX_XIAOYA_CHOICE:-$(prompt "选择小雅容器" "1")}"
  if [[ ! "${choice}" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#candidates[@]})); then
    fail "小雅容器选项无效"
  fi
  xiaoya_container="${candidates[$((choice - 1))]%%|*}"

  if ! container_running "${xiaoya_container}"; then
    echo "小雅容器当前已停止，正在启动以完成安装验证。"
    docker start "${xiaoya_container}" >/dev/null
    wait_container_running "${xiaoya_container}" || fail "小雅容器启动失败"
  fi

  default_dir="$(container_mount_source "${xiaoya_container}" "/data")"
  while true; do
    xiaoya_dir="${HIMEDIAX_XIAOYA_DATA_DIR:-$(prompt "小雅程序/数据目录" "${default_dir}")}"
    valid_xiaoya_dir "${xiaoya_dir}" && break
    [[ -n "${HIMEDIAX_XIAOYA_DATA_DIR:-}" ]] && fail "小雅程序/数据目录无效"
    echo "该目录不存在，或未找到小雅配置/数据特征，请重新输入。" >&2
    default_dir=""
  done

  default_port="$(container_host_port "${xiaoya_container}" "80")"
  while true; do
    xiaoya_webdav_port="${HIMEDIAX_XIAOYA_WEBDAV_PORT:-$(prompt "小雅 WebDAV 宿主机端口" "${default_port}")}"
    valid_port "${xiaoya_webdav_port}" && break
    [[ -n "${HIMEDIAX_XIAOYA_WEBDAV_PORT:-}" ]] && fail "小雅 WebDAV 端口无效"
    echo "请先确认小雅容器已发布 80/tcp，然后输入实际宿主机端口。" >&2
    default_port=""
  done
  wait_http_service "http://127.0.0.1:${xiaoya_webdav_port}" || fail "小雅 WebDAV 服务不可用，不能继续安装小雅控制器"
}

install_himediax() {
  local public_host="${1:-}"
  local compose_file="${script_dir}/docker-compose.yml"
  local install_dir="${HIMEDIAX_INSTALL_DIR:-${script_dir}}"
  local data_dir="${HIMEDIAX_DATA_DIR_HOST:-$(prompt "HiMediaX 数据目录" "${install_dir}/data")}"
  local library_dir="${HIMEDIAX_LIBRARY_DIR_HOST:-$(prompt "HiMediaX 媒体库目录" "${install_dir}/library")}"
  local http_port="${HIMEDIAX_HTTP_PORT:-$(prompt "HiMediaX 管理端口" "18080")}"
  local webdav_port="${HIMEDIAX_WEBDAV_PORT:-$(prompt "HiMediaX WebDAV 端口" "18081")}"
  local proxy_port="${HIMEDIAX_PROXY_PORT:-$(prompt "HiMediaX 播放反代端口" "18096")}"
  local env_file="${install_dir}/himediax.env"
  local jwt_secret=""

  [[ "${install_dir}" = /* && "${data_dir}" = /* && "${library_dir}" = /* ]] || fail "HiMediaX 安装和数据目录必须是绝对路径"
  if ! valid_port "${http_port}" || ! valid_port "${webdav_port}" || ! valid_port "${proxy_port}"; then
    fail "HiMediaX 端口无效"
  fi
  [[ -f "${compose_file}" ]] || fail "未找到 HiMediaX Compose 文件"

  echo
  echo "即将安装 HiMediaX："
  echo "  数据目录：${data_dir}"
  echo "  媒体库目录：${library_dir}"
  echo "  管理端口：${http_port}"
  confirm "确认继续？" || fail "已取消"

  mkdir -p "${install_dir}" "${data_dir}" "${library_dir}"
  chmod 0700 "${install_dir}" "${data_dir}"
  chmod 0755 "${library_dir}"
  if [[ -f "${env_file}" ]]; then
    jwt_secret="$(sed -n "s/^HIMEDIAX_JWT_SECRET='\([0-9a-fA-F]*\)'$/\1/p" "${env_file}" | head -n 1)"
  fi
  [[ -n "${jwt_secret}" ]] || jwt_secret="$(random_hex_32)"

  env_tmp="$(mktemp "${install_dir}/.himediax.env.XXXXXX")"
  trap 'rm -f "${env_tmp}"' EXIT
  chmod 0600 "${env_tmp}"
  write_env HIMEDIAX_DATA_DIR_HOST "${data_dir}"
  write_env HIMEDIAX_LIBRARY_DIR_HOST "${library_dir}"
  write_env HIMEDIAX_HTTP_PORT "${http_port}"
  write_env HIMEDIAX_WEBDAV_PORT "${webdav_port}"
  write_env HIMEDIAX_PROXY_PORT "${proxy_port}"
  write_env HIMEDIAX_JWT_SECRET "${jwt_secret}"
  write_env HIMEDIAX_IMAGE_REGISTRY "${HIMEDIAX_IMAGE_REGISTRY:-docker.io}"
  mv -f "${env_tmp}" "${env_file}"
  chmod 0600 "${env_file}"
  trap - EXIT

  docker compose --env-file "${env_file}" -f "${compose_file}" pull
  docker compose --env-file "${env_file}" -f "${compose_file}" up -d
  wait_himediax_ready "http://127.0.0.1:${http_port}" || fail "HiMediaX 健康检查失败"
  if [[ -n "${public_host}" ]]; then
    himediax_url="http://${public_host}:${http_port}"
    verify_himediax_url "${himediax_url}" || fail "小雅控制器无法通过 ${himediax_url} 访问 HiMediaX"
  else
    himediax_url="http://127.0.0.1:${http_port}"
  fi
  echo "HiMediaX 安装成功：${himediax_url}"
}

detect_local_himediax() {
  local -a candidates
  local entry
  local container
  local port
  local candidate_url

  mapfile -t candidates < <(
    docker ps -a --format '{{.Names}}|{{.Image}}' | awk -F'|' '
      BEGIN { IGNORECASE = 1 }
      ($1 == "hi-media-x" || $1 ~ /hi-media-x/) && $1 !~ /controller|guessit/ { print }
    '
  )
  for entry in "${candidates[@]}"; do
    container="${entry%%|*}"
    container_running "${container}" || continue
    port="$(container_host_port "${container}" "8080")"
    valid_port "${port}" || continue
    candidate_url="http://${service_host}:${port}"
    if verify_himediax_url "${candidate_url}"; then
      himediax_url="${candidate_url}"
      echo "已检测到本机 HiMediaX："
      echo "  容器：${container}"
      echo "  服务地址：${himediax_url}"
      echo "  运行状态：正常"
      return 0
    fi
  done
  return 1
}

resolve_himediax_url() {
  local entered
  detect_local_himediax && return
  echo "本机未检测到可用的 HiMediaX。"
  while true; do
    entered="${HIMEDIAX_APP_URL:-$(prompt "请输入 HiMediaX 服务地址（例如 http://192.168.1.10:18080）")}"
    entered="${entered%/}"
    if verify_himediax_url "${entered}"; then
      himediax_url="${entered}"
      echo "HiMediaX 连接验证成功：${himediax_url}"
      return
    fi
    [[ -n "${HIMEDIAX_APP_URL:-}" ]] && fail "HiMediaX 服务地址不可用"
    echo "该地址未通过 HiMediaX 存活和就绪检查，请重新输入。" >&2
  done
}

install_controller() {
  local compose_file="${script_dir}/compose.controller.yaml"
  local install_dir="${HIMEDIAX_CONTROLLER_INSTALL_DIR:-${script_dir}/controller}"
  local env_file="${install_dir}/controller.env"
  local controller_port
  local controller_url
  local controller_token=""

  [[ -n "${xiaoya_container}" && -n "${xiaoya_dir}" && -n "${xiaoya_webdav_port}" ]] || fail "小雅尚未通过安装验证"
  if [[ -z "${himediax_url}" ]] || ! verify_himediax_url "${himediax_url}"; then
    fail "HiMediaX 服务尚未通过验证"
  fi
  [[ -f "${compose_file}" ]] || fail "未找到小雅控制器 Compose 文件"
  controller_port="${HIMEDIAX_CONTROLLER_PORT:-$(prompt "小雅控制器端口" "19090")}"
  valid_port "${controller_port}" || fail "小雅控制器端口无效"
  controller_url="http://${service_host}:${controller_port}"
  [[ "${install_dir}" = /* ]] || fail "小雅控制器配置目录必须是绝对路径"

  echo
  echo "即将安装小雅控制器："
  echo "  小雅容器：${xiaoya_container}"
  echo "  小雅目录：${xiaoya_dir}"
  echo "  小雅 WebDAV：${service_host}:${xiaoya_webdav_port}"
  echo "  小雅控制器：${controller_url}"
  echo "  HiMediaX：${himediax_url}"
  confirm "确认继续？" || fail "已取消"

  mkdir -p "${install_dir}"
  chmod 0700 "${install_dir}"
  if [[ -f "${env_file}" ]]; then
    controller_token="$(sed -n "s/^HIMEDIAX_CONTROLLER_TOKEN='\([0-9a-fA-F]*\)'$/\1/p" "${env_file}" | head -n 1)"
  fi
  [[ -n "${controller_token}" ]] || controller_token="$(random_hex_32)"

  env_tmp="$(mktemp "${install_dir}/.controller.env.XXXXXX")"
  trap 'rm -f "${env_tmp}"' EXIT
  chmod 0600 "${env_tmp}"
  write_env HIMEDIAX_CONTROLLER_TOKEN "${controller_token}"
  write_env HIMEDIAX_XIAOYA_DATA_DIR "${xiaoya_dir}"
  write_env HIMEDIAX_XIAOYA_CONTAINER "${xiaoya_container}"
  write_env HIMEDIAX_XIAOYA_SERVICE_PORTS "80"
  write_env HIMEDIAX_XIAOYA_WEBDAV_PORT "${xiaoya_webdav_port}"
  write_env HIMEDIAX_SERVICE_HOST "${service_host}"
  write_env HIMEDIAX_CONTROLLER_PORT "${controller_port}"
  write_env HIMEDIAX_CONTROLLER_PUBLIC_URL "${controller_url}"
  write_env HIMEDIAX_APP_URL "${himediax_url}"
  write_env HIMEDIAX_IMAGE_REGISTRY "${HIMEDIAX_IMAGE_REGISTRY:-docker.io}"
  mv -f "${env_tmp}" "${env_file}"
  chmod 0600 "${env_file}"
  trap - EXIT

  docker compose --env-file "${env_file}" -f "${compose_file}" pull
  docker compose --env-file "${env_file}" -f "${compose_file}" up -d
  wait_container_running "${HIMEDIAX_CONTROLLER_CONTAINER_NAME:-hi-media-x-controller}" || fail "小雅控制器未能正常启动"
  echo "小雅控制器已启动，并将自动向 HiMediaX 注册。"
  echo "配置文件：${env_file}（权限 0600）"
}

show_menu() {
  echo "请选择安装方式："
  echo
  echo "  1) 全新安装：小雅 + HiMediaX + 小雅控制器"
  echo "  2) 只安装 HiMediaX"
  echo "  3) 安装小雅 + 小雅控制器"
  echo "  4) 只安装小雅控制器"
  echo "  5) 只安装小雅"
  echo
}

main() {
  local choice
  (($# == 0)) || fail "安装脚本不接受参数，请直接运行 ./install.sh"
  command -v docker >/dev/null 2>&1 || fail "未安装 Docker"
  command -v curl >/dev/null 2>&1 || fail "未安装 curl"
  docker info >/dev/null 2>&1 || fail "Docker 不可用，请检查服务状态和当前用户权限"
  docker compose version >/dev/null 2>&1 || fail "未安装 Docker Compose 插件"
  resolve_image_registry
  download_assets

  show_menu
  choice="$(prompt "请输入选项" "1")"
  case "${choice}" in
    1)
      install_xiaoya
      resolve_service_host
      install_himediax "${service_host}"
      install_controller
      ;;
    2)
      install_himediax
      ;;
    3)
      install_xiaoya
      resolve_service_host
      resolve_himediax_url
      install_controller
      ;;
    4)
      select_existing_xiaoya
      resolve_service_host
      resolve_himediax_url
      install_controller
      ;;
    5)
      install_xiaoya
      ;;
    *)
      fail "安装选项无效"
      ;;
  esac
}

if [[ -z "${BASH_SOURCE[0]:-}" || "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  main "$@"
fi
