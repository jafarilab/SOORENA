#!/bin/bash

# Quick Update Script - Deploy only app.R changes
# Use this when you've only modified app.R (no database/image changes)

set -e

echo "======================================================================"
echo "SOORENA Quick Update (app.R only)"
echo "======================================================================"
echo ""

# Configuration
read -p "Enter your Oracle Cloud VM Public IP: " SERVER_IP
read -p "Enter path to your SSH private key: " SSH_KEY

# Expand tilde
SSH_KEY="${SSH_KEY/#\~/$HOME}"

# Verify files exist
if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found at $SSH_KEY"
    exit 1
fi

if [ ! -f "shiny_app/app.R" ]; then
    echo "ERROR: app.R not found at shiny_app/app.R"
    exit 1
fi

echo ""
echo "Uploading app.R to server..."
scp -i "$SSH_KEY" shiny_app/app.R ubuntu@$SERVER_IP:/srv/shiny-server/soorena/

echo ""
echo "Restarting Shiny Server..."
ssh -i "$SSH_KEY" ubuntu@$SERVER_IP "sudo systemctl restart shiny-server"

echo ""
echo "======================================================================"
echo "✓ UPDATE COMPLETE!"
echo "======================================================================"
echo ""
echo "Your updated app is live at:"
echo "    http://$SERVER_IP:3838/soorena/"
echo ""
echo "Refresh your browser to see changes."
echo "======================================================================"
