#!/bin/bash

# Build image
docker build -t mysql-backup-s3 .

# Deploy backup
mkdir -p backup
chmod -R 777 backup

docker stack deploy --compose-file docker-compose.yaml --detach=false mariadb