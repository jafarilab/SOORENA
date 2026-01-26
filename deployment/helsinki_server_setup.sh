#!/bin/bash

# University of Helsinki Server Setup Script for SOORENA Shiny App
# Run this script ON THE HELSINKI SERVER after SSH'ing in
#
# This script installs all required software for SOORENA:
# - R and system dependencies
# - Shiny Server
# - R packages
# - Nginx web server
#
# Prerequisites:
# - Ubuntu 24.04 LTS
# - sudo/root access
# - Internet connection
#
# Usage:
#   bash helsinki_server_setup.sh
#
# Estimated time: 20-30 minutes

set -e  # Exit on any error

echo "======================================================================"
echo "SOORENA Server Setup - University of Helsinki"
echo "======================================================================"
echo ""
echo "This script will install and configure:"
echo "  ✓ R (version 4.x) and system dependencies"
echo "  ✓ Shiny Server (version 1.5.21.1012)"
echo "  ✓ 11 required R packages"
echo "  ✓ Nginx web server"
echo "  ✓ Application directory structure"
echo ""
echo "Target environment:"
echo "  - OS: Ubuntu 24.04 LTS"
echo "  - RAM: 8 GB"
echo "  - Server: University of Helsinki"
echo ""
echo "Estimated time: 20-30 minutes"
echo ""
read -p "Continue with installation? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Setup cancelled."
    exit 0
fi

# Start timer
START_TIME=$(date +%s)

echo ""
echo "======================================================================"
echo "Step 1/9: Updating System Packages"
echo "======================================================================"
echo "This ensures all system packages are up to date..."
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo ""
echo "✓ System updated successfully"

echo ""
echo "======================================================================"
echo "Step 2/9: Installing R"
echo "======================================================================"
echo "Installing R version 4.x from official CRAN repository..."
echo ""

# Install prerequisites for adding R repository
sudo apt install -y software-properties-common dirmngr

# Add R repository GPG key (for package signature verification)
echo "Adding R repository GPG key..."
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
  sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/r-project.gpg

# Add R repository for Ubuntu 24.04
echo "Adding R repository for Ubuntu 24.04..."
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" | \
  sudo tee /etc/apt/sources.list.d/r-project.list

# Update package list and install R
echo "Installing R..."
sudo apt update
sudo apt install -y r-base r-base-dev

# Verify R installation
R_VERSION=$(R --version | head -n 1)
echo ""
echo "✓ R installed successfully: $R_VERSION"

echo ""
echo "======================================================================"
echo "Step 3/9: Installing System Dependencies"
echo "======================================================================"
echo "Installing system libraries required for R packages..."
echo "This includes libraries for:"
echo "  - Network operations (libcurl, libssl)"
echo "  - XML processing (libxml2)"
echo "  - Graphics and fonts (libpng, libfreetype, etc.)"
echo "  - Database (libsqlite3)"
echo ""

sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libfontconfig1-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libtiff5-dev \
  libjpeg-dev \
  libsqlite3-dev \
  pandoc \
  gdebi-core

echo ""
echo "✓ System dependencies installed successfully"

echo ""
echo "======================================================================"
echo "Step 4/9: Installing Shiny Server"
echo "======================================================================"
echo "Downloading and installing Shiny Server 1.5.21.1012..."
echo ""

# Download Shiny Server package
wget -q https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb

# Install Shiny Server
echo "Installing Shiny Server..."
sudo gdebi -n shiny-server-1.5.21.1012-amd64.deb

# Clean up installer
rm shiny-server-1.5.21.1012-amd64.deb

# Verify Shiny Server is running
echo ""
echo "Shiny Server status:"
sudo systemctl status shiny-server --no-pager | head -n 5

echo ""
echo "✓ Shiny Server installed successfully"

echo ""
echo "======================================================================"
echo "Step 5/9: Installing Required R Packages"
echo "======================================================================"
echo "Installing 11 R packages required by SOORENA..."
echo ""
echo "Packages to install:"
echo "  1. shiny              - Web application framework"
echo "  2. DT                 - Interactive data tables"
echo "  3. dplyr              - Data manipulation"
echo "  4. DBI                - Database interface"
echo "  5. RSQLite            - SQLite database driver"
echo "  6. shinyjs            - JavaScript integration"
echo "  7. htmltools          - HTML rendering"
echo "  8. plotly             - Interactive plots"
echo "  9. ggplot2            - Static graphics"
echo "  10. shinycssloaders   - Loading animations"
echo "  11. rsconnect         - Deployment helper"
echo ""
echo "This step takes 10-15 minutes..."
echo ""

# Install all required packages
# Note: We install as root so packages are available system-wide
sudo su - -c "R -e \"install.packages(c('shiny', 'DT', 'dplyr', 'DBI', 'RSQLite', 'shinyjs', 'htmltools', 'plotly', 'ggplot2', 'shinycssloaders', 'rsconnect'), repos='https://cran.rstudio.com/')\""

echo ""
echo "✓ R packages installed successfully"

echo ""
echo "======================================================================"
echo "Step 6/9: Installing Nginx"
echo "======================================================================"
echo "Installing Nginx web server for HTTPS support..."
echo ""

sudo apt install -y nginx

# Verify Nginx installation
NGINX_VERSION=$(nginx -v 2>&1 | cut -d '/' -f 2)
echo ""
echo "✓ Nginx installed successfully: version $NGINX_VERSION"

echo ""
echo "======================================================================"
echo "Step 7/9: Creating Application Directory Structure"
echo "======================================================================"
echo "Creating directories for SOORENA application..."
echo ""

# Create directory structure
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www

# Set temporary ownership to current user (will be changed to shiny:shiny after deployment)
sudo chown -R $USER:$USER /srv/shiny-server/soorena

echo "Directory structure:"
echo "  /srv/shiny-server/soorena/"
echo "  ├── app.R                (to be deployed)"
echo "  ├── data/"
echo "  │   └── predictions.db   (to be deployed)"
echo "  └── www/                 (to be deployed)"
echo ""
echo "✓ Directory structure created"

echo ""
echo "======================================================================"
echo "Step 8/9: Configuring Shiny Server"
echo "======================================================================"
echo "Creating Shiny Server configuration optimized for SOORENA..."
echo ""

# Backup original configuration
if [ -f /etc/shiny-server/shiny-server.conf ]; then
    sudo cp /etc/shiny-server/shiny-server.conf /etc/shiny-server/shiny-server.conf.backup
    echo "✓ Original configuration backed up"
fi

# Create Shiny Server configuration
# This configuration is optimized for:
# - 247 MB database (increased timeouts)
# - 8 GB RAM (allows 5 concurrent sessions)
# - Production environment
sudo tee /etc/shiny-server/shiny-server.conf > /dev/null <<'EOF'
# Shiny Server Configuration for SOORENA Application
# University of Helsinki Deployment

run_as shiny;
preserve_logs true;

server {
  listen 3838;
  access_log /var/log/shiny-server/access.log;

  location / {
    site_dir /srv/shiny-server;
    directory_index on;
    log_dir /var/log/shiny-server;
  }

  location /soorena {
    app_dir /srv/shiny-server/soorena;
    log_dir /var/log/shiny-server;

    # Increased timeouts for 247 MB database
    app_init_timeout 120;   # 2 minutes for initial load
    app_idle_timeout 600;   # 10 minutes idle timeout

    # Allow 5 concurrent sessions (optimized for 8GB RAM)
    simple_scheduler 5;
  }
}
EOF

echo "✓ Shiny Server configured with optimized settings"

echo ""
echo "======================================================================"
echo "Step 9/9: Enabling Services"
echo "======================================================================"
echo "Configuring services to start automatically on boot..."
echo ""

# Enable Shiny Server to start on boot
sudo systemctl enable shiny-server
sudo systemctl restart shiny-server

# Enable Nginx to start on boot
sudo systemctl enable nginx
sudo systemctl restart nginx

# Verify services are running
echo "Service status:"
echo ""

if systemctl is-active --quiet shiny-server; then
    echo "  ✓ Shiny Server: running"
else
    echo "  ✗ Shiny Server: not running"
fi

if systemctl is-active --quiet nginx; then
    echo "  ✓ Nginx: running"
else
    echo "  ✗ Nginx: not running"
fi

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

echo ""
echo "======================================================================"
echo "✓ SERVER SETUP COMPLETE!"
echo "======================================================================"
echo ""
echo "Installation completed in ${MINUTES} minutes ${SECONDS} seconds"
echo ""
echo "System Configuration:"
echo "  ✓ OS: $(lsb_release -d | cut -f2)"
echo "  ✓ R Version: $(R --version | head -n 1 | cut -d ' ' -f 3)"
echo "  ✓ Shiny Server: Installed and running on port 3838"
echo "  ✓ Nginx: Installed and running on ports 80/443"
echo "  ✓ Total RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "  ✓ Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
echo ""
echo "Application Directory:"
echo "  /srv/shiny-server/soorena/ (ready for deployment)"
echo ""
echo "======================================================================"
echo "NEXT STEPS"
echo "======================================================================"
echo ""
echo "1. Configure Nginx with SSL certificates:"
echo "   - Transfer SSL certificates from Helsinki IT to /etc/ssl/helsinki/"
echo "   - Copy nginx_helsinki.conf to /etc/nginx/sites-available/soorena"
echo "   - Update domain name in the configuration"
echo "   - Enable site: sudo ln -s /etc/nginx/sites-available/soorena /etc/nginx/sites-enabled/"
echo "   - Test: sudo nginx -t"
echo "   - Reload: sudo systemctl reload nginx"
echo ""
echo "2. Configure Firewall:"
echo "   - sudo ufw allow 22/tcp    (SSH)"
echo "   - sudo ufw allow 80/tcp    (HTTP)"
echo "   - sudo ufw allow 443/tcp   (HTTPS)"
echo "   - sudo ufw --force enable"
echo ""
echo "3. Deploy SOORENA application files:"
echo "   - From your LOCAL machine, run:"
echo "     cd SOORENA_2/deployment"
echo "     bash helsinki_deploy_app.sh"
echo ""
echo "   - Or transfer files manually:"
echo "     scp shiny_app/app.R USER@SERVER:/srv/shiny-server/soorena/"
echo "     scp shiny_app/data/predictions.db USER@SERVER:/srv/shiny-server/soorena/data/"
echo "     scp -r shiny_app/www USER@SERVER:/srv/shiny-server/soorena/"
echo ""
echo "4. Set correct permissions after deployment:"
echo "   sudo chown -R shiny:shiny /srv/shiny-server/soorena"
echo "   sudo chmod -R 755 /srv/shiny-server/soorena"
echo "   sudo systemctl restart shiny-server"
echo ""
echo "5. Verify deployment:"
echo "   - Internal test: curl -I http://localhost:3838/soorena/"
echo "   - External test: https://YOUR_DOMAIN.helsinki.fi/soorena/"
echo ""
echo "For detailed instructions, see:"
echo "  deployment/HELSINKI_DEPLOYMENT.md"
echo ""
echo "======================================================================"
echo ""
