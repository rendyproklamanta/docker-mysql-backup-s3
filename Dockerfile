FROM alpine:latest

# Install necessary packages
RUN apk update && \
    apk add mysql-client bash curl python3 py3-pip && \
    pip3 install awscli && \
    rm -rf /var/cache/apk/*

# Add the backup script and entrypoint
COPY backup.sh /usr/local/bin/backup.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/backup.sh /usr/local/bin/entrypoint.sh

# Run entrypoint script to set cron dynamically and start cron daemon
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]