#!/bin/bash

# Set variables
DATE=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/tmp/backup/mysql"
BACKUP_FILE="$BACKUP_DIR/all_db_backup_$DATE.sql.gz"
BINLOG_BACKUP_FILE="$BACKUP_DIR/binlog_backup_$DATE.tar.gz"
ENDPOINT_URL="https://s3.${AWS_DEFAULT_REGION}.backblazeb2.com"  # Backblaze region

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Perform MySQL dump for all databases, including routines and events
mysqldump -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD --all-databases --routines --events | gzip > $BACKUP_FILE

# Backup binary logs
mysqlbinlog --read-from-remote-server --raw --stop-never mysql-bin.* > $BINLOG_BACKUP_FILE

# Upload MySQL dump and binary logs to Backblaze S3-Compatible bucket
aws s3 cp $BACKUP_FILE $S3_BUCKET/ --endpoint-url $ENDPOINT_URL
aws s3 cp $BINLOG_BACKUP_FILE $S3_BUCKET/ --endpoint-url $ENDPOINT_URL

# Remove local backup files
rm -f $BACKUP_FILE
rm -f $BINLOG_BACKUP_FILE

# Delete old backups in Backblaze S3-Compatible bucket older than 5 days
aws s3 ls $S3_BUCKET/ --endpoint-url $ENDPOINT_URL | while read -r line; do
    file_date=$(echo $line | awk '{print $1" "$2}')
    file_name=$(echo $line | awk '{print $4}')
    
    # Parse file date and current date to seconds
    file_timestamp=$(date -d "$file_date" +%s)
    current_timestamp=$(date +%s)

    # Calculate age of file in seconds and convert to days
    age=$(( (current_timestamp - file_timestamp) / 86400 ))

    # Delete file if older than xx days
    if [ $age -gt $DELETE_OLDER_THAN_DAY ]; then
        echo "Deleting $file_name from S3 (Age: $age days)"
        aws s3 rm "$S3_BUCKET/$file_name" --endpoint-url $ENDPOINT_URL
    fi
done
