#!/bin/bash
set -e

# ======================
# CONFIGURATION
# ======================
SOURCE_DIR="/var/www/html"
DEPLOY_SERVER="acepino@172.28.197.192"
INCOMING_DIR="/home/acepino/git/rabbitmqphp_example/it490/incoming_tar_frontend"
OUTPUT_FILE="webserver_full_deployment_$(date +%Y%m%d_%H%M%S).tar.gz"

# Essential files to bundle
ESSENTIAL_FILES=(
  "services/my-service.service"
  "path.inc"
  "get_host_info.inc"
  "host.ini"
  "app.js"
  "jquery.slicknav.min.js"
  "rabbitMQLib.inc"
  "bookres.html"
  "bookres.php"
  "composer.json"
  "package.json"
  "logger.php"
  "slicknav.css"
  "confirmation.html"
  "login.php"
  "corner.css"
  "loglistener.php"
  "filterhandle.php"
  "testRabbitMQClient.php"
  "filter.html"
  "my-service.sh"
  "testRabbitMQ.ini"
  "home.html"
  "index.html"
  "notiflanding.html"
  "invite.html"
  "notiftest.html"
)

# ======================
# DEPLOYMENT PREP
# ======================
TMP_DIR=$(mktemp -d)

echo "=== Bundling Web Server Files ==="
for file in "${ESSENTIAL_FILES[@]}"; do
  if [[ $file == /* ]]; then
	sudo cp -v "$file" "$TMP_DIR/" || {
  	echo "⚠ Failed to copy system file: $file"
  	exit 1
	}
  elif [ -f "$SOURCE_DIR/$file" ]; then
	mkdir -p "$(dirname "$TMP_DIR/$file")"
	cp -v "$SOURCE_DIR/$file" "$TMP_DIR/$file" || {
  	echo "⚠ Failed to copy project file: $file"
  	exit 1
	}
  elif [ -d "$SOURCE_DIR/$file" ]; then
	cp -rv "$SOURCE_DIR/$file" "$TMP_DIR/$file" || {
  	echo "⚠ Failed to copy directory: $file"
  	exit 1
	}
  else
	echo "⚠ Warning: Optional file '$file' not found (continuing)"
  fi
done

# ======================
# CREATE COMPLETE SETUP SCRIPT
# ======================
cat > "$TMP_DIR/setup_webserver.sh" << 'EOF'
#!/bin/bash
set -ex

# Logging setup
LOG_FILE="/tmp/webserver_full_setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee "$LOG_FILE") 2>&1

echo "=== Starting Web Server Full Setup $(date) ==="

# Install required packages
echo "=== Installing Dependencies ==="
sudo apt-get update && sudo apt-get install -y \
  apache2 \
  php \
  nodejs npm \
  wget || { echo "Package install failed"; exit 1; }

# Set working directory (assumes script is run from the bundle dir)
cd "$(dirname "$0")"

# Install Node.js dependencies
echo "=== Installing Node.js Dependencies ==="
if [ -f package.json ]; then
  npm install || { echo "npm install failed"; exit 1; }
else
  echo "No package.json found — skipping npm install"
fi

# Copy web files to Apache root
echo "=== Deploying Web Files to Apache ==="
sudo cp *.html *.php *.css *.js /var/www/html/ || echo "Some file types may be missing — continuing"

# Configure systemd service
echo "=== Configuring Web Server Listener Service ==="
if [ -f "services/my-service.service" ]; then
  sudo cp services/my-service.service /etc/systemd/system/my-service.service || { echo "Failed to copy service file"; exit 1; }
  sudo systemctl daemon-reload
  sudo systemctl enable my-service.service
  sudo systemctl start my-service.service || {
	echo "⚠ Service start failed - checking logs"
	journalctl -u my-service.service -n 50 --no-pager
	exit 1
  }
fi

# Ensure Apache is running
echo "=== Starting Apache Web Server ==="
sudo systemctl start apache2 || echo "⚠ Apache start failed — check service status manually"

echo "Service Status:"
sudo systemctl status my-service.service --no-pager || true

echo "=== Web Server Full Setup Complete ==="
echo "Log file available at: $LOG_FILE"
EOF

chmod +x "$TMP_DIR/setup_webserver.sh"

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
echo "=== Web Server Full Deployment Bundle Created ==="
echo "File: $OUTPUT_FILE"
echo "Contains:"
echo "- All web server files"
echo "- Apache, PHP and Node.js setup"
echo "- Auto setup script for full deployment"
echo "Sent to: $DEPLOY_SERVER:$INCOMING_DIR/"
