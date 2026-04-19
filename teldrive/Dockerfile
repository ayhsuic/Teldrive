FROM ghcr.io/tgdrive/teldrive AS teldrive
FROM debian

RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=teldrive /teldrive /teldrive

ENTRYPOINT /teldrive run \
    --db-data-source="${DB_DATA_SOURCE}" \
    --db-prepare-stmt=false \
    --jwt-allowed-users="${JWT_ALLOWED_USERS}" \
    --jwt-secret="${JWT_SECRET}" \
    --tg-uploads-encryption-key="${TG_UPLOADS_ENCRYPTION_KEY}" \
    --server-port=7860