#!/bin/bash

# Default cron schedule is every 4 hours
CRON_SCHEDULE="${CRON_SCHEDULE:-0 */4 * * *}"

# Write out the cron job to file
echo "$CRON_SCHEDULE /usr/local/bin/backup.sh >> /var/log/backup.log 2>&1" > /etc/crontabs/root

# Execute backup in entrypoint
cd /usr/local/bin
./backup.sh

# Start cron in foreground
crond -f -l 2
