#!/bin/bash
set -e  # Exit on error

# ======================
# CONFIGURATION
# ======================
TARBALL_DIR="/home/dfc27vm/tar"
PROCESSED_DIR="/home/dfc27vm/processed_tar"
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
[ -d "$PROCESSED_DIR" ] || { echo "Creating missing processed tar directory..."; mkdir -p "$PROCESSED_DIR"; }

# ======================
# EXTRACT NEW TAR (Supports rollback tarballs)
# ======================
newest_tar=$(ls -t "$TARBALL_DIR"/*.tar.gz 2>/dev/null | head -n 1)
[ -n "$newest_tar" ] || { echo "ERROR: No .tar.gz files found"; exit 1; }

if [[ "$newest_tar" == *rollback* ]]; then
  echo "⚠ Detected rollback deployment: $newest_tar"
else
  echo "Extracting $newest_tar to $EXTRACT_DIR..."
fi

sudo rm -rf "${EXTRACT_DIR:?}/"*
sudo tar -xzf "$newest_tar" -C "$EXTRACT_DIR" || { echo "Extraction failed"; exit 1; }

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
# UPDATE IP ADDRESSES
# ======================
echo "Changing IP addrs for bookres"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/bookres.html

echo "Changing IP addrs for filter"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/filter.html

echo "Changing IP addrs for home"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/home.html

echo "Changing IP addrs for invite"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/invite.html

echo "Changing IP addrs for notiflanding"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/notiflanding.html

echo "Changing IP addrs for notiftest"
sudo sed -i 's/172\.28\.71\.226/172\.28\.24\.103/g' /var/www/html/notiftest.html

echo "Editing testRabbitMQ.ini IP address"
sudo sed -i 's/172\.28\.80\.118/172\.28\.234\.188/g' /var/www/html/testRabbitMQ.ini

# ======================
# MOVE PROCESSED TAR
# ======================
echo "Moving deployed tarball to processed directory..."
mv -v "$newest_tar" "$PROCESSED_DIR/" || echo "⚠ Failed to move tarball — manual check recommended"

echo "=== Deployment successful ==="
exit 0
