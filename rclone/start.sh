#!/bin/sh
set -e

# --- 检查必须的环境变量 ---
if [ -z "${TELDRIVE_ACCESS_TOKEN}" ] || [ -z "${WEBDAV_USER}" ] || [ -z "${WEBDAV_PASS}" ]; then
  echo "错误: 必须在 Zeabur 中设置环境变量 TELDRIVE_ACCESS_TOKEN, WEBDAV_USER, 和 WEBDAV_PASS."
  exit 1
fi

# --- 设置 Rclone 默认值 ---
RCLONE_CONFIG_PATH="/config/rclone.conf"
RCLONE_REMOTE_NAME="teldrive"
CACHE_DIR="/cache"

# --- 步骤 1: 自动生成 Rclone 配置文件 ---
echo "正在生成 Rclone 配置文件: ${RCLONE_CONFIG_PATH}"
# 确保配置文件所在的目录存在
mkdir -p "$(dirname "${RCLONE_CONFIG_PATH}")"

# 使用环境变量生成配置文件
echo "[${RCLONE_REMOTE_NAME}]
type = teldrive
api_host = https://caster.zeabur.app
access_token = ${TELDRIVE_ACCESS_TOKEN}
chunk_size = 500M
upload_concurrency = 4
encrypt_files = false
random_chunk_name = true" > "${RCLONE_CONFIG_PATH}"

# --- 步骤 2: 创建缓存目录 ---
echo "正在创建缓存目录 ${CACHE_DIR}"
mkdir -p "${CACHE_DIR}"

# --- 步骤 3: 启动 Rclone WebDAV 服务 ---
echo "正在启动 Rclone WebDAV 服务..."
# 使用 exec, 让 rclone 成为主进程
exec rclone serve webdav ${RCLONE_REMOTE_NAME}: \
    --config="${RCLONE_CONFIG_PATH}" \
    --addr :8080 \
    --user "${WEBDAV_USER}" \
    --pass "${WEBDAV_PASS}" \
    --vfs-cache-mode full \
    --vfs-cache-max-age 72h \
    --vfs-cache-max-size 1024M \
    --dir-cache-time 120h \
    --cache-dir "${CACHE_DIR}" \
    --vfs-read-chunk-size=32M \
    --vfs-read-chunk-streams=4 \
    --teldrive-threaded-streams=1
