#!/bin/bash

DB_HOST=$(cat "$DB_HOST_FILE")
DB_PORT=$(cat "$DB_PORT_FILE")
DB_USER=$(cat "$DB_USER_FILE")
DB_PASS=$(cat "$DB_PASS_FILE")

# Set variables
DATE=$(date +%Y%m%d%H%M%S)
BACKUP_DIR="/tmp/backup/mysql"
ENCRYPTION_FILE="$BACKUP_DIR/encryption_$DATE.tar.gz"
BACKUP_FILE="$BACKUP_DIR/all_db_backup_$DATE.sql.gz"
BINLOG_BACKUP_FILE="$BACKUP_DIR/binlog_backup_$DATE.tar.gz"

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Create a compressed archive of the backup directory
tar -czf $ENCRYPTION_FILE -C $ENCRYPTION_SOURCE .

# SSL-related parameters
SSL_PARAMS=""
if [ "$ENABLE_SSL" = "true" ]; then
    SSL_PARAMS="--ssl --ssl-ca=/etc/my.cnf.d/tls/ca-cert.pem --ssl-cert=/etc/my.cnf.d/tls/client-cert.pem --ssl-key=/etc/my.cnf.d/tls/client-key.pem"
fi

# Perform MySQL dump for all databases, including routines and events
mysqldump -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASS --all-databases --routines --events $SSL_PARAMS | gzip > $BACKUP_FILE

# Backup binary logs
mysqlbinlog --read-from-remote-server --raw --stop-never mysql-bin.* > $BINLOG_BACKUP_FILE

# Upload MySQL dump and binary logs to Backblaze S3-Compatible bucket
aws s3 cp $BACKUP_FILE $S3_BUCKET/ --endpoint-url $ENDPOINT_URL
aws s3 cp $BINLOG_BACKUP_FILE $S3_BUCKET/ --endpoint-url $ENDPOINT_URL
aws s3 cp $ENCRYPTION_FILE $S3_BUCKET/ --endpoint-url $ENDPOINT_URL

# Remove local backup files
rm -f $BACKUP_FILE
rm -f $BINLOG_BACKUP_FILE
rm -f $ENCRYPTION_FILE

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
