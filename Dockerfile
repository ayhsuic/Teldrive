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

COPY --from=teldrive /teldrive /usr/local/bin/teldrive
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

WORKDIR /app

RUN mkdir -p \
    /tmp \
    /cache \
    /etc/nginx \
    /app/config \
    /var/lib/nginx \
    /var/log/nginx \
    /var/log/supervisor \
    && chmod -R 777 \
    /tmp \
    /app \
    /cache\
    /var/log \
    /etc/nginx \
    /var/lib/nginx

ENV USER="admin" \
    PASS="password" \
    JWT_SECRET="" \
    DB_DATA_SOURCE="" \
    JWT_ALLOWED_USERS="" \
    TG_UPLOADS_ENCRYPTION_KEY="" \
    IMGPROXY_KEY="" \
    IMGPROXY_SALT="" \
    IMGPROXY_ALLOW_ORIGIN="*" \
    IMGPROXY_MALLOC="jemalloc" \
    IMGPROXY_ENFORCE_WEBP=true \
    IMGPROXY_PATH_PREFIX="/img" \
    IMGPROXY_BIND=127.0.0.1:8082 \
    RCLONE_CONFIG_TELDRIVE_TYPE=teldrive \
    RCLONE_CONFIG_TELDRIVE_ACCESS_TOKEN="" \
    RCLONE_CONFIG_TELDRIVE_CHUNK_SIZE=100M \
    RCLONE_CONFIG_TELDRIVE_ENCRYPT_FILES=false \
    RCLONE_CONFIG_TELDRIVE_UPLOAD_CONCURRENCY=8 \
    RCLONE_CONFIG_TELDRIVE_RANDOM_CHUNK_NAME=false \
    RCLONE_CONFIG_TELDRIVE_API_HOST="http://127.0.0.1:8080"

RUN cat << 'EOF' > /etc/nginx/nginx.conf
pid /tmp/nginx.pid;
events {}
http {
    include /etc/nginx/mime.types;
    client_max_body_size 2000M;
    map $http_upgrade $connection_upgrade {
        default upgrade;
        '' close;
    }

    server {
        listen 7860;
        port_in_redirect off;
        absolute_redirect off;
        proxy_http_version 1.1;
        
        proxy_set_header Host $host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Scheme https;
        proxy_cookie_path / "/; SameSite=None; Secure";
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;

        location = /dav {
            return 301 $scheme://$http_host/dav/;
        }

        location /dav/ {
            proxy_pass http://127.0.0.1:8081;
            proxy_set_header X-Forwarded-Prefix /dav;
            proxy_redirect / /dav/;
        }
        
        location = /img {
            return 301 $scheme://$http_host/img/;
        }
        
        location /img/ {
            proxy_pass http://127.0.0.1:8082;
            proxy_set_header X-Forwarded-Prefix /img;
            proxy_redirect / /img/;
        }
        
        location / {
            proxy_pass http://127.0.0.1:8080;
            proxy_redirect default;
        }
    }
}
EOF

RUN cat << 'EOF' > /app/entrypoint.sh
#!/bin/sh
cat << SUP_EOF > /app/config/services.conf
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
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
command=/usr/local/bin/rclone serve webdav teldrive: --addr :8081 --baseurl /dav --user "%(ENV_USER)s" --pass "%(ENV_PASS)s" --cache-dir /cache --vfs-cache-mode full
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
