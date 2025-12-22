#!/bin/bash

# Digital Ocean Droplet Setup Script for SOORENA Shiny App
# Run this script ON THE DROPLET after SSH'ing in

set -e  # Exit on any error

echo "======================================================================"
echo "SOORENA Server Setup - Digital Ocean Ubuntu Droplet"
echo "======================================================================"
echo ""
echo "This script will install:"
echo "  - R and required system dependencies"
echo "  - Shiny Server"
echo "  - Required R packages"
echo "  - Configure firewall"
echo ""
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "======================================================================"
echo "Step 1: Updating System"
echo "======================================================================"
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo ""
echo "======================================================================"
echo "Step 2: Installing R"
echo "======================================================================"
# Add R repository with proper key
sudo apt install -y software-properties-common dirmngr

# Add the R GPG key properly (non-interactive)
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/r-project.gpg

# Add R repository with signed-by
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" | sudo tee /etc/apt/sources.list.d/r-project.list

# Install R
sudo apt update
sudo apt install -y r-base r-base-dev

echo ""
echo "R Version:"
R --version | head -n 1

echo ""
echo "======================================================================"
echo "Step 3: Installing System Dependencies for R Packages"
echo "======================================================================"
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
echo "======================================================================"
echo "Step 4: Installing Shiny Server"
echo "======================================================================"
# Download Shiny Server
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb

# Install Shiny Server
sudo gdebi -n shiny-server-1.5.21.1012-amd64.deb

# Clean up
rm shiny-server-1.5.21.1012-amd64.deb

echo ""
echo "Shiny Server Status:"
sudo systemctl status shiny-server --no-pager | head -n 5

echo ""
echo "======================================================================"
echo "Step 5: Installing Required R Packages"
echo "======================================================================"
echo "Installing R packages..."
echo ""

# Install all required packages
sudo su - -c "R -e \"install.packages(c('shiny', 'shinydashboard', 'DT', 'plotly', 'dplyr', 'DBI', 'RSQLite', 'scales', 'shinyjs', 'shinycssloaders', 'ggplot2', 'htmltools', 'rsconnect'), repos='https://cran.rstudio.com/')\""

echo ""
echo "======================================================================"
echo "Step 6: Configuring Firewall (UFW)"
echo "======================================================================"
# Allow SSH
sudo ufw allow 22/tcp

# Allow Shiny Server
sudo ufw allow 3838/tcp

# Enable firewall
sudo ufw --force enable

echo ""
echo "Firewall Status:"
sudo ufw status

echo ""
echo "======================================================================"
echo "Step 7: Creating App Directory"
echo "======================================================================"
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www
sudo chown -R $USER:$USER /srv/shiny-server/soorena

echo ""
echo "======================================================================"
echo "Step 8: Configuring Shiny Server"
echo "======================================================================"

# Create Shiny Server config
sudo tee /etc/shiny-server/shiny-server.conf > /dev/null <<'EOF'
# Shiny Server Configuration

run_as shiny;

server {
  listen 3838;

  location / {
    site_dir /srv/shiny-server;
    log_dir /var/log/shiny-server;
    directory_index on;
  }

  location /soorena {
    app_dir /srv/shiny-server/soorena;
    log_dir /var/log/shiny-server;

    # Generous timeout for large database
    app_init_timeout 120;
    app_idle_timeout 600;
  }
}
EOF

echo "  ✓ Shiny Server configured"

echo ""
echo "======================================================================"
echo "Step 9: Enabling Shiny Server Auto-Start"
echo "======================================================================"
sudo systemctl enable shiny-server
sudo systemctl restart shiny-server

echo ""
echo "======================================================================"
echo "✓ SERVER SETUP COMPLETE!"
echo "======================================================================"
echo ""
echo "System Configuration:"
echo "  IP Address: $(curl -s ifconfig.me)"
echo "  Total RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "  Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
echo ""
echo "Next steps:"
echo "  1. Exit this SSH session (type 'exit')"
echo "  2. On your LOCAL machine, run:"
echo "     cd /Users/halao/Desktop/SOORENA_2/deployment"
echo "     ./deploy_to_digitalocean.sh"
echo ""
echo "======================================================================"
