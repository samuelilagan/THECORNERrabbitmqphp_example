#!/bin/bash
set -e

# ======================
# CONFIGURATION
# ======================
SOURCE_DIR="$HOME/git/rabbitmqphp_example"
DEPLOY_SERVER="qavm@172.28.234.188"  # Changed to your QA VM
INCOMING_DIR="/home/qavm/received_backups"  # Changed to QA VM's backup directory
OUTPUT_FILE="rabbitmqphp_deployment_$(date +%Y%m%d_%H%M%S).tar.gz"

# Essential files to bundle
ESSENTIAL_FILES=(
"testRabbitMQServer.php"
"dmzRabbitMQClient.php"
"mysqlconnect.php"
"localRabbitMQ.ini"
"path.inc"
"get_host_info.inc"
"rabbitMQLib.inc"
"host.ini"
"/etc/systemd/system/testRabbitMQServer.service"
"/etc/systemd/system/dmz-sync.service"
"/etc/systemd/system/dmz-sync.timer"
)

# ======================
# DEPLOYMENT PREP (unchanged)
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

# MySQL backup with complete database dump
echo "=== Backing Up MySQL Database ==="
sudo mysqldump -u root --databases users --hex-blob --triggers --routines --events \
   --complete-insert --add-drop-table > "$TMP_DIR/full_mysql_backup.sql" || {
  echo "⚠ MySQL backup failed"
  exit 1
}

# ======================
# CREATE UPDATED SETUP SCRIPT (unchanged)
# ======================
cat > "$TMP_DIR/setup.sh" << 'EOF'
#!/bin/bash
set -ex

# Improved logging setup
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(sudo tee "$LOG_FILE") 2>&1
echo "=== Starting Dependency Installation $(date) ==="

# Get current user and home directory
CURRENT_USER=$(whoami)
CURRENT_HOME=$(eval echo ~$CURRENT_USER)
PROJECT_DIR="$CURRENT_HOME/git/rabbitmqphp_example"

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

# Create RabbitMQ objects
echo "=== Creating RabbitMQ Objects ==="
{
    # Exchanges
    rabbitmqadmin declare exchange \
       --vhost=testHost \
       name=testExchange \
       type=direct \
       durable=true \
       --username=test \
       --password=test || { echo "Failed to create testExchange"; exit 1; }

    rabbitmqadmin declare exchange \
       --vhost=testHost \
       name=apiExchange \
       type=direct \
       durable=true \
       --username=test \
       --password=test || { echo "Failed to create apiExchange"; exit 1; }

    # Queues
    rabbitmqadmin declare queue \
       --vhost=testHost \
       name=testQueue \
       durable=false \
       auto_delete=true \
       --username=test \
       --password=test || { echo "Failed to create testQueue"; exit 1; }

    rabbitmqadmin declare queue \
       --vhost=testHost \
       name=apiQueue \
       durable=true \
       auto_delete=false \
       --username=test \
       --password=test || { echo "Failed to create apiQueue"; exit 1; }

    # Bindings
    rabbitmqadmin declare binding \
       --vhost=testHost \
       source=testExchange \
       destination=testQueue \
       routing_key=test_routing_key \
       --username=test \
       --password=test || { echo "Failed to create test binding"; exit 1; }

    rabbitmqadmin declare binding \
       --vhost=testHost \
       source=apiExchange \
       destination=apiQueue \
       routing_key=api_routing_key \
       --username=test \
       --password=test || { echo "Failed to create api binding"; exit 1; }
}

# Verify RabbitMQ setup
echo "=== Verifying RabbitMQ Setup ==="
rabbitmqadmin list exchanges --vhost=testHost --username=test --password=test
rabbitmqadmin list queues --vhost=testHost --username=test --password=test
rabbitmqadmin list bindings --vhost=testHost --username=test --password=test

# Start and enable MySQL service
echo "=== Starting MySQL Service ==="
sudo systemctl start mysql || { 
    echo "Failed to start MySQL. Checking logs:";
    sudo journalctl -u mysql -n 50 --no-pager;
    exit 1;
}
sudo systemctl enable mysql || { echo "Failed to enable MySQL"; exit 1; }
sleep 5  # Give MySQL time to initialize

# Configure MySQL
echo "=== Configuring MySQL Database ==="
sudo mysql << 'MYSQL_SCRIPT'
CREATE DATABASE IF NOT EXISTS users;
CREATE USER IF NOT EXISTS 'testUser'@'localhost' IDENTIFIED BY '12345';
GRANT ALL PRIVILEGES ON users.* TO 'testUser'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Restore database from backup
echo "=== Restoring MySQL Database ==="
[ -f "$PWD/full_mysql_backup.sql" ] && sudo mysql -u root users < "$PWD/full_mysql_backup.sql" || {
   echo "MySQL database restoration failed"
   exit 1
}

# Verify MySQL setup
echo "=== Verifying Database ==="
sudo mysql -u testUser -p12345 -e "USE users; SHOW TABLES;" || {
   echo "MySQL verification failed";
   exit 1;
}

# Configure systemd services
echo "=== Configuring Systemd Services ==="

# Function to configure a service
configure_service() {
    local SERVICE_FILE="$1"
    local EXEC_START="$2"
    
    if [ ! -f "$SERVICE_FILE" ]; then
       echo "Error: Service file not found at $SERVICE_FILE"
       return 1
    fi

    # Modify the service file to use current user
    sudo sed -i "s|User=.*|User=$CURRENT_USER|g" "$SERVICE_FILE"
    sudo sed -i "s|Group=.*|Group=$CURRENT_USER|g" "$SERVICE_FILE"
    sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$PROJECT_DIR|g" "$SERVICE_FILE"
    sudo sed -i "s|ExecStart=.*|ExecStart=$EXEC_START|g" "$SERVICE_FILE"

    # Install service
    sudo cp "$SERVICE_FILE" /etc/systemd/system/ || { echo "Failed to copy service file"; return 1; }
    sudo chmod 644 /etc/systemd/system/$(basename "$SERVICE_FILE") || { echo "Failed to set permissions"; return 1; }
}

# Configure services
configure_service "$PWD/testRabbitMQServer.service" "/usr/bin/php $PROJECT_DIR/testRabbitMQServer.php"
configure_service "$PWD/dmz-sync.service" "/usr/bin/php $PROJECT_DIR/dmzRabbitMQClient.php"

# Configure timer if exists
if [ -f "$PWD/dmz-sync.timer" ]; then
    sudo cp "$PWD/dmz-sync.timer" /etc/systemd/system/ || { echo "Failed to copy timer file"; exit 1; }
    sudo chmod 644 /etc/systemd/system/dmz-sync.timer || { echo "Failed to set timer permissions"; exit 1; }
fi

# Reload systemd
sudo systemctl daemon-reload || { echo "Failed to reload systemd"; exit 1; }

# Enable and start services
echo "=== Enabling Services ==="
sudo systemctl enable testRabbitMQServer.service || { echo "Failed to enable testRabbitMQServer"; exit 1; }
sudo systemctl enable dmz-sync.service || { echo "Failed to enable dmz-sync.service"; exit 1; }

if [ -f "/etc/systemd/system/dmz-sync.timer" ]; then
    sudo systemctl enable dmz-sync.timer || { echo "Failed to enable dmz-sync.timer"; exit 1; }
    sudo systemctl start dmz-sync.timer || { echo "Failed to start dmz-sync.timer"; exit 1; }
fi

# Start services with verification
start_and_verify_service() {
    local SERVICE_NAME="$1"
    
    echo "=== Starting $SERVICE_NAME ==="
    sudo systemctl start "$SERVICE_NAME" || {
       echo "Service start failed - checking logs"
       journalctl -u "$SERVICE_NAME" -n 50 --no-pager
       exit 1
    }

    sleep 2
    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
       echo "$SERVICE_NAME is not running - checking status"
       sudo systemctl status "$SERVICE_NAME" --no-pager
       journalctl -u "$SERVICE_NAME" -n 50 --no-pager
       exit 1
    fi
}

start_and_verify_service "testRabbitMQServer.service"
start_and_verify_service "dmz-sync.service"

# Final verification
echo "=== Final Verification ==="
echo "RabbitMQ Objects:"
rabbitmqadmin list exchanges --vhost=testHost --username=test --password=test
rabbitmqadmin list queues --vhost=testHost --username=test --password=test
rabbitmqadmin list bindings --vhost=testHost --username=test --password=test

echo "=== MySQL Tables ==="
sudo mysql -u testUser -p12345 -e "USE users; SHOW TABLES;"

echo "=== Service Statuses ==="
sudo systemctl status testRabbitMQServer.service --no-pager || true
sudo systemctl status dmz-sync.service --no-pager || true

if [ -f "/etc/systemd/system/dmz-sync.timer" ]; then
    sudo systemctl status dmz-sync.timer --no-pager || true
fi

echo "=== Setup Complete ==="
echo "Log file available at: $LOG_FILE"
EOF

chmod +x "$TMP_DIR/setup.sh"

# =====================================
# CREATE CLEANUP SCRIPT (unchanged)
# =====================================
cat > "$TMP_DIR/cleanup.sh" << 'EOF'
#!/bin/bash
set -ex

# ======================
# ENHANCED CLEANUP SCRIPT
# ======================
CLEANUP_LOG="/tmp/cleanup_$(date +%Y%m%d_%H%M%S).log"
exec > >(sudo tee "$CLEANUP_LOG") 2>&1
echo "=== STARTING COMPLETE CLEANUP $(date) ==="

# 1. SERVICE CLEANUP
echo "=== STOPPING SERVICES ==="
sudo systemctl stop testRabbitMQServer.service 2>/dev/null || true
sudo systemctl stop dmz-sync.service 2>/dev/null || true
sudo systemctl stop dmz-sync.timer 2>/dev/null || true

echo "=== DISABLING SERVICES ==="
sudo systemctl disable testRabbitMQServer.service 2>/dev/null || true
sudo systemctl disable dmz-sync.service 2>/dev/null || true
sudo systemctl disable dmz-sync.timer 2>/dev/null || true

echo "=== REMOVING SYSTEMD FILES ==="
sudo rm -f /etc/systemd/system/testRabbitMQServer.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/dmz-sync.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/dmz-sync.timer 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl reset-failed

# 2. RABBITMQ CLEANUP
echo "=== RESETTING RABBITMQ ==="
{
    sudo rabbitmqctl stop_app 2>/dev/null || true
    sudo rabbitmqctl reset 2>/dev/null || true
    sudo rabbitmqctl start_app 2>/dev/null || true
    sudo rabbitmqctl delete_user test 2>/dev/null || true
    sudo rabbitmqctl delete_vhost testHost 2>/dev/null || true
    sudo rm -f /usr/local/bin/rabbitmqadmin 2>/dev/null || true
} || echo "RabbitMQ cleanup completed with warnings"

# 3. MYSQL NUCLEAR OPTION
echo "=== COMPLETELY REMOVING MYSQL ==="
{
    # Stop MySQL first
    sudo systemctl stop mysql 2>/dev/null || true
    
    # Full purge
    sudo apt-get purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
    
    # Remove all database files
    sudo rm -rf /etc/mysql /var/lib/mysql /var/log/mysql*
    
    # Clean up dependencies
    sudo apt-get autoremove -y
    sudo apt-get autoclean
} || echo "MySQL removal completed with warnings"

# 4. PACKAGE CLEANUP
echo "=== REMOVING INSTALLED PACKAGES ==="
sudo apt-get remove -y --purge \
    php php-amqp php-mysql \
    rabbitmq-server \
    wget 2>/dev/null || true
sudo apt-get autoremove -y

# 5. PROJECT FILES CLEANUP (PRESERVING DIRECTORY)
echo "=== CLEARING PROJECT FILES ==="
PROJECT_DIR="$HOME/git/rabbitmqphp_example"
if [ -d "$PROJECT_DIR" ]; then
    echo "Removing contents of $PROJECT_DIR..."
    # First try with find (more precise)
    sudo find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || {
        echo "Using alternative cleanup method..."
        # Fallback method if find fails
        sudo rm -rf "$PROJECT_DIR"/* "$PROJECT_DIR"/.* 2>/dev/null || true
    }
    echo "Directory structure preserved at $PROJECT_DIR"
    # Verify cleanup
    if [ "$(ls -A "$PROJECT_DIR")" ]; then
        echo "Warning: Some files remain in $PROJECT_DIR"
    else
        echo "Project directory is now empty"
    fi
else
    echo "Project directory not found at $PROJECT_DIR - skipping"
fi

# 6. TEMP FILE CLEANUP
echo "=== CLEANING TEMPORARY FILES ==="
sudo rm -rf /tmp/rabbitmq* /tmp/mysql* 2>/dev/null || true

# FINAL CONFIRMATION
echo "=== VERIFYING CLEANUP ==="
{
    echo "Services status:"
    systemctl list-unit-files | grep -E 'testRabbitMQ|dmz-sync' || echo "No services found"
    
    echo "MySQL check:"
    which mysql || echo "MySQL not found"
    
    echo "RabbitMQ check:"
    which rabbitmqctl || echo "RabbitMQ not found"
    
    echo "Project directory status:"
    ls -ld "$PROJECT_DIR" 2>/dev/null || echo "Project directory not found"
    if [ -d "$PROJECT_DIR" ]; then
        echo "Contents count: $(find "$PROJECT_DIR" -mindepth 1 | wc -l)"
    fi
}

echo "=== CLEANUP COMPLETED SUCCESSFULLY ==="
echo "Full cleanup log available at: $CLEANUP_LOG"
EOF

chmod +x "$TMP_DIR/cleanup.sh"

# ======================
# CREATE FINAL BUNDLE
# ======================
echo "=== Creating Deployment Bundle ==="
tar -czvf "$OUTPUT_FILE" -C "$TMP_DIR" .

# ======================
# TRANSFER TO QA VM
# ======================
echo "=== Transferring to QA VM (${DEPLOY_SERVER}) ==="
scp -v "$OUTPUT_FILE" "${DEPLOY_SERVER}:${INCOMING_DIR}/" || {
  echo "Failed to transfer bundle to QA VM"
  exit 1
}

# Cleanup
rm -rf "$TMP_DIR"
echo "=== Deployment Bundle Created and Sent ==="
echo "File: $OUTPUT_FILE"
echo "Sent to: ${DEPLOY_SERVER}:${INCOMING_DIR}/"