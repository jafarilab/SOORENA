#!/bin/bash

# SOORENA Deployment Script for University of Helsinki
# This script automates the deployment of SOORENA Shiny app to Helsinki server
#
# Run this script from your LOCAL machine in the SOORENA_2/deployment directory
#
# Prerequisites:
# - Server setup completed (helsinki_server_setup.sh has been run)
# - SSH access to Helsinki server
# - Application files ready in ../shiny_app/ directory
#
# Usage:
#   bash helsinki_deploy_app.sh
#
# Estimated time: 5-10 minutes (depending on network speed)

set -e  # Exit on any error

echo "======================================================================"
echo "SOORENA Deployment - University of Helsinki"
echo "======================================================================"
echo ""

# ------------------------------------------------------------------------
# Step 1: Gather Configuration
# ------------------------------------------------------------------------
echo "Please provide the following information:"
echo ""

read -p "Helsinki server IP or hostname: " SERVER_HOST
read -p "SSH username: " SSH_USER

# Optional: SSH key path
read -p "Path to SSH key (press Enter to use default or password): " SSH_KEY

# Expand tilde if provided
if [ -n "$SSH_KEY" ]; then
    SSH_KEY="${SSH_KEY/#\~/$HOME}"

    # Verify SSH key exists
    if [ ! -f "$SSH_KEY" ]; then
        echo "WARNING: SSH key not found at $SSH_KEY"
        read -p "Continue with password authentication? (y/n): " USE_PASSWORD
        if [ "$USE_PASSWORD" != "y" ]; then
            echo "Deployment cancelled."
            exit 1
        fi
        SSH_KEY=""
    fi
fi

# Set SSH command based on whether key is provided
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY"
    SCP_CMD="scp -i $SSH_KEY"
    RSYNC_CMD="rsync -e \"ssh -i $SSH_KEY\""
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
    RSYNC_CMD="rsync"
fi

# ------------------------------------------------------------------------
# Step 2: Verify Local Files
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Verifying Local Files"
echo "======================================================================"

# Determine paths (handle both running from deployment/ or repo root)
if [ -f "../shiny_app/app.R" ]; then
    APP_PATH="../shiny_app"
elif [ -f "shiny_app/app.R" ]; then
    APP_PATH="shiny_app"
else
    echo "ERROR: Cannot find shiny_app/app.R"
    echo "Please run this script from SOORENA_2/deployment/ directory"
    exit 1
fi

# Verify app.R exists
if [ ! -f "$APP_PATH/app.R" ]; then
    echo "ERROR: app.R not found at $APP_PATH/app.R"
    exit 1
fi
echo "✓ app.R found ($(du -h "$APP_PATH/app.R" | cut -f1))"

# Verify database exists
if [ ! -f "$APP_PATH/data/predictions.db" ]; then
    echo "ERROR: predictions.db not found at $APP_PATH/data/predictions.db"
    echo ""
    echo "Please create the database first:"
    echo "  python scripts/python/data_processing/create_sqlite_db.py \\"
    echo "    --input shiny_app/data/predictions.csv \\"
    echo "    --output shiny_app/data/predictions.db"
    exit 1
fi
DB_SIZE=$(du -h "$APP_PATH/data/predictions.db" | cut -f1)
echo "✓ predictions.db found ($DB_SIZE)"

# Verify www directory exists
if [ ! -d "$APP_PATH/www" ]; then
    echo "WARNING: www directory not found at $APP_PATH/www"
    echo "Static assets (logos, images) will not be deployed"
    HAS_WWW=false
else
    WWW_SIZE=$(du -sh "$APP_PATH/www" | cut -f1)
    echo "✓ www/ directory found ($WWW_SIZE)"
    HAS_WWW=true
fi

echo ""
echo "Configuration Summary:"
echo "  Server: $SSH_USER@$SERVER_HOST"
echo "  App file: $APP_PATH/app.R"
echo "  Database: $APP_PATH/data/predictions.db ($DB_SIZE)"
if [ "$HAS_WWW" = true ]; then
    echo "  Assets: $APP_PATH/www/ ($WWW_SIZE)"
fi
echo ""

read -p "Continue with deployment? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Start timer
START_TIME=$(date +%s)

# ------------------------------------------------------------------------
# Step 3: Test SSH Connection
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Testing SSH Connection"
echo "======================================================================"

if $SSH_CMD -o ConnectTimeout=10 $SSH_USER@$SERVER_HOST "echo 'SSH connection successful!'" 2>/dev/null; then
    echo "✓ Connected to $SERVER_HOST"
else
    echo "ERROR: Cannot connect to $SERVER_HOST"
    echo "Please verify:"
    echo "  - Server hostname/IP is correct"
    echo "  - SSH service is running"
    echo "  - Firewall allows SSH (port 22)"
    echo "  - Credentials are correct"
    exit 1
fi

# ------------------------------------------------------------------------
# Step 4: Create/Verify Directory Structure
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Verifying Server Directory Structure"
echo "======================================================================"

$SSH_CMD $SSH_USER@$SERVER_HOST << 'EOF'
# Create directories if they don't exist
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www

# Set temporary permissions for upload
sudo chown -R $USER:$USER /srv/shiny-server/soorena

echo "✓ Directory structure ready"
EOF

# ------------------------------------------------------------------------
# Step 5: Transfer app.R
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Transferring Application File"
echo "======================================================================"
echo "Uploading app.R..."

$SCP_CMD "$APP_PATH/app.R" $SSH_USER@$SERVER_HOST:/tmp/app.R
$SSH_CMD $SSH_USER@$SERVER_HOST "sudo mv /tmp/app.R /srv/shiny-server/soorena/"

echo "✓ app.R uploaded successfully"

# ------------------------------------------------------------------------
# Step 6: Transfer Database
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Transferring Database"
echo "======================================================================"
echo "Uploading predictions.db ($DB_SIZE)..."
echo "This may take 2-10 minutes depending on your connection speed..."
echo ""

# Use rsync for progress and efficiency
if [ -n "$SSH_KEY" ]; then
    rsync -avz --progress -e "ssh -i $SSH_KEY" \
        "$APP_PATH/data/predictions.db" \
        $SSH_USER@$SERVER_HOST:/tmp/
else
    rsync -avz --progress \
        "$APP_PATH/data/predictions.db" \
        $SSH_USER@$SERVER_HOST:/tmp/
fi

$SSH_CMD $SSH_USER@$SERVER_HOST "sudo mv /tmp/predictions.db /srv/shiny-server/soorena/data/"

echo ""
echo "✓ Database uploaded successfully"

# ------------------------------------------------------------------------
# Step 7: Transfer www Assets (if exists)
# ------------------------------------------------------------------------
if [ "$HAS_WWW" = true ]; then
    echo ""
    echo "======================================================================"
    echo "Transferring Static Assets"
    echo "======================================================================"
    echo "Uploading www/ directory ($WWW_SIZE)..."
    echo ""

    # Upload www directory
    if [ -n "$SSH_KEY" ]; then
        rsync -avz --progress -e "ssh -i $SSH_KEY" \
            "$APP_PATH/www/" \
            $SSH_USER@$SERVER_HOST:/tmp/www/
    else
        rsync -avz --progress \
            "$APP_PATH/www/" \
            $SSH_USER@$SERVER_HOST:/tmp/www/
    fi

    $SSH_CMD $SSH_USER@$SERVER_HOST << 'EOF'
sudo rm -rf /srv/shiny-server/soorena/www
sudo mv /tmp/www /srv/shiny-server/soorena/
EOF

    echo ""
    echo "✓ Static assets uploaded successfully"
fi

# ------------------------------------------------------------------------
# Step 8: Set Correct Permissions
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Setting File Permissions"
echo "======================================================================"

$SSH_CMD $SSH_USER@$SERVER_HOST << 'EOF'
# Set ownership to shiny user (required for Shiny Server)
sudo chown -R shiny:shiny /srv/shiny-server/soorena

# Set proper permissions
sudo chmod -R 755 /srv/shiny-server/soorena

# Make database readable
sudo chmod 644 /srv/shiny-server/soorena/data/predictions.db

echo "✓ Permissions set correctly"
EOF

# ------------------------------------------------------------------------
# Step 9: Restart Shiny Server
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Restarting Shiny Server"
echo "======================================================================"

$SSH_CMD $SSH_USER@$SERVER_HOST << 'EOF'
# Restart Shiny Server
sudo systemctl restart shiny-server

# Wait for service to start
sleep 3

# Check status
if systemctl is-active --quiet shiny-server; then
    echo "✓ Shiny Server restarted successfully"
else
    echo "WARNING: Shiny Server may not be running properly"
    sudo systemctl status shiny-server --no-pager | head -n 10
fi
EOF

# ------------------------------------------------------------------------
# Step 10: Verify Deployment
# ------------------------------------------------------------------------
echo ""
echo "======================================================================"
echo "Verifying Deployment"
echo "======================================================================"

echo "Testing internal access..."
$SSH_CMD $SSH_USER@$SERVER_HOST << 'EOF'
# Test if app responds
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3838/soorena/)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Application is responding (HTTP $HTTP_CODE)"
else
    echo "WARNING: Application returned HTTP $HTTP_CODE"
    echo "Check logs: sudo tail -50 /var/log/shiny-server.log"
fi
EOF

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo "======================================================================"
echo "✓ DEPLOYMENT COMPLETE!"
echo "======================================================================"
echo ""
echo "Deployment completed in ${MINUTES} minutes ${SECONDS} seconds"
echo ""
echo "Deployed Files:"
echo "  ✓ app.R → /srv/shiny-server/soorena/app.R"
echo "  ✓ predictions.db → /srv/shiny-server/soorena/data/predictions.db"
if [ "$HAS_WWW" = true ]; then
    echo "  ✓ www/ → /srv/shiny-server/soorena/www/"
fi
echo ""
echo "======================================================================"
echo "ACCESS YOUR APPLICATION"
echo "======================================================================"
echo ""
echo "Internal Access (from server):"
echo "  http://localhost:3838/soorena/"
echo ""
echo "External Access (once Nginx is configured):"
echo "  https://YOUR_DOMAIN.helsinki.fi/soorena/"
echo ""
echo "======================================================================"
echo "NEXT STEPS"
echo "======================================================================"
echo ""
echo "If Nginx with SSL is not yet configured:"
echo ""
echo "1. Transfer SSL certificates to server:"
echo "   scp YOUR_DOMAIN.helsinki.fi.crt $SSH_USER@$SERVER_HOST:/tmp/"
echo "   scp YOUR_DOMAIN.helsinki.fi.key $SSH_USER@$SERVER_HOST:/tmp/"
echo ""
echo "2. On the server, move certificates:"
echo "   sudo mkdir -p /etc/ssl/helsinki"
echo "   sudo mv /tmp/YOUR_DOMAIN.helsinki.fi.crt /etc/ssl/helsinki/"
echo "   sudo mv /tmp/YOUR_DOMAIN.helsinki.fi.key /etc/ssl/helsinki/"
echo "   sudo chmod 644 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt"
echo "   sudo chmod 600 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key"
echo ""
echo "3. Configure Nginx:"
echo "   - Copy deployment/configs/nginx_helsinki.conf to server"
echo "   - Update domain name in configuration"
echo "   - Enable site and reload Nginx"
echo ""
echo "4. Configure firewall:"
echo "   sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp"
echo "   sudo ufw --force enable"
echo ""
echo "For detailed instructions, see:"
echo "  deployment/HELSINKI_DEPLOYMENT.md"
echo ""
echo "======================================================================"
echo "TESTING & VERIFICATION"
echo "======================================================================"
echo ""
echo "Test the application:"
echo "  1. Open https://YOUR_DOMAIN.helsinki.fi/soorena/ in browser"
echo "  2. Verify all tabs load (Dashboard, Data Explorer, Statistics, About)"
echo "  3. Test filters and data display"
echo "  4. Check that images load correctly"
echo ""
echo "Check logs if needed:"
echo "  $SSH_CMD $SSH_USER@$SERVER_HOST 'sudo tail -f /var/log/shiny-server.log'"
echo ""
echo "Check Nginx logs (if configured):"
echo "  $SSH_CMD $SSH_USER@$SERVER_HOST 'sudo tail -f /var/log/nginx/soorena_error.log'"
echo ""
echo "======================================================================"
echo ""
