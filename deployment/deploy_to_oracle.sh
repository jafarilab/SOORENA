#!/bin/bash

# SOORENA Deployment Script for Oracle Cloud
# This script automates the deployment of your Shiny app to Oracle Cloud

set -e  # Exit on any error

echo "======================================================================"
echo "SOORENA Deployment to Oracle Cloud"
echo "======================================================================"
echo ""

# Configuration
read -p "Enter your Oracle Cloud VM Public IP: " SERVER_IP
read -p "Enter path to your SSH private key (e.g., ~/Downloads/ssh-key-*.key): " SSH_KEY

# Expand tilde
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

# Verify database exists (check both repo root and parent directory)
if [ -f "shiny_app/data/predictions.db" ]; then
    DB_PATH="shiny_app/data/predictions.db"
    APP_PATH="shiny_app"
elif [ -f "../shiny_app/data/predictions.db" ]; then
    DB_PATH="../shiny_app/data/predictions.db"
    APP_PATH="../shiny_app"
else
    echo "ERROR: Database not found"
    echo "Please ensure predictions.db exists in shiny_app/data/"
    exit 1
fi

echo ""
echo "Configuration:"
echo "  Server IP: $SERVER_IP"
echo "  SSH Key: $SSH_KEY"
echo "  Database size: $(du -h "$DB_PATH" | cut -f1)"
echo ""

read -p "Continue with deployment? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "======================================================================"
echo "Step 1: Testing SSH Connection"
echo "======================================================================"
ssh -i "$SSH_KEY" -o ConnectTimeout=10 ubuntu@$SERVER_IP "echo 'SSH connection successful!'"

echo ""
echo "======================================================================"
echo "Step 2: Creating App Directory on Server"
echo "======================================================================"
ssh -i "$SSH_KEY" ubuntu@$SERVER_IP << 'EOF'
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www
sudo chown -R ubuntu:ubuntu /srv/shiny-server/soorena
EOF

echo ""
echo "======================================================================"
echo "Step 3: Transferring App Files"
echo "======================================================================"
echo "Uploading app.R..."
scp -i "$SSH_KEY" "$APP_PATH/app.R" ubuntu@$SERVER_IP:/srv/shiny-server/soorena/

echo ""
echo "======================================================================"
echo "Step 4: Transferring Database (this will take a while...)"
echo "======================================================================"
echo "Uploading predictions.db (6.1 GB)..."
echo "Estimated time: 5-15 minutes depending on your connection"
echo ""

# Use rsync for better progress and resumability
rsync -avz --progress -e "ssh -i $SSH_KEY" \
    "$DB_PATH" \
    ubuntu@$SERVER_IP:/srv/shiny-server/soorena/data/

echo ""
echo "======================================================================"
echo "Step 5: Transferring Images and Assets"
echo "======================================================================"
rsync -avz --progress -e "ssh -i $SSH_KEY" \
    "$APP_PATH/www/" \
    ubuntu@$SERVER_IP:/srv/shiny-server/soorena/www/

echo ""
echo "======================================================================"
echo "Step 6: Setting Permissions"
echo "======================================================================"
ssh -i "$SSH_KEY" ubuntu@$SERVER_IP << 'EOF'
sudo chown -R shiny:shiny /srv/shiny-server/soorena
sudo chmod -R 755 /srv/shiny-server/soorena
EOF

echo ""
echo "======================================================================"
echo "Step 7: Restarting Shiny Server"
echo "======================================================================"
ssh -i "$SSH_KEY" ubuntu@$SERVER_IP << 'EOF'
sudo systemctl restart shiny-server
sleep 3
sudo systemctl status shiny-server --no-pager
EOF

echo ""
echo "======================================================================"
echo "✓ DEPLOYMENT COMPLETE!"
echo "======================================================================"
echo ""
echo "Your SOORENA app is now live at:"
echo ""
echo "    http://$SERVER_IP:3838/soorena/"
echo ""
echo "Next steps:"
echo "  1. Open the URL above in your browser"
echo "  2. Test all functionality"
echo "  3. Check logs if needed: ssh -i $SSH_KEY ubuntu@$SERVER_IP 'sudo tail -f /var/log/shiny-server.log'"
echo ""
echo "======================================================================"
