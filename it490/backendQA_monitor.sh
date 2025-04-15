#This should reference only SAM's VM on QA Cluster
ssh sam@172.28.166.145 << 'EOF'
  if [ -d /path/to/deployed/app ]; then
    if pgrep -f "your_app_binary_or_service_name" > /dev/null; then
      echo "QA App is running"
    else
      echo "QA App is NOT running"
    fi
  else
    echo "QA App not found/unpacked"
  fi
EOF
