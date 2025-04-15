#!/bin/bash
LOG_FILE="/home/acepino/git/rabbitmqphp_example/it490/forward_tar.log"
# Define directories
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
SENT_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"

# PROD target details
PROD_USER="deployprod"
PROD_IP="172.28.107.83"
#PROD_USER="produser"
#PROD_IP="10.0.0.102"

# Ensure SENT_DIR exists
mkdir -p "$SENT_DIR"

#  Send the newest file in sent_tar to PROD VM
newest_file=$(ls -t "$SENT_DIR"/*.tar.gz 2>/dev/null | head -n 1)

if [ -n "$newest_file" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sending newest file $newest_file to PROD VM..." | tee -a "$LOG_FILE"
    
    scp -i /home/acepino/.ssh/id_rsa "$newest_file" ${PROD_USER}@${PROD_IP}:/home/${PROD_USER}/received_backups/
    
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Transfer successful: $newest_file" | tee -a "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Transfer failed for $newest_file" | tee -a "$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No .tar.gz files found in $SENT_DIR to send." | tee -a "$LOG_FILE"
fi