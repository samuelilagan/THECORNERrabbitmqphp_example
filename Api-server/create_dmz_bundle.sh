#!/bin/bash
set -e

# ======================
# CONFIGURATION
# ======================
SOURCE_DIR="$HOME/git/rabbitmqphp_example/Api-server"
DEPLOY_SERVER="acepino@172.28.197.192"
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
OUTPUT_FILE="dmz_full_deployment_$(date +%Y%m%d_%H%M%S).tar.gz"
MYSQL_USER="testUser"
MYSQL_PASS="12345"
MYSQL_DB="users"

# Essential files to bundle
ESSENTIAL_FILES=(
"dmzMelRabbit.php"
"dmzRabbitMQ.ini"
".env"
"fetchReviews.js"
"get_host_info.inc"
"my-api-service.sh"
"path.inc"
"rabbitMQLib.inc"
"/etc/systemd/system/dmz-listener.service"
)

# ======================
# DEPLOYMENT PREP
# ======================
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR"

echo "=== Bundling DMZ API Server Files ==="
for file in "${ESSENTIAL_FILES[@]}"; do
  if [[ $file == /* ]]; then
      sudo cp -v "$file" "$TMP_DIR/" || {
          echo "⚠ Failed to copy system file: $file"
          exit 1
      }
  elif [ -f "$SOURCE_DIR/$file" ]; then
      cp -v "$SOURCE_DIR/$file" "$TMP_DIR/" || {
          echo "⚠ Failed to copy project file: $file"
          exit 1
      }
  else
      echo "⚠ Warning: Optional file '$file' not found (continuing)"
  fi
done

# ======================
# MYSQL DATABASE BACKUP
# ======================
echo "=== Backing Up MySQL Database ==="
sudo mysqldump -u $MYSQL_USER -p$MYSQL_PASS --hex-blob --triggers --routines --events \
   --complete-insert --add-drop-table $MYSQL_DB > "$TMP_DIR/dmz_mysql_backup.sql" || {
  echo "⚠ MySQL backup failed"
  exit 1
}

# ======================
# CREATE COMPLETE SETUP SCRIPT
# ======================
cat > "$TMP_DIR/setup_dmz.sh" << 'EOF'
#!/bin/bash
set -ex

# Improved logging setup
LOG_FILE="/tmp/dmz_full_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(sudo tee "$LOG_FILE") 2>&1
echo "=== Starting DMZ Full Setup $(date) ==="

# Install required packages
echo "=== Installing Dependencies ==="
sudo apt-get update && sudo apt-get install -y \
   php php-amqp php-mysql \
   nodejs npm \
   rabbitmq-server mysql-server \
   wget || { echo "Package install failed"; exit 1; }

# Configure MySQL
echo "=== Configuring MySQL ==="
sudo mysql << 'MYSQL_SCRIPT'
CREATE DATABASE IF NOT EXISTS users;
CREATE USER IF NOT EXISTS 'testUser'@'localhost' IDENTIFIED BY '12345';
GRANT ALL PRIVILEGES ON users.* TO 'testUser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Restore database
echo "=== Restoring Database ==="
sudo mysql -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB < "$PWD/dmz_mysql_backup.sql" || {
   echo "⚠ MySQL restore failed"
   exit 1
}

# Verify table structure
echo "=== Verifying Table Structure ==="
sudo mysql -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "
DESCRIBE reviews;
SELECT COUNT(*) FROM reviews;
" || {
   echo "⚠ Table verification failed"
   exit 1
}

# Configure RabbitMQ
echo "=== Configuring RabbitMQ ==="
{
   sudo rabbitmqctl delete_user test 2>/dev/null || true
   sudo rabbitmqctl delete_vhost testHost 2>/dev/null || true
   sudo rabbitmqctl add_vhost testHost || { echo "Failed to create vhost"; exit 1; }
   sudo rabbitmqctl add_user test test || { echo "Failed to create user"; exit 1; }
   sudo rabbitmqctl set_user_tags test administrator || { echo "Failed to set admin tag"; exit 1; }
   sudo rabbitmqctl set_permissions -p testHost test ".*" ".*" ".*" || { echo "Failed to set permissions"; exit 1; }
   sudo rabbitmq-plugins enable rabbitmq_management
   sudo systemctl restart rabbitmq-server
}

# Install Node.js dependencies
echo "=== Installing Node.js Dependencies ==="
npm install || { echo "npm install failed"; exit 1; }

# Configure systemd service
echo "=== Configuring DMZ Listener Service ==="
if [ -f "dmz-listener.service" ]; then
   sudo cp dmz-listener.service /etc/systemd/system/ || { echo "Failed to copy service file"; exit 1; }
   sudo systemctl daemon-reload
   sudo systemctl enable dmz-listener.service
   sudo systemctl start dmz-listener.service || {
      echo "⚠ Service start failed - checking logs"
      journalctl -u dmz-listener.service -n 50 --no-pager
      exit 1
   }
fi

# Create RabbitMQ objects
echo "=== Creating RabbitMQ Objects ==="
rabbitmqadmin declare exchange \
   --vhost=testHost \
   name=apiExchange \
   type=direct \
   durable=true \
   --username=test \
   --password=test || { echo "Failed to create exchange"; exit 1; }

rabbitmqadmin declare queue \
   --vhost=testHost \
   name=apiQueue \
   durable=true \
   --username=test \
   --password=test || { echo "Failed to create queue"; exit 1; }

rabbitmqadmin declare binding \
   --vhost=testHost \
   source=apiExchange \
   destination=apiQueue \
   routing_key=api_routing_key \
   --username=test \
   --password=test || { echo "Failed to create binding"; exit 1; }

echo "=== Final Verification ==="
echo "MySQL Reviews Count:"
sudo mysql -u $MYSQL_USER -p$MYSQL_PASS $MYSQL_DB -e "SELECT COUNT(*) FROM reviews;"

echo "RabbitMQ Status:"
rabbitmqadmin list exchanges --vhost=testHost --username=test --password=test
rabbitmqadmin list queues --vhost=testHost --username=test --password=test
rabbitmqadmin list bindings --vhost=testHost --username=test --password=test

echo "Service Status:"
sudo systemctl status dmz-listener.service --no-pager || true

echo "=== DMZ Full Setup Complete ==="
echo "Log file available at: $LOG_FILE"
EOF

chmod +x "$TMP_DIR/setup_dmz.sh"

# ======================
# CREATE FINAL BUNDLE
# ======================
echo "=== Creating Deployment Bundle ==="
tar -czvf "$OUTPUT_FILE" -C "$TMP_DIR" .

# ======================
# TRANSFER TO DEPLOYMENT SERVER
# ======================
echo "=== Transferring to Deployment Server ==="
scp "$OUTPUT_FILE" "$DEPLOY_SERVER:$INCOMING_DIR/" || {
  echo "⚠ Failed to transfer bundle to deployment server"
  exit 1
}

# Cleanup
rm -rf "$TMP_DIR"
echo "=== DMZ Full Deployment Bundle Created ==="
echo "File: $OUTPUT_FILE"
echo "Contains:"
echo "- All API server files"
echo "- Complete MySQL database backup"
echo "- Automated setup script"
echo "Sent to: $DEPLOY_SERVER:$INCOMING_DIR/"
