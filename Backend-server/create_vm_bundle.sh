#!/bin/bash
set -e


# ======================
# CONFIGURATION
# ======================
SOURCE_DIR="$HOME/git/rabbitmqphp_example"
DEPLOY_SERVER="acepino@172.28.197.192"
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar"
OUTPUT_FILE="rabbitmqphp_deployment_$(date +%Y%m%d_%H%M%S).tar.gz"


# Essential files to bundle
ESSENTIAL_FILES=(
"testRabbitMQServer.php"
"mysqlconnect.php"
"localRabbitMQ.ini"
"path.inc"
"get_host_info.inc"
"rabbitMQLib.inc"
"host.ini"
"/etc/systemd/system/testRabbitMQServer.service"
)


# ======================
# DEPLOYMENT PREP
# ======================
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR"


echo "=== Bundling Essential Files ==="
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
      echo "Error: Missing file '$file'"
      exit 1
  fi
done


# MySQL backup with complete database dump including all tables
echo "=== Backing Up MySQL Database ==="
sudo mysqldump -u root --databases users --hex-blob --triggers --routines --events \
   --complete-insert --add-drop-table > "$TMP_DIR/full_mysql_backup.sql" || {
  echo "⚠ MySQL backup failed"
  exit 1
}


# ======================
# CREATE UPDATED SETUP SCRIPT
# ======================
cat > "$TMP_DIR/setup.sh" << 'EOF'
#!/bin/bash
set -ex


# Improved logging setup
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(sudo tee "$LOG_FILE") 2>&1
echo "=== Starting Dependency Installation $(date) ==="


# Install packages
echo "=== Installing Dependencies ==="
sudo apt-get update && sudo apt-get install -y \
   php php-amqp php-mysql \
   rabbitmq-server mysql-server \
   wget || { echo "Package install failed"; exit 1; }


# Configure RabbitMQ
echo "=== Configuring RabbitMQ ==="
sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl restart rabbitmq-server || { echo "RabbitMQ restart failed"; exit 1; }
sleep 10


# Reset RabbitMQ test environment
echo "=== Configuring RabbitMQ Test Environment ==="
{
   sudo rabbitmqctl delete_user test 2>/dev/null || true
   sudo rabbitmqctl delete_vhost testHost 2>/dev/null || true
   sudo rabbitmqctl add_vhost testHost || { echo "Failed to create vhost"; exit 1; }
   sudo rabbitmqctl add_user test test || { echo "Failed to create user"; exit 1; }
   sudo rabbitmqctl set_user_tags test administrator || { echo "Failed to set admin tag"; exit 1; }
   sudo rabbitmqctl set_permissions -p testHost test ".*" ".*" ".*" || { echo "Failed to set permissions"; exit 1; }
}


# Install rabbitmqadmin
echo "=== Installing rabbitmqadmin ==="
sudo wget -q -O /usr/local/bin/rabbitmqadmin \
   http://127.0.0.1:15672/cli/rabbitmqadmin || {
   sleep 5
   sudo wget -q -O /usr/local/bin/rabbitmqadmin \
       http://127.0.0.1:15672/cli/rabbitmqadmin || {
       echo "Failed to download rabbitmqadmin"
       exit 1
   }
}
sudo chmod +x /usr/local/bin/rabbitmqadmin


# Configure MySQL - IMPORTANT CHANGES HERE
echo "=== Configuring MySQL Database ==="
sudo mysql << 'MYSQL_SCRIPT'
CREATE DATABASE IF NOT EXISTS users;
CREATE USER IF NOT EXISTS 'testUser'@'localhost' IDENTIFIED BY '12345';
GRANT ALL PRIVILEGES ON users.* TO 'testUser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT


# Restore database from backup with proper permissions
echo "=== Restoring MySQL Database ==="
sudo mysql -u root users < "$PWD/full_mysql_backup.sql" || {
   echo "⚠ MySQL database restoration failed"
   exit 1
}


# Verify MySQL setup and tables
echo "=== Verifying Database ==="
sudo mysql -u testUser -p12345 -e "USE users; SHOW TABLES;" || {
   echo "MySQL verification failed";
   exit 1;
}


# Create RabbitMQ objects
echo "=== Creating RabbitMQ Objects ==="
rabbitmqadmin declare exchange \
   --vhost=testHost \
   name=testExchange \
   type=direct \
   durable=true \
   --username=test \
   --password=test || { echo "Failed to create exchange"; exit 1; }


rabbitmqadmin declare queue \
   --vhost=testHost \
   name=testQueue \
   durable=true \
   --username=test \
   --password=test || { echo "Failed to create queue"; exit 1; }


rabbitmqadmin declare binding \
   --vhost=testHost \
   source=testExchange \
   destination=testQueue \
   routing_key=testKey \
   --username=test \
   --password=test || { echo "Failed to create binding"; exit 1; }


# Setup systemd service
echo "=== Configuring Systemd Service ==="
SERVICE_FILE="$PWD/testRabbitMQServer.service"
if [ ! -f "$SERVICE_FILE" ]; then
   echo "Error: Service file not found at $SERVICE_FILE"
   exit 1
fi


# Get current username
CURRENT_USER=$(whoami)
CURRENT_HOME=$(eval echo ~$CURRENT_USER)


# Modify the service file to use current user
sudo sed -i "s|User=.*|User=$CURRENT_USER|g" "$SERVICE_FILE"
sudo sed -i "s|Group=.*|Group=$CURRENT_USER|g" "$SERVICE_FILE"
sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$CURRENT_HOME/git/rabbitmqphp_example|g" "$SERVICE_FILE"
sudo sed -i "s|ExecStart=.*|ExecStart=/usr/bin/php $CURRENT_HOME/git/rabbitmqphp_example/testRabbitMQServer.php|g" "$SERVICE_FILE"


# Install service
echo "=== Installing Systemd Service ==="
sudo cp "$SERVICE_FILE" /etc/systemd/system/ || { echo "Failed to copy service file"; exit 1; }
sudo chmod 644 /etc/systemd/system/testRabbitMQServer.service || { echo "Failed to set permissions"; exit 1; }
sudo systemctl daemon-reload || { echo "Failed to reload systemd"; exit 1; }
sudo systemctl enable testRabbitMQServer.service || { echo "Failed to enable service"; exit 1; }


# Add pre-start validation
echo "=== Validating Service Configuration ==="
sudo systemctl cat testRabbitMQServer.service || { echo "Failed to verify service config"; exit 1; }


# Start with logging
echo "=== Starting Service with Detailed Logging ==="
sudo systemctl start testRabbitMQServer.service || {
   echo "⚠ Service start failed - checking logs"
   journalctl -u testRabbitMQServer.service -n 50 --no-pager
   exit 1
}


# Verify service is running
sleep 2
if ! systemctl is-active --quiet testRabbitMQServer.service; then
   echo "⚠ Service is not running - checking status"
   sudo systemctl status testRabbitMQServer.service --no-pager
   journalctl -u testRabbitMQServer.service -n 50 --no-pager
   exit 1
fi


# Verify setup
echo "=== Verification ==="
echo "RabbitMQ Objects:"
rabbitmqadmin list exchanges --vhost=testHost --username=test --password=test
rabbitmqadmin list queues --vhost=testHost --username=test --password=test
rabbitmqadmin list bindings --vhost=testHost --username=test --password=test


echo "=== MySQL Tables ==="
sudo mysql -u testUser -p12345 -e "USE users; SHOW TABLES;"


echo "=== Service Status ==="
sudo systemctl status testRabbitMQServer.service --no-pager || {
   echo "⚠ Service check failed"
   exit 1
}


echo "=== Setup Complete ==="
echo "Log file available at: $LOG_FILE"
EOF


chmod +x "$TMP_DIR/setup.sh"


# ======================
# CREATE FINAL BUNDLE
# ======================
echo "=== Creating Deployment Bundle ==="
tar -czvf "$OUTPUT_FILE" -C "$TMP_DIR" .


# ======================
# TRANSFER TO DEPLOYMENT SERVER
# ======================
echo "=== Transferring to Deployment Server ==="
scp -v "$OUTPUT_FILE" "$DEPLOY_SERVER:$INCOMING_DIR/$OUTPUT_FILE" || {
  echo "Failed to transfer bundle to deployment server"
  exit 1
}


# Cleanup
rm -rf "$TMP_DIR"
echo "=== Deployment Bundle Created and Sent ==="
echo "File: $OUTPUT_FILE"
echo "Sent to: $DEPLOY_SERVER:$INCOMING_DIR/"
echo "The deployment server will automatically distribute it to target VMs"