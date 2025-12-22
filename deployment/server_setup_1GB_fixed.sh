#!/bin/bash

# Oracle Cloud VM Setup Script for SOORENA Shiny App
# OPTIMIZED FOR 1 GB RAM (VM.Standard.E2.1.Micro)
# Run this script ON THE SERVER after SSH'ing in

set -e  # Exit on any error

echo "======================================================================"
echo "SOORENA Server Setup - Oracle Cloud Ubuntu VM (1 GB RAM)"
echo "======================================================================"
echo ""
echo "This script will install:"
echo "  - Swap space (4 GB virtual memory)"
echo "  - R and required system dependencies"
echo "  - Shiny Server"
echo "  - Required R packages (optimized for low memory)"
echo "  - Configure firewall"
echo ""
read -p "Continue? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "======================================================================"
echo "Step 1: Creating Swap Space (4 GB)"
echo "======================================================================"
echo "This is critical for 1 GB RAM systems!"

# Check if swap already exists
if [ -f /swapfile ]; then
    echo "  Swap file already exists, skipping creation"
else
    # Create 4 GB swap file
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Make swap permanent
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    echo "  ✓ Swap space created: 4 GB"
fi

# Verify swap
echo ""
echo "Current memory status:"
free -h

echo ""
echo "======================================================================"
echo "Step 2: Updating System"
echo "======================================================================"
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

echo ""
echo "======================================================================"
echo "Step 3: Installing R"
echo "======================================================================"
# Add R repository with proper key
sudo apt install -y software-properties-common dirmngr

# Add the R GPG key properly
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marmoset.gpg | sudo gpg --dearmor -o /usr/share/keyrings/r-project.gpg

# Add R repository with signed-by
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" | sudo tee /etc/apt/sources.list.d/r-project.list

# Install R
sudo apt update
sudo apt install -y r-base r-base-dev

echo ""
echo "R Version:"
R --version | head -n 1

echo ""
echo "======================================================================"
echo "Step 4: Installing System Dependencies for R Packages"
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
  gdebi-core \
  htop

echo ""
echo "======================================================================"
echo "Step 5: Installing Shiny Server"
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
echo "Step 6: Installing Required R Packages"
echo "======================================================================"
echo "⚠️  This will take 15-20 minutes on 1 GB RAM system"
echo "Installing packages ONE AT A TIME to avoid memory issues..."
echo ""

# Install packages one by one to avoid memory exhaustion
packages=("shiny" "shinydashboard" "DT" "plotly" "dplyr" "RSQLite" "scales")

for pkg in "${packages[@]}"; do
    echo "Installing $pkg..."
    sudo su - -c "R -e \"install.packages('$pkg', repos='https://cran.rstudio.com/')\"" || {
        echo "⚠️  Warning: Failed to install $pkg, retrying..."
        sudo su - -c "R -e \"install.packages('$pkg', repos='https://cran.rstudio.com/')\""
    }
    echo "  ✓ $pkg installed"
    echo ""
done

echo ""
echo "======================================================================"
echo "Step 7: Configuring Firewall"
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
echo "Step 8: Creating App Directory"
echo "======================================================================"
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www
sudo chown -R ubuntu:ubuntu /srv/shiny-server/soorena

echo ""
echo "======================================================================"
echo "Step 9: Configuring Shiny Server for Low Memory"
echo "======================================================================"

# Create optimized Shiny Server config
sudo tee /etc/shiny-server/shiny-server.conf > /dev/null <<'EOF'
# Shiny Server Configuration - Optimized for 1 GB RAM

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

    # Memory optimization settings
    app_init_timeout 120;
    app_idle_timeout 300;
  }
}
EOF

echo "  ✓ Shiny Server configured for low memory"

echo ""
echo "======================================================================"
echo "Step 10: Enabling Shiny Server Auto-Start"
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
echo "  Swap Space: $(free -h | grep Swap | awk '{print $2}')"
echo "  Available Disk: $(df -h / | tail -1 | awk '{print $4}')"
echo ""
echo "Next steps:"
echo "  1. Exit this SSH session (type 'exit')"
echo "  2. On your LOCAL machine, run:"
echo "     cd /Users/halao/Desktop/SOORENA_2/deployment"
echo "     ./deploy_to_oracle.sh"
echo ""
echo "⚠️  NOTE: With 1 GB RAM, initial database load will be slow."
echo "    First access may take 30-60 seconds. Be patient!"
echo ""
echo "======================================================================"
