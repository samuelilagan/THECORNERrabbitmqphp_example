#!/bin/bash

MYSQL_USER="nagios"
MYSQL_PASS="nagios"
MYSQL_DB="nagios_info"
MYSQL_HOST="localhost"

TAR_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"
DEPLOY_SCRIPT="/home/acepino/git/rabbitmqphp_example/it490/deploy_tar.sh"  # path to your deploy script

# Get the latest FAILED tarball name
FAILED_TAR=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -sN -e \
"SELECT tar_name FROM tar_status WHERE overall_status='FAIL' ORDER BY deploy_time DESC LIMIT 1;" "$MYSQL_DB")

# Get the latest PASSED tarball name
PASSED_TAR=$(mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" -sN -e \
"SELECT tar_name FROM tar_status WHERE overall_status='PASS' ORDER BY deploy_time DESC LIMIT 1;" "$MYSQL_DB")

# Check both values exist
if [[ -z "$FAILED_TAR" || -z "$PASSED_TAR" ]]; then
  echo "ERROR: Could not find both FAILED and PASSED tarballs for rollback."
  exit 1
fi

echo "Rolling back: replacing $FAILED_TAR with $PASSED_TAR"

# Overwrite the failed tarball with the latest working one
cp "$TAR_DIR/$PASSED_TAR" "$TAR_DIR/$FAILED_TAR"

echo "Rollback file copied. Triggering redeploy of $FAILED_TAR..."

# Trigger redeploy script — pass the tarball name if needed
bash "$DEPLOY_SCRIPT" "$FAILED_TAR"

if [[ $? -eq 0 ]]; then
  echo "Redeploy successful."
else
  echo "Redeploy script failed. Manual intervention may be required."
  exit 2
fi
