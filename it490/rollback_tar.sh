#!/bin/bash
#
# rollback_tar.sh
# - Replaces the latest FAILED tarball with the latest PASSED one
# - Calls deploy_tar.sh
# - Logs rollback into tar_status table

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
MYSQL_USER="nagios"
MYSQL_PASS="nagios"
MYSQL_DB="nagios_info"
MYSQL_HOST="localhost"

QA_USER="qavm"
QA_VM="172.28.234.188"
TAR_DIR="/home/acepino/git/rabbitmqphp_example/it490/sent_tar"
DEPLOY_SCRIPT="/home/$QA_USER/deploy_vm.sh"

LOG_FILE="/home/acepino/git/rabbitmqphp_example/it490/rollback.log"
exec >>"$LOG_FILE" 2>&1

echo "====== Rollback triggered at $(date '+%Y-%m-%d %H:%M:%S') ======"

# ── Queries ───────────────────────────────────────────────────────────────────
FAILED_TAR=$(mysql -Nse "
 SELECT tar_name
   FROM tar_status
  WHERE overall_status='FAIL'
ORDER BY monitor_time DESC
  LIMIT 1;
" -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB")

PASSED_TAR=$(mysql -Nse "
 SELECT tar_name
   FROM tar_status
  WHERE overall_status='PASS'
ORDER BY monitor_time DESC
  LIMIT 1;
" -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB")

# ── Validation ────────────────────────────────────────────────────────────────
if [[ -z "$FAILED_TAR" || -z "$PASSED_TAR" ]]; then
  echo "ERROR: Could not find both FAIL and PASS tarballs. Aborting."
  exit 1
fi

echo "Latest FAIL tar:   $FAILED_TAR"
echo "Latest PASS tar:   $PASSED_TAR"



# ── File existence ─────────────────────────────────────────────────────────────
if [[ ! -f "$TAR_DIR/$PASSED_TAR" ]]; then
  echo "ERROR: Working tar not found at $TAR_DIR/$PASSED_TAR"
  exit 2
fi

# Backup the failed tar just in case
cp "$TAR_DIR/$FAILED_TAR" "$TAR_DIR/${FAILED_TAR}.bak.$(date +%s)" || true

# Overwrite failed with passed
cp -f "$TAR_DIR/$PASSED_TAR" "$TAR_DIR/$FAILED_TAR"

echo "Replaced $FAILED_TAR with contents of $PASSED_TAR"
echo "Using original filename: $FAILED_TAR (now contains the contents of $PASSED_TAR)"

# ── Redeploy ───────────────────────────────────────────────────────────────────
if ssh "$QA_USER@$QA_VM" "bash $DEPLOY_SCRIPT $PASSED_TAR"; then
  echo "Redeploy of $FAILED_TAR (contents of $PASSED_TAR) succeeded"
else
  echo "ERROR: Redeploy script failed for $FAILED_TAR"
  exit 3
fi

# ── Log rollback in DB ─────────────────────────────────────────────────────────
mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" <<EOF
INSERT INTO tar_status (tar_name, monitor_time, overall_status, nagios_status)
VALUES (
  '$FAILED_TAR',
  NOW(),
  'PASS',
  'rollback from $PASSED_TAR'
);
EOF

echo "Logged rollback event to tar_status table."
echo "====== Rollback complete at $(date '+%Y-%m-%d %H:%M:%S') ======"
