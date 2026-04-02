#!/bin/bash
set -e

# 生成 teldrive 配置文件
echo "正在生成 Teldrive 配置文件: /telcloud/config.toml"
echo "[db]
data-source = \"${DB_DATA_SOURCE}\"
prepare-stmt = ${DB_PREPARE_STMT}

[db.pool]
enable = ${DB_POOL_ENABLE}

[jwt]
allowed-users = [\"${JWT_ALLOWED_USERS}\"]
secret = \"${JWT_SECRET}\"

[tg.uploads]
encryption-key = \"${TG_UPLOADS_ENCRYPTION_KEY}\"

[tg.stream]
multi-threads = ${TG_STREAM_MULTI_THREADS}
stream-buffers = ${TG_STREAM_STREAM_BUFFERS}" > "/telcloud/config.toml"

# 生成 Rclone 配置文件
echo "正在生成 Rclone 配置文件: /telcloud/rclone.conf"
echo "[teldrive]
type = teldrive
api_host = http://localhost:8080
access_token = ${TELDRIVE_ACCESS_TOKEN}
chunk_size = "500M"
upload_concurrency = 4
encrypt_files = false
random_chunk_name = false" > "/telcloud/rclone.conf"

# 启动 teldrive
echo "Starting teldrive..."
/teldrive run --config /telcloud/config.toml &

# 等待 teldrive 启动后再启动 rclone
echo "Waiting for Teldrive to be ready..."
sleep 5

# 启动 rclone
echo "Starting rclone..."
exec /usr/local/bin/rclone serve webdav teldrive: \
--config "/telcloud/rclone.conf" \
--addr :8000 \
--user admin \
--pass ${PASS:-password} \
--cache-dir=/telcloud \
--vfs-cache-mode full \
--vfs-cache-max-age 72h \
--vfs-cache-max-size 5G \
--vfs-read-chunk-size 32M \
--vfs-read-chunk-streams 4 \
--dir-cache-time 24h \
--teldrive-threaded-streams=1
