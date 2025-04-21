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

echo "Checking deployment of $TARNAME on QA VM..."

# Run checks and capture stdout/stderr safely
RABBIT_OUT=$(ssh -t $QA_USER@$QA_VM "sudo /usr/lib/nagios/plugins/check_nrpe -H localhost -c check_rabbitmq_aliveness" 2>&1 | tr '\n' ' ' | sed "s/'/\\\'/g")
RABBIT_STATUS=$?

MYSQL_OUT=$(ssh -t $QA_USER@$QA_VM "sudo /usr/lib/nagios/plugins/check_nrpe -H localhost -c check_mysql" 2>&1 | tr '\n' ' ' | sed "s/'/\\\'/g")
MYSQL_STATUS=$?

if [[ $RABBIT_STATUS -eq 0 && $MYSQL_STATUS -eq 0 ]]; then
    OVERALL="PASS"
    echo "PASS: All services healthy"
else
    OVERALL="FAIL"
    echo "FAIL: One or more services failed"
fi

# Insert clean result into MySQL
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" <<EOF
INSERT INTO tar_status (tar_name, monitor_time, overall_status, nagios_status)
VALUES (
    '$TARNAME',
    NOW(),
    '$OVERALL',
    'RabbitMQ: $RABBIT_OUT | MySQL: $MYSQL_OUT',
  
);
EOF

# Trigger rollback if needed
if [[ "$OVERALL" == "FAIL" ]]; then
    /home/acepino/git/rabbitmqphp_example/it490/rollback_tar.sh
    exit 1
else
    exit 0
fi
