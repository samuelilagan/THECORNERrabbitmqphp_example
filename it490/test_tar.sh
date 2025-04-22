#!/bin/bash



QA_VM="172.28.234.188"
QA_USER="qavm"
MYSQL_USER="nagios"
MYSQL_PASS="nagios"
MYSQL_DB="nagios_info"
MYSQL_HOST="localhost"
TAR_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"
TARBALL=$(ls -t "$TAR_DIR"/*.tar.gz | head -1)
TARNAME=$(basename "$TARBALL")

set -o errexit
set -o nounset
#set -o pipefail  # Optional while debugging




LOG_FILE="/home/acepino/git/rabbitmqphp_example/it490/test_tar.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "====== $(date '+%Y-%m-%d %H:%M:%S') ======"


# === Get most recent tarball ===
TARBALL=$(ls -t "$TAR_DIR"/*.tar.gz | head -1)
TARNAME=$(basename "$TARBALL")

echo "Checking deployment of $TARNAME on QA VM: $QA_USER@$QA_VM..."

# === Service checks ===

# RabbitMQ check
RABBIT_OUT=$(ssh "$QA_USER@$QA_VM" "sudo /usr/lib/nagios/plugins/check_nrpe -H 127.0.0.1 -c check_rabbitmq_aliveness" 2>&1 || true)
echo "RabbitMQ output: $RABBIT_OUT"
RABBIT_STATUS="FAIL"
if echo "$RABBIT_OUT" | grep -q "OK"; then
  RABBIT_STATUS="PASS"
fi

# MySQL check
MYSQL_OUT=$(ssh "$QA_USER@$QA_VM" "sudo /usr/lib/nagios/plugins/check_nrpe -H 127.0.0.1 -c check_mysql" 2>&1 || true)
echo "MySQL output: $MYSQL_OUT"
MYSQL_STATUS="FAIL"
if echo "$MYSQL_OUT" | grep -q "OK"; then
  MYSQL_STATUS="PASS"
fi

# === Determine overall status ===
if [[ "$RABBIT_STATUS" == "PASS" && "$MYSQL_STATUS" == "PASS" ]]; then
  OVERALL="PASS"
  echo -e "\e[32mPASS: All services healthy\e[0m"
else
  OVERALL="FAIL"
  echo -e "\e[31mFAIL: One or more services failed\e[0m"
fi

# === Insert into MySQL ===
echo "Logging deployment result to MySQL..."

ESCAPED_NAGIOS_STATUS=$(printf "RabbitMQ: %s, MySQL: %s" "$RABBIT_STATUS" "$MYSQL_STATUS" | sed "s/'/\\'/g")

mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" <<EOF
INSERT INTO tar_status (tar_name, monitor_time, overall_status, nagios_status)
VALUES ('$TARNAME', NOW(), '$OVERALL', '$ESCAPED_NAGIOS_STATUS');
EOF

# === Trigger rollback if needed ===
echo "OVERALL status is: $OVERALL"
if [[ "$OVERALL" == "FAIL" ]]; then
  echo "Triggering rollback..."
  bash /home/acepino/git/rabbitmqphp_example/it490/rollback_tar.sh >> /home/acepino/git/rabbitmqphp_example/it490/test_tar.log 2>&1
  echo "Rollback script finished running"
  exit 1
else
  exit 0
fi


