FROM ghcr.io/tgdrive/teldrive AS teldrive
FROM ghcr.io/tgdrive/rclone AS rclone

FROM debian

COPY --from=teldrive /teldrive /teldrive
COPY --from=rclone /usr/local/bin/rclone /usr/local/bin/rclone

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]