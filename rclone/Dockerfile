FROM ghcr.io/tgdrive/rclone AS rclone
FROM debian
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

ENV RCLONE_CONFIG_TELDRIVE_TYPE=teldrive
ENV RCLONE_CONFIG_TELDRIVE_CHUNK_SIZE=500M
ENV RCLONE_CONFIG_TELDRIVE_UPLOAD_CONCURRENCY=4
ENV RCLONE_CONFIG_TELDRIVE_ENCRYPT_FILES=false
ENV RCLONE_CONFIG_TELDRIVE_RANDOM_CHUNK_NAME=false

ENV RCLONE_CONFIG_TELDRIVE_API_HOST="http://localhost:8080"
ENV RCLONE_CONFIG_TELDRIVE_ACCESS_TOKEN=""
ENV USER="admin"
ENV PASS="password"

ENTRYPOINT /usr/local/bin/rclone serve webdav teldrive: \
    --addr :7860 \
    --user "${USER}" \
    --pass "${PASS}" \
    --cache-dir /cache \
    --vfs-cache-mode full