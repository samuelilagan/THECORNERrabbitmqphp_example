#!/bin/bash
LOG_FILE="/home/acepino/git/rabbitmqphp_example/it490/forward_tar.log"

# Define directories
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
SENT_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"

# QA target details
QA_USER="sam"
QA_IP="172.28.166.145"
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

# Step 2: Send the newest file in sent_tar to QA VM
newest_file=$(ls -t "$SENT_DIR"/*.tar.gz 2>/dev/null | head -n 1)

if [ -n "$newest_file" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sending newest file $newest_file to QA VM..." | tee -a "$LOG_FILE"
    
    scp -i /home/acepino/.ssh/id_rsa "$newest_file" ${QA_USER}@${QA_IP}:/home/${QA_USER}/received_backups/
    
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Transfer successful: $newest_file" | tee -a "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Transfer failed for $newest_file" | tee -a "$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No .tar.gz files found in $SENT_DIR to send." | tee -a "$LOG_FILE"
fi


