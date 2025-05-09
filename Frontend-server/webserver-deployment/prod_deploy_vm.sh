#!/bin/bash
set -e  # Exit on error

# ======================
# CONFIGURATION
# ======================
TARBALL_DIR="/home/dfc27vm/tar"
PROCESSED_TARBALL_DIR="/home/dfc27vm/processed_tar"  # New directory for processed tarballs
EXTRACT_DIR="/home/dfc27vm/extract"
WEB_ROOT="/var/www/html"
SETUP_SCRIPT="setup_webserver.sh"
LOG_FILE="/var/log/deploy.log"

# Initialize logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Deployment started: $(date) ==="

# ======================
# VERIFY DIRECTORIES
# ======================
[ -d "$TARBALL_DIR" ] || { echo "ERROR: $TARBALL_DIR missing"; exit 1; }
[ -d "$EXTRACT_DIR" ] || { echo "ERROR: $EXTRACT_DIR missing"; exit 1; }
[ -d "$PROCESSED_TARBALL_DIR" ] || { echo "ERROR: $PROCESSED_TARBALL_DIR missing"; exit 1; }

# ======================
# EXTRACT NEW TAR
# ======================
newest_tar=$(ls -t "$TARBALL_DIR"/*.tar.gz 2>/dev/null | head -n 1)
[ -n "$newest_tar" ] || { echo "ERROR: No .tar.gz files found"; exit 1; }

echo "Extracting $newest_tar to $EXTRACT_DIR..."
sudo rm -rf "${EXTRACT_DIR:?}/"*  # Clear extract dir (keeps folder)
sudo tar -xzf "$newest_tar" -C "$EXTRACT_DIR" || { echo "Extraction failed"; exit 1; }

# Move the processed tarball to the processed_tar directory
echo "Moving $newest_tar to $PROCESSED_TARBALL_DIR..."
sudo mv "$newest_tar" "$PROCESSED_TARBALL_DIR" || { echo "Failed to move tarball to processed_tar"; exit 1; }

# ======================
# RUN SETUP SCRIPT (IF EXISTS)
# ======================
if [ -f "$EXTRACT_DIR/$SETUP_SCRIPT" ]; then
  echo "Running $SETUP_SCRIPT..."
  sudo chmod +x "$EXTRACT_DIR/$SETUP_SCRIPT"
  (cd "$EXTRACT_DIR" && sudo ./"$SETUP_SCRIPT") || { echo "Setup failed"; exit 1; }
fi

# ======================
# DEPLOY TO WEB ROOT (ATOMIC)
# ======================
echo "Removing old files from $WEB_ROOT..."
sudo find "$WEB_ROOT" -mindepth 1 -maxdepth 1 ! -name '.*' -exec rm -rf {} +

echo "Copying new files..."
sudo cp -r "$EXTRACT_DIR"/* "$WEB_ROOT/"

# ======================
# REPLACE IP ADDRESSES
# ======================
echo "Changing IP addresses in HTML files..."
sudo sed -i 's/172\.28\.71\.226/172\.28\.12\.41/g' /var/www/html/*.html

echo "Changing IP address in testRabbitMQ.ini"
sudo sed -i 's/172\.28\.80\.118/172\.28\.234\.188/g' /var/www/html/testRabbitMQ.ini

echo "=== Deployment completed successfully ==="
exit 0
