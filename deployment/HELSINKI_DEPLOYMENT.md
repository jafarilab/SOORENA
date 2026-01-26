# SOORENA Deployment Guide - University of Helsinki

## Document Overview

This guide provides complete step-by-step instructions for deploying the SOORENA Shiny application on the University of Helsinki server. It is designed specifically for the Helsinki institutional server environment with HTTPS, SSL certificates provided by IT, and Nginx as a reverse proxy.

**Target audience:** Jehad (or anyone deploying SOORENA to Helsinki server)
**Estimated deployment time:** 45-60 minutes
**Difficulty level:** Intermediate (no prior R/Shiny experience required)

---

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Part 1: Initial Server Setup](#part-1-initial-server-setup)
5. [Part 2: Install Required Software](#part-2-install-required-software)
6. [Part 3: Configure Shiny Server](#part-3-configure-shiny-server)
7. [Part 4: Configure Nginx with SSL](#part-4-configure-nginx-with-ssl)
8. [Part 5: Deploy SOORENA Application](#part-5-deploy-soorena-application)
9. [Part 6: Testing and Verification](#part-6-testing-and-verification)
10. [Part 7: Troubleshooting](#part-7-troubleshooting)
11. [Part 8: Maintenance](#part-8-maintenance)
12. [Part 9: Quick Reference Commands](#part-9-quick-reference-commands)
13. [Appendices](#appendices)

---

## Quick Reference

For experienced users, here's a condensed checklist:

### Prerequisites Checklist
- ✓ Server: Ubuntu 24.04 LTS, 4 vCPU, 8GB RAM
- ✓ Root/sudo access
- ✓ SSL certificates from Helsinki IT (.crt and .key files)
- ✓ Domain name (or server IP as fallback)
- ✓ SOORENA repository files locally

### Installation Steps (Summary)
1. Run `helsinki_server_setup.sh` on server (20-30 min)
2. Configure Nginx with SSL certificates
3. Configure firewall (UFW)
4. Run `helsinki_deploy_app.sh` from local machine (5-10 min)
5. Test at `https://YOUR_DOMAIN.helsinki.fi/soorena/`

### Critical Configuration Files
- `/etc/nginx/sites-available/soorena` - Nginx config with SSL
- `/etc/shiny-server/shiny-server.conf` - Shiny Server config
- `/srv/shiny-server/soorena/` - Application directory

### Key Commands
```bash
# Check services
sudo systemctl status shiny-server
sudo systemctl status nginx

# View logs
sudo tail -f /var/log/shiny-server.log
sudo tail -f /var/log/nginx/soorena_error.log

# Restart services
sudo systemctl restart shiny-server
sudo systemctl restart nginx
```

---

## Prerequisites

### Server Specifications

**Confirmed working environment:**
- **Operating System:** Ubuntu 24.04 LTS
- **CPU:** 4 vCPU
- **RAM:** 8 GB
- **Disk Space:** 50+ GB available
- **Access Level:** Root or sudo privileges required

**Network requirements:**
- Ports 22 (SSH), 80 (HTTP), and 443 (HTTPS) must be accessible
- Internet connection for package installation

### What You Need Before Starting

Create this checklist and verify each item:

- [ ] **Server access:** SSH credentials for University of Helsinki server
- [ ] **SSL certificate file:** `YOUR_DOMAIN.helsinki.fi.crt` (from IT)
- [ ] **SSL private key file:** `YOUR_DOMAIN.helsinki.fi.key` (from IT)
- [ ] **Domain name:** Provided by Helsinki IT (or use server IP temporarily)
- [ ] **SOORENA repository:** Complete local copy of SOORENA_2 project
- [ ] **Application files ready:**
  - `shiny_app/app.R` (158 KB)
  - `shiny_app/data/predictions.db` (247 MB)
  - `shiny_app/www/` directory (logos, images)

### Estimated Time Breakdown

| Phase | Task | Time |
|-------|------|------|
| Part 1 | Initial server setup | 5 minutes |
| Part 2 | Install software (R, Shiny Server, Nginx, packages) | 20-30 minutes |
| Part 3 | Configure Shiny Server | 5 minutes |
| Part 4 | Configure Nginx with SSL | 10-15 minutes |
| Part 5 | Deploy application files | 5-10 minutes |
| Part 6 | Testing and verification | 5-10 minutes |
| **Total** | | **45-65 minutes** |

---

## Architecture Overview

### How the Components Work Together

SOORENA uses a multi-tier architecture for secure HTTPS access:

```
Internet
    ↓
    ↓ HTTPS (port 443)
    ↓
┌─────────────────────────────────┐
│ Nginx Web Server                │
│ - SSL/TLS termination           │
│ - Reverse proxy                 │
│ - Security headers              │
│ - Static file serving           │
└─────────────────────────────────┘
    ↓
    ↓ HTTP (port 3838, localhost only)
    ↓
┌─────────────────────────────────┐
│ Shiny Server                    │
│ - Hosts R Shiny applications    │
│ - Manages R processes           │
│ - WebSocket support             │
└─────────────────────────────────┘
    ↓
    ↓
    ↓
┌─────────────────────────────────┐
│ SOORENA R Shiny Application     │
│ - app.R (main application)      │
│ - SQLite database (247 MB)      │
│ - Static assets (www/)          │
└─────────────────────────────────┘
```

### Why Nginx?

Shiny Server doesn't support SSL/HTTPS natively. Nginx acts as a **reverse proxy** that:
1. **Handles HTTPS:** Encrypts traffic using SSL certificates from Helsinki IT
2. **Forwards requests:** Passes requests to Shiny Server on internal port 3838
3. **Adds security:** Implements security headers and modern TLS protocols
4. **Improves performance:** Caches static files and handles multiple connections efficiently
5. **WebSocket support:** Enables real-time interactivity required by Shiny applications

This architecture is standard for institutional deployments and follows security best practices.

---

## Part 1: Initial Server Setup

### Step 1.1: Connect to Server

From your local terminal, connect to the Helsinki server via SSH:

```bash
ssh YOUR_USERNAME@SERVER_IP_OR_HOSTNAME
```

**Example:**
```bash
ssh jehad@soorena.helsinki.fi
# Or if using IP:
ssh jehad@123.45.67.89
```

**If using a specific SSH key:**
```bash
ssh -i ~/.ssh/helsinki_key YOUR_USERNAME@SERVER_IP_OR_HOSTNAME
```

**First connection warning:** You may see a message about host authenticity. Type `yes` to continue.

**Verification:**
```bash
whoami
# Should show: YOUR_USERNAME

pwd
# Should show: /home/YOUR_USERNAME or similar
```

### Step 1.2: Check Server Specifications

Verify the server meets the requirements:

```bash
# Check Ubuntu version (should be 24.04)
lsb_release -a
```

**Expected output:**
```
Distributor ID: Ubuntu
Description:    Ubuntu 24.04 LTS
Release:        24.04
Codename:       noble
```

```bash
# Check RAM (should show 8GB total)
free -h
```

**Expected output:**
```
              total        used        free      shared  buff/cache   available
Mem:          7.8Gi       1.2Gi       5.1Gi        50Mi       1.5Gi       6.3Gi
```

```bash
# Check disk space (should have 20+ GB free)
df -h /
```

**Expected output:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        50G  8.5G   39G  18% /
```

```bash
# Check CPU cores (should show 4)
nproc
```

**Expected output:** `4`

**If specs don't match:** Contact Helsinki IT to verify the correct server.

### Step 1.3: Update System

Update all system packages to ensure security and compatibility:

```bash
sudo apt update
```

This downloads the latest package lists. You should see:
```
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
...
Reading package lists... Done
```

```bash
sudo apt upgrade -y
```

This upgrades all installed packages. The `-y` flag automatically confirms. This step takes 5-10 minutes.

**Why this step matters:** System updates patch security vulnerabilities and ensure compatibility with the software we'll install.

**Estimated time:** 5-10 minutes

---

## Part 2: Install Required Software

### Option A: Automated Installation (Recommended)

The easiest way is to use the provided setup script:

1. **Transfer the script to the server:**

   From your LOCAL machine:
   ```bash
   scp SOORENA_2/deployment/helsinki_server_setup.sh YOUR_USERNAME@SERVER_IP:/tmp/
   ```

2. **On the server, run the script:**

   ```bash
   bash /tmp/helsinki_server_setup.sh
   ```

   The script will:
   - Install R 4.x
   - Install system dependencies
   - Install Shiny Server
   - Install 11 required R packages
   - Install Nginx
   - Configure directory structure
   - Enable services

   **Estimated time:** 20-30 minutes

3. **Skip to Part 3** if automated installation succeeds.

### Option B: Manual Installation (Step-by-Step)

If you prefer manual installation or need to troubleshoot, follow these detailed steps:

#### Step 2.1: Install R (Version 4.x)

**What is R?**
R is a programming language for statistical computing. SOORENA is written in R using the Shiny framework.

```bash
# Install prerequisites
sudo apt install -y software-properties-common dirmngr
```

```bash
# Add R repository GPG key
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
  sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/r-project.gpg
```

```bash
# Add R repository for Ubuntu 24.04
echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" | \
  sudo tee /etc/apt/sources.list.d/r-project.list
```

```bash
# Update package list
sudo apt update
```

```bash
# Install R
sudo apt install -y r-base r-base-dev
```

**Verify installation:**
```bash
R --version
```

**Expected output:**
```
R version 4.4.1 (2024-06-14) -- "Race for Your Life"
...
```

**Estimated time:** 3-5 minutes

#### Step 2.2: Install System Dependencies

R packages require system libraries to compile. Install them now:

```bash
sudo apt install -y \
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
```

**What each library does:**

| Package | Purpose |
|---------|---------|
| `libcurl4-openssl-dev` | Network operations (downloading data) |
| `libssl-dev` | Encryption and HTTPS |
| `libxml2-dev` | XML parsing |
| `libfontconfig1-dev`, `libharfbuzz-dev`, `libfribidi-dev`, `libfreetype6-dev` | Font rendering for plots |
| `libpng-dev`, `libtiff5-dev`, `libjpeg-dev` | Image processing |
| `libsqlite3-dev` | SQLite database support |
| `pandoc` | Document conversion |
| `gdebi-core` | Package installation tool |

**Estimated time:** 2-3 minutes

#### Step 2.3: Install Shiny Server

**What is Shiny Server?**
Shiny Server is a web server specifically designed to host R Shiny applications. It manages R processes, handles user sessions, and serves the application to web browsers.

```bash
# Download Shiny Server
wget https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.21.1012-amd64.deb
```

```bash
# Install Shiny Server
sudo gdebi -n shiny-server-1.5.21.1012-amd64.deb
```

The `-n` flag means non-interactive (automatically confirms).

```bash
# Clean up installer
rm shiny-server-1.5.21.1012-amd64.deb
```

**Verify installation:**
```bash
sudo systemctl status shiny-server
```

**Expected output:**
```
● shiny-server.service - ShinyServer
     Loaded: loaded (/etc/systemd/system/shiny-server.service; enabled)
     Active: active (running) since ...
```

Press `q` to exit the status view.

**Enable auto-start on boot:**
```bash
sudo systemctl enable shiny-server
```

**Estimated time:** 2-3 minutes

#### Step 2.4: Install Required R Packages

**What are R packages?**
R packages are like libraries or modules in other programming languages. They provide additional functionality. SOORENA requires 11 specific packages.

**The 11 packages SOORENA needs:**

1. **shiny** - Core web application framework
2. **DT** - Interactive data tables with sorting/filtering
3. **dplyr** - Data manipulation (filtering, grouping)
4. **DBI** - Database interface (generic connection layer)
5. **RSQLite** - SQLite database driver (connects to predictions.db)
6. **shinyjs** - JavaScript integration (dark mode toggle, etc.)
7. **htmltools** - Safe HTML rendering
8. **plotly** - Interactive charts and graphs
9. **ggplot2** - Static graphics and plots
10. **shinycssloaders** - Loading spinners/animations
11. **rsconnect** - Deployment helper

**Install all packages:**

```bash
sudo su - -c "R -e \"install.packages(c('shiny', 'DT', 'dplyr', 'DBI', 'RSQLite', 'shinyjs', 'htmltools', 'plotly', 'ggplot2', 'shinycssloaders', 'rsconnect'), repos='https://cran.rstudio.com/')\""
```

**What this command does:**
- `sudo su - -c` - Run as root (installs system-wide)
- `R -e` - Execute R command
- `install.packages(...)` - Install the listed packages
- `repos='https://cran.rstudio.com/'` - Download from CRAN repository

**This takes 10-15 minutes.** You'll see compilation output for each package.

**Expected output:**
You should see output like:
```
* installing *binary* package 'shiny' ...
* DONE (shiny)
...
* installing *source* package 'DT' ...
** package 'DT' successfully unpacked and MD5 sums checked
...
```

**Watch for errors:**
If you see `installation of package 'X' had non-zero exit status`, check:
1. System dependencies are installed (Step 2.2)
2. Internet connection is working
3. Disk space is available

**Verify installation:**
```bash
sudo su - -c "R -e \"library(shiny); library(DT); library(RSQLite)\""
```

If successful, you'll see no errors, just version information.

**Estimated time:** 10-15 minutes

#### Step 2.5: Install Nginx

**What is Nginx?**
Nginx (pronounced "engine-x") is a high-performance web server. We'll use it as a reverse proxy to add HTTPS support to Shiny Server.

```bash
sudo apt install -y nginx
```

**Verify installation:**
```bash
nginx -v
```

**Expected output:**
```
nginx version: nginx/1.24.0 (Ubuntu)
```

```bash
sudo systemctl status nginx
```

**Expected output:**
```
● nginx.service - A high performance web server
     Active: active (running)
```

**Enable auto-start on boot:**
```bash
sudo systemctl enable nginx
```

**Test Nginx is working:**
```bash
curl -I http://localhost
```

You should see `HTTP/1.1 200 OK` in the response.

**Estimated time:** 1-2 minutes

### Checkpoint: Verify All Software

Before proceeding, verify everything is installed:

```bash
echo "✓ Checking R..."
R --version | head -n 1

echo "✓ Checking Shiny Server..."
sudo systemctl is-active shiny-server

echo "✓ Checking Nginx..."
nginx -v

echo "✓ Checking R packages..."
R -e "installed.packages()[c('shiny', 'DT', 'RSQLite'), 'Version']" 2>/dev/null | grep -E "shiny|DT|RSQLite"
```

All checks should succeed. If any fail, revisit the corresponding installation step.

---

## Part 3: Configure Shiny Server

### Step 3.1: Create Application Directory Structure

```bash
# Create directory structure
sudo mkdir -p /srv/shiny-server/soorena/data
sudo mkdir -p /srv/shiny-server/soorena/www
```

**Directory layout:**
```
/srv/shiny-server/soorena/
├── app.R              # Main application file (deployed later)
├── data/
│   └── predictions.db # SQLite database (deployed later)
└── www/               # Static assets: logos, images (deployed later)
```

**Set temporary permissions:**
```bash
sudo chmod -R 755 /srv/shiny-server/soorena
```

We'll set final permissions (shiny:shiny ownership) after deploying files.

### Step 3.2: Configure Shiny Server

**Backup original configuration:**
```bash
sudo cp /etc/shiny-server/shiny-server.conf /etc/shiny-server/shiny-server.conf.backup
```

**Create new configuration:**

You can either:

**Option A: Copy from repository (if available on server)**
```bash
sudo cp /path/to/SOORENA_2/deployment/configs/shiny-server_helsinki.conf /etc/shiny-server/shiny-server.conf
```

**Option B: Create manually**
```bash
sudo nano /etc/shiny-server/shiny-server.conf
```

Paste this configuration:

```nginx
# Shiny Server Configuration for SOORENA Application

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
```

**Save and exit:** Press `Ctrl+O`, Enter, then `Ctrl+X`

**Configuration explanation:**

- `run_as shiny;` - Run apps as the 'shiny' user (not root, for security)
- `listen 3838;` - Internal port (not exposed to internet)
- `app_init_timeout 120;` - Allow 2 minutes to load the 247 MB database
- `app_idle_timeout 600;` - Allow 10 minutes before timing out idle sessions
- `simple_scheduler 5;` - Support up to 5 concurrent users

**Why these timeouts?**
- The 247 MB database takes 30-60 seconds to load on first access
- Complex filtering operations can take 20-40 seconds
- We want to prevent premature disconnections

**Restart Shiny Server:**
```bash
sudo systemctl restart shiny-server
```

**Verify configuration:**
```bash
sudo systemctl status shiny-server
```

Should show `Active: active (running)`.

**Estimated time:** 3-5 minutes

---

## Part 4: Configure Nginx with SSL

### Step 4.1: Prepare SSL Certificates

**What you should have received from Helsinki IT:**
1. **Certificate file:** `YOUR_DOMAIN.helsinki.fi.crt`
2. **Private key file:** `YOUR_DOMAIN.helsinki.fi.key`

**Transfer certificates to server:**

From your **LOCAL machine**:
```bash
scp YOUR_DOMAIN.helsinki.fi.crt YOUR_USERNAME@SERVER_IP:/tmp/
scp YOUR_DOMAIN.helsinki.fi.key YOUR_USERNAME@SERVER_IP:/tmp/
```

**Example:**
```bash
scp soorena.helsinki.fi.crt jehad@123.45.67.89:/tmp/
scp soorena.helsinki.fi.key jehad@123.45.67.89:/tmp/
```

**On the SERVER:**

```bash
# Create directory for certificates
sudo mkdir -p /etc/ssl/helsinki

# Move certificates to proper location
sudo mv /tmp/YOUR_DOMAIN.helsinki.fi.crt /etc/ssl/helsinki/
sudo mv /tmp/YOUR_DOMAIN.helsinki.fi.key /etc/ssl/helsinki/

# Set proper permissions (IMPORTANT for security)
sudo chmod 644 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt
sudo chmod 600 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key
```

**Why these permissions?**
- Certificate (`.crt`): 644 = readable by all (public information)
- Private key (`.key`): 600 = readable only by root (must be kept secret!)

**Verify certificates:**

```bash
# Check certificate details
sudo openssl x509 -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt -text -noout | grep "Subject:"
```

Should show your domain name.

```bash
# Verify key matches certificate
sudo openssl x509 -noout -modulus -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt | openssl md5
sudo openssl rsa -noout -modulus -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key | openssl md5
```

**The two MD5 hashes MUST match.** If they don't, the certificate and key don't belong together.

**Example output:**
```
(stdin)= 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
(stdin)= 1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p
```

**If IT provided a certificate chain file:**

Some institutions provide a separate chain file (e.g., `chain.crt` or `intermediate.crt`). If so:

```bash
# Concatenate certificate and chain
sudo cat /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt /tmp/chain.crt | \
  sudo tee /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi-fullchain.crt
```

Then use `YOUR_DOMAIN.helsinki.fi-fullchain.crt` in the Nginx configuration below.

**Estimated time:** 5-7 minutes

### Step 4.2: Create Nginx Configuration for SOORENA

**Transfer the configuration template:**

From your **LOCAL machine**:
```bash
scp SOORENA_2/deployment/configs/nginx_helsinki.conf YOUR_USERNAME@SERVER_IP:/tmp/
```

**On the SERVER:**

```bash
# Copy to Nginx sites-available directory
sudo cp /tmp/nginx_helsinki.conf /etc/nginx/sites-available/soorena
```

**Update the configuration with your domain:**

```bash
sudo nano /etc/nginx/sites-available/soorena
```

**Find and replace** all instances of `YOUR_DOMAIN.helsinki.fi` with your actual domain.

For example, change:
```nginx
server_name YOUR_DOMAIN.helsinki.fi;
```
To:
```nginx
server_name soorena.helsinki.fi;
```

**Also update certificate paths** if needed:
```nginx
ssl_certificate /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt;
ssl_certificate_key /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key;
```

**If using IP address temporarily** (domain not yet available):

Replace `YOUR_DOMAIN.helsinki.fi` with your server IP:
```nginx
server_name 123.45.67.89;
```

**Note:** SSL will show warnings when using IP, but functionality will work. Update to domain once available.

**Save and exit:** `Ctrl+O`, Enter, `Ctrl+X`

**Enable the site:**

```bash
# Create symbolic link to enable site
sudo ln -s /etc/nginx/sites-available/soorena /etc/nginx/sites-enabled/
```

**Optional: Remove default site**
```bash
sudo rm /etc/nginx/sites-enabled/default
```

**Test configuration:**

```bash
sudo nginx -t
```

**Expected output:**
```
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**Common errors and fixes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `unknown directive "ssl_certificate"` | Typo in configuration | Check spelling |
| `cannot load certificate` | Wrong certificate path | Verify path with `ls /etc/ssl/helsinki/` |
| `no "ssl_certificate" is defined` | Missing certificate directive | Add ssl_certificate lines |
| `duplicate location` | Multiple location blocks with same path | Remove duplicate |

**If test succeeds, reload Nginx:**

```bash
sudo systemctl reload nginx
```

**Verify Nginx is running:**
```bash
sudo systemctl status nginx
```

Should show `Active: active (running)`.

**Estimated time:** 10-15 minutes

### Step 4.3: Configure Firewall

**Why configure firewall?**
Security best practice. Only allow necessary ports to reduce attack surface.

```bash
# Check if firewall is active
sudo ufw status
```

If inactive, configure it now:

```bash
# Allow SSH (IMPORTANT - don't lock yourself out!)
sudo ufw allow 22/tcp

# Allow HTTP (for redirect to HTTPS)
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw --force enable
```

The `--force` flag bypasses the confirmation prompt.

**Verify rules:**
```bash
sudo ufw status verbose
```

**Expected output:**
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

**IMPORTANT:** Port 3838 (Shiny Server) is **NOT** open to the internet. It's only accessible via Nginx on localhost. This is correct for security.

**Estimated time:** 2-3 minutes

### Checkpoint: Server Configuration Complete

At this point, you should have:
- ✓ R and packages installed
- ✓ Shiny Server configured and running
- ✓ Nginx configured with SSL certificates
- ✓ Firewall configured (22, 80, 443 open)

**Verify services:**
```bash
sudo systemctl status shiny-server nginx --no-pager
```

Both should show `active (running)`.

---

## Part 5: Deploy SOORENA Application

### Option A: Automated Deployment (Recommended)

Use the provided deployment script from your **LOCAL machine**:

1. **Navigate to deployment directory:**
   ```bash
   cd SOORENA_2/deployment
   ```

2. **Run the deployment script:**
   ```bash
   bash helsinki_deploy_app.sh
   ```

3. **Follow the prompts:**
   - Enter server IP or hostname
   - Enter SSH username
   - Enter SSH key path (or press Enter for password)
   - Confirm deployment

The script will:
- Test SSH connection
- Create directories
- Upload app.R
- Upload predictions.db (247 MB, takes 2-10 minutes)
- Upload www/ directory
- Set correct permissions
- Restart Shiny Server

**Estimated time:** 5-10 minutes

Skip to Part 6 if automated deployment succeeds.

### Option B: Manual Deployment

If you prefer manual control or need to troubleshoot:

#### Step 5.1: Transfer Application Files

From your **LOCAL machine**, in the SOORENA_2 directory:

**Transfer app.R:**
```bash
scp shiny_app/app.R YOUR_USERNAME@SERVER_IP:/tmp/
```

**Transfer database (247 MB - takes 2-5 minutes):**
```bash
scp shiny_app/data/predictions.db YOUR_USERNAME@SERVER_IP:/tmp/
```

You'll see progress:
```
predictions.db            247MB   2.1MB/s   01:58
```

**Transfer www directory:**
```bash
scp -r shiny_app/www YOUR_USERNAME@SERVER_IP:/tmp/
```

**Using rsync (alternative, shows progress):**
```bash
rsync -avz --progress shiny_app/data/predictions.db YOUR_USERNAME@SERVER_IP:/tmp/
rsync -avz --progress shiny_app/www/ YOUR_USERNAME@SERVER_IP:/tmp/www/
```

**Estimated time:** 5-10 minutes (depends on network speed)

#### Step 5.2: Move Files to Application Directory

On the **SERVER**:

```bash
# Move app.R
sudo mv /tmp/app.R /srv/shiny-server/soorena/

# Move database
sudo mv /tmp/predictions.db /srv/shiny-server/soorena/data/

# Move www assets
sudo rm -rf /srv/shiny-server/soorena/www  # Remove empty dir
sudo mv /tmp/www /srv/shiny-server/soorena/
```

**Verify files are in place:**
```bash
ls -lh /srv/shiny-server/soorena/
```

**Expected output:**
```
drwxr-xr-x 2 root root 4.0K Jan 26 10:00 data
-rw-r--r-- 1 root root 158K Jan 26 10:00 app.R
drwxr-xr-x 3 root root 4.0K Jan 26 10:00 www
```

```bash
ls -lh /srv/shiny-server/soorena/data/
```

Should show `predictions.db` (247M).

```bash
ls -lh /srv/shiny-server/soorena/www/
```

Should show logo files and images directory.

**Estimated time:** 2-3 minutes

#### Step 5.3: Set Correct Permissions

**Why permissions matter:**
Shiny Server runs as the 'shiny' user and must be able to read these files.

```bash
# Set ownership to shiny user
sudo chown -R shiny:shiny /srv/shiny-server/soorena

# Set directory permissions (read, execute)
sudo chmod -R 755 /srv/shiny-server/soorena

# Set database file permissions (read only)
sudo chmod 644 /srv/shiny-server/soorena/data/predictions.db
```

**Verify permissions:**
```bash
ls -la /srv/shiny-server/soorena/
```

**Expected output:**
```
drwxr-xr-x 4 shiny shiny 4096 Jan 26 10:00 .
drwxr-xr-x 3 root  root  4096 Jan 26 09:45 ..
-rw-r--r-- 1 shiny shiny 161792 Jan 26 10:00 app.R
drwxr-xr-x 2 shiny shiny 4096 Jan 26 10:00 data
drwxr-xr-x 3 shiny shiny 4096 Jan 26 10:00 www
```

Key points:
- Owner: `shiny shiny` ✓
- Directories: `drwxr-xr-x` (755) ✓
- Files: `-rw-r--r--` (644) ✓

**Estimated time:** 1-2 minutes

#### Step 5.4: Restart Services

```bash
# Restart Shiny Server to load the new app
sudo systemctl restart shiny-server

# Wait a moment for service to start
sleep 5

# Check status
sudo systemctl status shiny-server
```

**Expected output:**
```
● shiny-server.service - ShinyServer
     Active: active (running) since ...
```

**If status shows failed:** Check logs in Part 7 (Troubleshooting).

**Also verify Nginx is running:**
```bash
sudo systemctl status nginx
```

**Estimated time:** 1 minute

---

## Part 6: Testing and Verification

### Step 6.1: Test Internal Access (from server)

**Why test internally first?**
This isolates whether Shiny Server is working, separate from Nginx/SSL issues.

```bash
curl -I http://localhost:3838/soorena/
```

**Expected output:**
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
...
```

**Success indicators:**
- Status code: `200 OK` ✓
- Content-Type: `text/html` ✓

**If you get errors:**
- `Connection refused` → Shiny Server not running
- `404 Not Found` → App directory wrong or app.R missing
- `500 Internal Server Error` → App has errors, check logs

### Step 6.2: Test HTTPS Access (from local machine)

**Open your web browser and navigate to:**

```
https://YOUR_DOMAIN.helsinki.fi/soorena/
```

**Example:**
```
https://soorena.helsinki.fi/soorena/
```

**What you should see:**

1. **SSL Certificate:** Green padlock in browser (no warnings)
2. **SOORENA Dashboard:** Application loads with header and tabs
3. **Tabs visible:** Dashboard, Data Explorer, Statistics, About, Ontology

**If using IP address temporarily:**
```
https://123.45.67.89/soorena/
```

You'll see an SSL warning (expected). Click "Advanced" → "Proceed" to continue.

### Step 6.3: Verify Functionality

**Complete functionality checklist:**

- [ ] **Dashboard loads:** No error messages, loading spinners disappear
- [ ] **Header displays:** SOORENA logo and partner logos visible
- [ ] **Navigation works:** Click through all tabs (Dashboard, Data Explorer, Statistics, About, Ontology)
- [ ] **Data Explorer shows data:** Table displays with rows of data
- [ ] **Pagination works:** Navigate between pages (bottom of table)
- [ ] **Filters work:**
  - Select a mechanism type → table updates
  - Adjust probability slider → results change
  - Clear filters → full dataset returns
- [ ] **Search works:** Type in search box → results filter
- [ ] **Statistics charts display:** Bar charts and plots render
- [ ] **Images load:** Check logos in header and team photos in About tab
- [ ] **Dark mode toggle:** Click dark mode button → theme changes
- [ ] **Export works:** Click export/download button → CSV downloads
- [ ] **Details work:** Click on a row → details popup appears

**If any functionality fails:** See Part 7 (Troubleshooting).

### Step 6.4: Check Logs

**Verify no errors in logs:**

```bash
# Check Shiny Server logs (last 50 lines)
sudo tail -50 /var/log/shiny-server.log
```

**Look for:**
- ✓ `Starting Shiny app`
- ✓ `Listening on http://...`
- ✗ `ERROR` or `WARNING` messages

```bash
# Check Nginx access logs
sudo tail -50 /var/log/nginx/soorena_access.log
```

Should show HTTP 200 responses:
```
123.45.67.89 - - [26/Jan/2025:10:15:23 +0000] "GET /soorena/ HTTP/2.0" 200 ...
```

```bash
# Check Nginx error logs
sudo tail -50 /var/log/nginx/soorena_error.log
```

Should be empty or only show minor warnings (not errors).

**Estimated time:** 5-10 minutes

### Success Criteria

Deployment is successful when ALL of these are true:

✓ **Services running:**
  - `sudo systemctl status shiny-server` → active (running)
  - `sudo systemctl status nginx` → active (running)

✓ **Internal access works:**
  - `curl -I http://localhost:3838/soorena/` → HTTP 200

✓ **External HTTPS access works:**
  - `https://YOUR_DOMAIN.helsinki.fi/soorena/` loads in browser
  - No SSL warnings (green padlock)

✓ **Functionality verified:**
  - All tabs load
  - Data displays correctly
  - Filters and search work
  - Images load
  - Export works

✓ **Logs clean:**
  - No errors in Shiny Server logs
  - No errors in Nginx logs

---

## Part 7: Troubleshooting

### Issue: Cannot Connect to HTTPS Site

**Symptoms:**
- Browser shows "This site can't be reached"
- Connection refused or timeout

**Step-by-step troubleshooting:**

1. **Check DNS resolution:**
   ```bash
   nslookup YOUR_DOMAIN.helsinki.fi
   ```
   Should return the server IP. If not, contact Helsinki IT about DNS.

2. **Check Nginx is running:**
   ```bash
   sudo systemctl status nginx
   ```
   If not running:
   ```bash
   sudo systemctl start nginx
   ```

3. **Check firewall:**
   ```bash
   sudo ufw status | grep 443
   ```
   Should show:
   ```
   443/tcp                    ALLOW       Anywhere
   ```
   If not:
   ```bash
   sudo ufw allow 443/tcp
   ```

4. **Check Nginx is listening on 443:**
   ```bash
   sudo ss -tlnp | grep 443
   ```
   Should show:
   ```
   LISTEN 0 128 *:443 *:* users:(("nginx",pid=...))
   ```

5. **Check Nginx error logs:**
   ```bash
   sudo tail -100 /var/log/nginx/error.log
   ```
   Look for clues about why Nginx can't start or respond.

6. **Test with curl from server:**
   ```bash
   curl -I https://localhost/soorena/
   ```
   This bypasses DNS and tests locally.

### Issue: SSL Certificate Errors

**Symptoms:**
- Browser shows "Your connection is not private"
- NET::ERR_CERT_AUTHORITY_INVALID
- SSL certificate warnings

**Step-by-step troubleshooting:**

1. **Verify certificate files exist:**
   ```bash
   ls -la /etc/ssl/helsinki/
   ```
   Should show `.crt` and `.key` files.

2. **Check certificate validity:**
   ```bash
   sudo openssl x509 -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt -noout -dates
   ```
   Should show:
   ```
   notBefore=... (start date)
   notAfter=... (expiry date)
   ```
   Verify expiry date is in the future.

3. **Verify domain name matches:**
   ```bash
   sudo openssl x509 -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt -noout -subject
   ```
   Should show your domain:
   ```
   subject=CN=YOUR_DOMAIN.helsinki.fi
   ```

4. **Check certificate and key match:**
   ```bash
   sudo openssl x509 -noout -modulus -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt | openssl md5
   sudo openssl rsa -noout -modulus -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key | openssl md5
   ```
   The two MD5 hashes must be identical.

5. **Verify certificate permissions:**
   ```bash
   ls -l /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key
   ```
   Should show `-rw-------` (600) and owned by root.

6. **Test Nginx configuration:**
   ```bash
   sudo nginx -t
   ```
   Should report no SSL-related errors.

7. **Check if certificate chain is needed:**
   Some browsers require intermediate certificates. Test with:
   ```bash
   openssl s_client -connect YOUR_DOMAIN.helsinki.fi:443 -servername YOUR_DOMAIN.helsinki.fi
   ```
   Look for "Verify return code: 0 (ok)". If not, you may need a certificate chain.

### Issue: App Loads But Shows Errors

**Symptoms:**
- Dashboard loads but shows error messages
- "An error has occurred"
- "Database not found"

**Step-by-step troubleshooting:**

1. **Check database exists:**
   ```bash
   ls -lh /srv/shiny-server/soorena/data/predictions.db
   ```
   Should show 247M file. If missing, redeploy database.

2. **Check database permissions:**
   ```bash
   sudo -u shiny cat /srv/shiny-server/soorena/data/predictions.db > /dev/null
   ```
   Should not show permission errors. If it does:
   ```bash
   sudo chown shiny:shiny /srv/shiny-server/soorena/data/predictions.db
   sudo chmod 644 /srv/shiny-server/soorena/data/predictions.db
   ```

3. **Check Shiny logs for specific error:**
   ```bash
   sudo tail -100 /var/log/shiny-server.log
   ```
   Look for error messages that indicate the problem.

4. **Check R package installation:**
   ```bash
   sudo su - -c "R -e \"library(shiny); library(DT); library(RSQLite)\""
   ```
   All should load without errors. If not, reinstall packages (Part 2 Step 2.4).

5. **Check app.R syntax:**
   ```bash
   sudo su - -c "R -e \"source('/srv/shiny-server/soorena/app.R')\""
   ```
   This checks for syntax errors in the R code.

6. **Check database integrity:**
   ```bash
   sqlite3 /srv/shiny-server/soorena/data/predictions.db "PRAGMA integrity_check;"
   ```
   Should return `ok`. If not, database is corrupted - redeploy.

7. **Restart Shiny Server:**
   ```bash
   sudo systemctl restart shiny-server
   ```
   Sometimes a fresh start resolves issues.

### Issue: WebSocket Connection Fails

**Symptoms:**
- App loads but becomes unresponsive
- Console shows "WebSocket connection failed"
- Filters don't work, clicks don't respond

**Step-by-step troubleshooting:**

1. **Check Nginx WebSocket configuration:**
   ```bash
   grep -A 5 "Upgrade" /etc/nginx/sites-available/soorena
   ```
   Should show:
   ```nginx
   proxy_http_version 1.1;
   proxy_set_header Upgrade $http_upgrade;
   proxy_set_header Connection $connection_upgrade;
   ```

2. **Check WebSocket upgrade map:**
   ```bash
   grep -A 3 "map.*upgrade" /etc/nginx/sites-available/soorena
   ```
   Should show:
   ```nginx
   map $http_upgrade $connection_upgrade {
       default upgrade;
       '' close;
   }
   ```

3. **Test WebSocket headers:**
   ```bash
   curl -I -H "Upgrade: websocket" http://localhost:3838/soorena/
   ```
   Should include upgrade headers in response.

4. **Reload Nginx configuration:**
   ```bash
   sudo nginx -t && sudo systemctl reload nginx
   ```

5. **Check browser console (F12):**
   Look for specific WebSocket error messages. They often indicate the exact problem.

### Issue: Slow Loading

**Symptoms:**
- App takes >30 seconds to load
- "Please wait" message persists
- Timeout errors

**Causes and solutions:**

1. **Database loading (normal):**
   - **Cause:** 247 MB database takes time to load
   - **Expected:** 10-30 seconds on first access
   - **Solution:** This is normal. No action needed.

2. **Insufficient RAM:**
   ```bash
   free -h
   ```
   Check "available" memory. Should have 2+ GB free. If not:
   - Restart Shiny Server: `sudo systemctl restart shiny-server`
   - Check for memory leaks: `ps aux --sort=-%mem | head`

3. **Timeout settings too low:**
   ```bash
   grep timeout /etc/shiny-server/shiny-server.conf
   ```
   Should show:
   ```
   app_init_timeout 120;
   app_idle_timeout 600;
   ```
   If lower, increase them and restart.

4. **Check Nginx timeouts:**
   ```bash
   grep proxy_read_timeout /etc/nginx/sites-available/soorena
   ```
   Should show `300s` or higher.

5. **Check CPU usage:**
   ```bash
   top
   ```
   If CPU is consistently at 100%, the server may be underpowered.

### Issue: HTTP Redirect Not Working

**Symptoms:**
- `http://YOUR_DOMAIN.helsinki.fi` doesn't redirect to `https://`
- Browser stays on HTTP

**Step-by-step troubleshooting:**

1. **Check Nginx configuration has redirect block:**
   ```bash
   grep -A 5 "listen 80" /etc/nginx/sites-available/soorena
   ```
   Should show:
   ```nginx
   server {
       listen 80;
       server_name YOUR_DOMAIN.helsinki.fi;
       return 301 https://$server_name$request_uri;
   }
   ```

2. **Test manually:**
   ```bash
   curl -I http://YOUR_DOMAIN.helsinki.fi
   ```
   Should show:
   ```
   HTTP/1.1 301 Moved Permanently
   Location: https://YOUR_DOMAIN.helsinki.fi/
   ```

3. **Reload Nginx:**
   ```bash
   sudo nginx -t && sudo systemctl reload nginx
   ```

### Issue: Port 3838 Exposed to Internet

**Symptoms:**
- Security scan shows port 3838 open
- App accessible at `http://SERVER_IP:3838/soorena/`

**Solution:**

This is a security issue. Port 3838 should ONLY be accessible via Nginx.

```bash
# Check firewall
sudo ufw status | grep 3838
```

If port 3838 is allowed, remove it:
```bash
sudo ufw delete allow 3838/tcp
sudo ufw reload
```

Verify:
```bash
sudo ufw status
```

Port 3838 should NOT appear in the output.

---

## Part 8: Maintenance

### Updating the Application Code

**When you need to update app.R** (UI changes, logic fixes, etc.):

**From LOCAL machine:**
```bash
cd SOORENA_2
scp shiny_app/app.R YOUR_USERNAME@SERVER_IP:/tmp/
```

**On SERVER:**
```bash
sudo mv /tmp/app.R /srv/shiny-server/soorena/
sudo chown shiny:shiny /srv/shiny-server/soorena/app.R
sudo systemctl restart shiny-server
```

**Wait 5-10 seconds, then test:**
```bash
curl -I http://localhost:3838/soorena/
```

Should return `HTTP/1.1 200 OK`.

### Updating the Database

**When you need to update predictions.db** (new data, reprocessed data):

**From LOCAL machine:**
```bash
cd SOORENA_2
scp shiny_app/data/predictions.db YOUR_USERNAME@SERVER_IP:/tmp/
```

This takes 2-10 minutes depending on network speed.

**On SERVER:**
```bash
# Backup old database (optional but recommended)
sudo cp /srv/shiny-server/soorena/data/predictions.db \
       /srv/shiny-server/soorena/data/predictions.db.backup

# Replace with new database
sudo mv /tmp/predictions.db /srv/shiny-server/soorena/data/
sudo chown shiny:shiny /srv/shiny-server/soorena/data/predictions.db
sudo chmod 644 /srv/shiny-server/soorena/data/predictions.db

# Restart Shiny Server
sudo systemctl restart shiny-server
```

**Verify database loaded:**
```bash
sudo tail -20 /var/log/shiny-server.log
```

Should not show database errors.

### Updating Static Assets (Logos, Images)

**When you need to update files in www/ directory:**

**From LOCAL machine:**
```bash
cd SOORENA_2
rsync -avz --progress shiny_app/www/ YOUR_USERNAME@SERVER_IP:/tmp/www/
```

**On SERVER:**
```bash
sudo rm -rf /srv/shiny-server/soorena/www
sudo mv /tmp/www /srv/shiny-server/soorena/
sudo chown -R shiny:shiny /srv/shiny-server/soorena/www
sudo chmod -R 755 /srv/shiny-server/soorena/www
sudo systemctl restart shiny-server
```

### Monitoring Application Health

**Daily/weekly checks:**

```bash
# Check service status
sudo systemctl status shiny-server nginx --no-pager

# Check memory usage
free -h

# Check disk usage
df -h

# Check recent access (last 20 requests)
sudo tail -20 /var/log/nginx/soorena_access.log

# Check for errors
sudo tail -50 /var/log/shiny-server.log | grep -i error
sudo tail -50 /var/log/nginx/soorena_error.log
```

**Set up alerts (optional):**

Create a monitoring script `/usr/local/bin/soorena_health.sh`:

```bash
#!/bin/bash

# Check if Shiny Server is running
if ! systemctl is-active --quiet shiny-server; then
    echo "ALERT: Shiny Server is down" | mail -s "SOORENA Alert" your.email@helsinki.fi
fi

# Check if Nginx is running
if ! systemctl is-active --quiet nginx; then
    echo "ALERT: Nginx is down" | mail -s "SOORENA Alert" your.email@helsinki.fi
fi

# Check disk space (alert if >80% full)
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "ALERT: Disk usage at ${DISK_USAGE}%" | mail -s "SOORENA Alert" your.email@helsinki.fi
fi
```

Make executable: `sudo chmod +x /usr/local/bin/soorena_health.sh`

Add to crontab: `sudo crontab -e`
```
# Run health check every hour
0 * * * * /usr/local/bin/soorena_health.sh
```

### Log Rotation

**Prevent logs from filling disk:**

**Nginx logs rotate automatically** via `/etc/logrotate.d/nginx`.

Check configuration:
```bash
cat /etc/logrotate.d/nginx
```

**For Shiny Server logs**, create `/etc/logrotate.d/shiny-server`:

```bash
sudo nano /etc/logrotate.d/shiny-server
```

Add:
```
/var/log/shiny-server/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 shiny shiny
    sharedscripts
    postrotate
        systemctl reload shiny-server > /dev/null 2>&1 || true
    endscript
}
```

This keeps 14 days of logs, compresses old logs, and rotates daily.

### Security Updates

**Monthly maintenance (recommended):**

```bash
# Update system packages
sudo apt update
sudo apt upgrade -y

# Check for security updates specifically
sudo apt list --upgradable | grep -i security

# If kernel was updated, reboot is needed
# Check if reboot required:
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required"
    cat /var/run/reboot-required.pkgs
fi
```

**After updates, restart services:**
```bash
sudo systemctl restart shiny-server nginx
```

**Verify services started:**
```bash
sudo systemctl status shiny-server nginx --no-pager
```

### SSL Certificate Renewal

**When Helsinki IT provides new certificates** (typically annually):

1. **Backup old certificates:**
   ```bash
   sudo cp /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt \
          /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt.old
   sudo cp /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key \
          /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key.old
   ```

2. **Upload new certificates** (from LOCAL machine):
   ```bash
   scp NEW_CERTIFICATE.crt YOUR_USERNAME@SERVER_IP:/tmp/
   scp NEW_KEY.key YOUR_USERNAME@SERVER_IP:/tmp/
   ```

3. **Install new certificates** (on SERVER):
   ```bash
   sudo mv /tmp/NEW_CERTIFICATE.crt /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt
   sudo mv /tmp/NEW_KEY.key /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key
   sudo chmod 644 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt
   sudo chmod 600 /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.key
   ```

4. **Test new configuration:**
   ```bash
   sudo nginx -t
   ```

5. **Reload Nginx:**
   ```bash
   sudo systemctl reload nginx
   ```

6. **Verify in browser:**
   - Visit `https://YOUR_DOMAIN.helsinki.fi/soorena/`
   - Click padlock icon → Certificate → Check expiry date
   - Should show new expiry date

### Backup Strategy

**What to backup:**

1. **Application files:**
   ```bash
   sudo tar -czf soorena-backup-$(date +%Y%m%d).tar.gz \
     /srv/shiny-server/soorena/
   ```

2. **Configuration files:**
   ```bash
   sudo tar -czf soorena-config-backup-$(date +%Y%m%d).tar.gz \
     /etc/nginx/sites-available/soorena \
     /etc/shiny-server/shiny-server.conf \
     /etc/ssl/helsinki/
   ```

3. **Transfer backups off-server:**
   ```bash
   scp soorena-backup-*.tar.gz your.local.machine:/path/to/backups/
   ```

**Restore from backup:**
```bash
# Extract backup
sudo tar -xzf soorena-backup-20250126.tar.gz -C /

# Set permissions
sudo chown -R shiny:shiny /srv/shiny-server/soorena
sudo chmod -R 755 /srv/shiny-server/soorena

# Restart services
sudo systemctl restart shiny-server
```

---

## Part 9: Quick Reference Commands

### Service Management

```bash
# Check status
sudo systemctl status shiny-server
sudo systemctl status nginx

# Start services
sudo systemctl start shiny-server
sudo systemctl start nginx

# Stop services
sudo systemctl stop shiny-server
sudo systemctl stop nginx

# Restart services
sudo systemctl restart shiny-server
sudo systemctl restart nginx

# Reload configuration (Nginx only, no downtime)
sudo systemctl reload nginx

# Enable auto-start on boot
sudo systemctl enable shiny-server
sudo systemctl enable nginx

# Disable auto-start
sudo systemctl disable shiny-server
sudo systemctl disable nginx
```

### Log Viewing

```bash
# View Shiny Server logs (live)
sudo tail -f /var/log/shiny-server.log

# View last 50 lines
sudo tail -50 /var/log/shiny-server.log

# View last 100 lines with search
sudo tail -100 /var/log/shiny-server.log | grep -i error

# View Nginx access logs
sudo tail -f /var/log/nginx/soorena_access.log

# View Nginx error logs
sudo tail -f /var/log/nginx/soorena_error.log

# View system logs for service
sudo journalctl -u shiny-server -n 50
sudo journalctl -u nginx -n 50

# Follow system logs live
sudo journalctl -u shiny-server -f
```

### Testing and Verification

```bash
# Test internal access (from server)
curl -I http://localhost:3838/soorena/

# Test HTTPS (from server)
curl -I https://localhost/soorena/

# Test Nginx configuration
sudo nginx -t

# Check listening ports
sudo ss -tlnp | grep -E '(3838|80|443)'

# Check firewall status
sudo ufw status verbose

# Check service is running
systemctl is-active shiny-server
systemctl is-active nginx

# Check certificate expiry
sudo openssl x509 -in /etc/ssl/helsinki/YOUR_DOMAIN.helsinki.fi.crt -noout -dates
```

### System Monitoring

```bash
# Memory usage
free -h

# Disk usage
df -h

# Disk usage by directory
du -sh /srv/shiny-server/soorena/*

# CPU and process info
top

# Network connections
sudo netstat -tlnp

# Check who's logged in
who
```

### File Operations

```bash
# List application files
ls -lah /srv/shiny-server/soorena/

# Check file permissions
ls -la /srv/shiny-server/soorena/app.R
ls -la /srv/shiny-server/soorena/data/predictions.db

# Change ownership
sudo chown -R shiny:shiny /srv/shiny-server/soorena/

# Change permissions
sudo chmod -R 755 /srv/shiny-server/soorena/
sudo chmod 644 /srv/shiny-server/soorena/data/predictions.db

# View file content
sudo cat /etc/nginx/sites-available/soorena
sudo cat /etc/shiny-server/shiny-server.conf

# Edit configuration
sudo nano /etc/nginx/sites-available/soorena
sudo nano /etc/shiny-server/shiny-server.conf
```

---

## Appendices

### Appendix A: Server Specifications

**Minimum Requirements:**
- OS: Ubuntu 20.04 LTS or newer
- RAM: 4 GB
- Disk: 20 GB free
- CPU: 2 cores

**Recommended (Helsinki Setup):**
- OS: Ubuntu 24.04 LTS
- RAM: 8 GB
- Disk: 50 GB free
- CPU: 4 cores

**Network Requirements:**
- Inbound: 22/tcp (SSH), 80/tcp (HTTP), 443/tcp (HTTPS)
- Outbound: 80/tcp, 443/tcp (for package installation)

### Appendix B: File Sizes and Transfer Times

| File/Directory | Size | Transfer Time (Estimate) |
|----------------|------|--------------------------|
| app.R | 158 KB | <1 second |
| predictions.db | 247 MB | 2-10 minutes |
| www/ | ~5 MB | 10-30 seconds |
| **Total** | **~252 MB** | **3-11 minutes** |

*Transfer times assume university network speeds (10-50 Mbps).*

### Appendix C: Port Usage

| Port | Service | Protocol | Exposed | Purpose |
|------|---------|----------|---------|---------|
| 22 | SSH | TCP | Yes | Remote administration |
| 80 | Nginx | TCP | Yes | HTTP (redirects to 443) |
| 443 | Nginx | TCP | Yes | HTTPS (main access) |
| 3838 | Shiny Server | TCP | **No** | Internal only (via Nginx) |

### Appendix D: Configuration File Locations

| File | Purpose | Backup Before Editing |
|------|---------|----------------------|
| `/etc/nginx/sites-available/soorena` | Nginx site configuration | Yes |
| `/etc/nginx/nginx.conf` | Nginx main configuration | Yes |
| `/etc/shiny-server/shiny-server.conf` | Shiny Server configuration | Yes |
| `/etc/ssl/helsinki/` | SSL certificates | Yes |
| `/srv/shiny-server/soorena/` | Application directory | Yes |

### Appendix E: Common Error Codes

| Code | Meaning | Likely Cause | Where to Check |
|------|---------|--------------|----------------|
| 200 | OK | Success | - |
| 301 | Moved Permanently | HTTP→HTTPS redirect | Expected |
| 404 | Not Found | Wrong URL or app not deployed | Nginx logs |
| 500 | Internal Server Error | App crashed or R error | Shiny logs |
| 502 | Bad Gateway | Shiny Server not running | Both logs |
| 503 | Service Unavailable | Shiny Server overloaded | Shiny logs |
| 504 | Gateway Timeout | App taking too long to respond | Increase timeouts |

### Appendix F: Glossary

**Nginx** - High-performance web server and reverse proxy
**Reverse Proxy** - Server that forwards client requests to another server
**SSL/TLS** - Encryption protocols for secure HTTPS connections
**Certificate** - Digital file that proves identity for SSL/TLS
**Shiny Server** - Web server specifically designed for R Shiny applications
**WebSocket** - Protocol for real-time bidirectional communication (required for Shiny interactivity)
**Firewall (UFW)** - Security system that controls network traffic
**systemd** - Linux system and service manager
**Port** - Numbered endpoint for network connections
**Localhost** - The current computer (127.0.0.1)
**SSH** - Secure Shell, encrypted remote access protocol

### Appendix G: Useful Resources

**Official Documentation:**
- Shiny Server: https://docs.posit.co/shiny-server/
- Nginx: https://nginx.org/en/docs/
- R Project: https://www.r-project.org/

**Community Support:**
- Posit Community (Shiny): https://community.rstudio.com/
- Stack Overflow: https://stackoverflow.com/questions/tagged/shiny

**Security:**
- Ubuntu Security: https://ubuntu.com/security
- SSL Labs (test SSL): https://www.ssllabs.com/ssltest/

### Appendix H: Getting Help

**For deployment issues:**
1. Check this troubleshooting section (Part 7)
2. Review logs (see Quick Reference)
3. Contact: [Deployment team contact - add if available]

**For application issues:**
1. Check Shiny Server logs
2. Verify database integrity
3. Contact: [Development team contact - add if available]

**For server/infrastructure issues:**
1. Contact Helsinki IT support
2. Reference: "SOORENA Shiny Application"
3. Provide: Error logs and configuration details

---

## Document Information

**Version:** 1.0
**Last Updated:** January 2025
**Maintained by:** SOORENA Development Team
**Server Environment:** University of Helsinki

**Change Log:**
- v1.0 (January 2025) - Initial Helsinki deployment guide created

---

**End of Document**

For questions or issues not covered in this guide, please contact the SOORENA development team or refer to the official documentation linked in Appendix G.
