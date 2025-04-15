#!/bin/bash

# Define directories
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
SENT_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"

# QA target details
QA_USER="acepino"
QA_IP="172.28.178.248"
#PROD_USER="produser"
#PROD_IP="10.0.0.102"

# Ensure SENT_DIR exists
mkdir -p "$SENT_DIR"

# Step 1: Move all new tar files to sent_tar
for file in "$INCOMING_DIR"/*.tar.gz; do
    [ -e "$file" ] || continue  # Skip if no files
    echo "Moving $file to $SENT_DIR..."
    mv "$file" "$SENT_DIR"
done

# Step 2: Send all files in sent_tar to QA VM # and PROD VM
for file in "$SENT_DIR"/*.tar.gz; do
    [ -e "$file" ] || continue  # Skip if no files
    echo "Sending $file to QA VM..."
    scp -i /home/acepino/.ssh/id_rsa "$file" ${QA_USER}@${QA_IP}:/home/${QA_USER}/received_backups/
# scp "$file" ${PROD_USER}@${PROD_IP}:/home/${PROD_USER}/received_backups/

done
