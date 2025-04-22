#!/bin/bash

# FOR BACKEND TARBALL FLOW
LOG_FILE="/home/acepino/git/rabbitmqphp_example/it490/forward_tar.log"

####BACKEND CODE

# Define directories
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
SENT_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"

# QA target details
QA_USER="qavm"
QA_IP="172.28.234.188"
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
newest_file=$(find "$SENT_DIR" -type f -name '*.tar.gz' -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2-)

if [ -n "$newest_file" ]; then
    echo "Newest file: $newest_file" | tee -a "$LOG_FILE"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sending newest file $newest_file to QA VM..." | tee -a "$LOG_FILE"
    
    scp -v -o StrictHostKeyChecking=no -i /home/acepino/.ssh/id_rsa "$newest_file" ${QA_USER}@${QA_IP}:/home/${QA_USER}/received_backups/
    
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Transfer successful: $newest_file" | tee -a "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Transfer failed for $newest_file" | tee -a "$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No .tar.gz files found in $SENT_DIR to send." | tee -a "$LOG_FILE"
fi

####FRONTEND CODE FLOW

# Define directories
INCOMING_DIR_FRONTEND="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar_frontend"
SENT_DIR_FRONTEND="/home/acepino/git/rabbitmqphp_example/it490/sent_tar_frontend"

# QA target details
QA_USER_FRONTEND="dfc27vm"
QA_IP_FRONTEND="172.28.24.103"
#PROD_USER="produser"
#PROD_IP="10.0.0.102"

# Ensure SENT_DIR_FRONTEND exists
mkdir -p "$SENT_DIR_FRONTEND"

# Step 1: Move all new tar files to sent_tar
for file in "$INCOMING_DIR_FRONTEND"/*.tar.gz; do
    [ -e "$file" ] || continue  # Skip if no files
    echo "Moving $file to $SENT_DIR_FRONTEND..."
    mv "$file" "$SENT_DIR_FRONTEND"
done

# Step 2: Send the newest file in sent_tar to QA VM
newest_file_frontend=$(find "$SENT_DIR_FRONTEND" -type f -name '*.tar.gz' -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2-)

if [ -n "$newest_file_frontend" ]; then
    echo "Newest file: $newest_file_frontend" | tee -a "$LOG_FILE"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Sending newest file $newest_file_frontend to QA VM..." | tee -a "$LOG_FILE"
    
    scp -v -o StrictHostKeyChecking=no -i /home/acepino/.ssh/id_rsa "$newest_file_frontend" ${QA_USER_FRONTEND}@${QA_IP_FRONTEND}:/var/www/html
    
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Transfer successful: $newest_file_frontend" | tee -a "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Transfer failed for $newest_file_frontend" | tee -a "$LOG_FILE"
    fi
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No .tar.gz files found in $SENT_DIR_FRONTEND to send." | tee -a "$LOG_FILE"
fi
 
 
