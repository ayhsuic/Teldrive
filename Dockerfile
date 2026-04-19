FROM ghcr.io/tgdrive/rclone AS rclone
FROM ghcr.io/tgdrive/teldrive AS teldrive
FROM darthsim/imgproxy:latest

USER root

RUN apt-get update \
    && apt-get install -y \
    nginx \
    supervisor \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=rclone \
    /usr/local/bin/rclone \
    /usr/local/bin/rclone
COPY --from=teldrive \
    /teldrive \
    /usr/local/bin/teldrive

WORKDIR /app

RUN mkdir -p \
    /app/config \
    /var/lib/nginx \
    /var/log/nginx \
    /var/log/supervisor \
    && chmod -R 777 \
    /app \
    /var/lib/nginx \
    /var/log/nginx \
    /var/log/supervisor \
    /etc/nginx \
    /etc/supervisor \
    /tmp

ENV RCLONE_CONFIG_TELDRIVE_TYPE=teldrive \
    RCLONE_CONFIG_TELDRIVE_CHUNK_SIZE=100M \
    RCLONE_CONFIG_TELDRIVE_UPLOAD_CONCURRENCY=8 \
    RCLONE_CONFIG_TELDRIVE_ENCRYPT_FILES=false \
    RCLONE_CONFIG_TELDRIVE_RANDOM_CHUNK_NAME=false \
    RCLONE_CONFIG_TELDRIVE_API_HOST="http://127.0.0.1:8080" \
    RCLONE_CONFIG_TELDRIVE_ACCESS_TOKEN="" \
    USER="admin" \
    PASS="password" \
    DB_DATA_SOURCE="" \
    JWT_ALLOWED_USERS="" \
    JWT_SECRET="" \
    TG_UPLOADS_ENCRYPTION_KEY="" \
    IMGPROXY_BIND=127.0.0.1:8082 \
    IMGPROXY_ALLOW_ORIGIN="*" \
    IMGPROXY_ENFORCE_WEBP=true \
    IMGPROXY_MALLOC="jemalloc" \
    IMGPROXY_KEY="" \
    IMGPROXY_SALT=""

RUN cat << 'EOF' > /etc/nginx/nginx.conf
pid /tmp/nginx.pid;
events {
    worker_connections 1024;
}
http {
    client_max_body_size 2000M;
    server {
        listen 7860;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
        
        location /dav {
            rewrite ^/dav/?(.*)$ /$1 break;
            proxy_pass http://127.0.0.1:8081;
        }
        location /img {
            rewrite ^/img/?(.*)$ /$1 break;
            proxy_pass http://127.0.0.1:8082;
        }
        location / {
            proxy_pass http://127.0.0.1:8080;
        }
    }
}
EOF

RUN cat << 'EOF' > /app/entrypoint.sh
#!/bin/sh
cat << SUP_EOF > /app/config/services.conf
[supervisord]
nodaemon=true
logfile=/app/logs/supervisord.log
pidfile=/tmp/supervisord.pid

[program:teldrive]
command=/usr/local/bin/teldrive run --db-data-source="%(ENV_DB_DATA_SOURCE)s" --db-prepare-stmt=false --jwt-allowed-users="%(ENV_JWT_ALLOWED_USERS)s" --jwt-secret="%(ENV_JWT_SECRET)s" --tg-uploads-encryption-key="%(ENV_TG_UPLOADS_ENCRYPTION_KEY)s" --server-port=8080
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:imgproxy]
command=imgproxy
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP_EOF

if [ -n "$RCLONE_CONFIG_TELDRIVE_ACCESS_TOKEN" ]; then
    cat << SUP_EOF >> /app/config/services.conf
[program:rclone]
command=/usr/local/bin/rclone serve webdav teldrive: --addr :8081 --user "%(ENV_USER)s" --pass "%(ENV_PASS)s" --cache-dir /tmp --vfs-cache-mode full
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP_EOF
fi
exec /usr/bin/supervisord -c /app/config/services.conf
EOF

RUN chmod +x /app/entrypoint.sh
USER 1000
EXPOSE 7860
ENTRYPOINT ["/app/entrypoint.sh"]