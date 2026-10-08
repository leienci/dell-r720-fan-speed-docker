FROM alpine:latest

RUN apk add --no-cache bash ipmitool

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENV RETRY_COUNT=10 \
    RETRY_INTERVAL=5

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
