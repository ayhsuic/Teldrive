# rclone
rclone serve webdav teldrive: --config "/telcloud/rclone.conf" --addr :8000 --user admin --pass password --cache-dir=/telcloud --vfs-cache-mode=full --vfs-cache-max-age=72h --vfs-cache-max-size=1024M --dir-cache-time=5m --vfs-read-chunk-size=4M --vfs-read-chunk-streams=16 --teldrive-threaded-streams=1
# env
TELDRIVE_ACCESS_TOKEN= \
DB_DATA_SOURCE= \
JWT_ALLOWED_USERS= \
JWT_SECRET= \
TG_UPLOADS_ENCRYPTION_KEY= \
DB_PREPARE_STMT=false \
DB_POOL_ENABLE=false \
TG_STREAM_MULTI_THREADS=6 \
TG_STREAM_STREAM_BUFFERS=20
# port
8080 \
8000 \
8888
# volume
/telcloud
