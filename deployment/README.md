# SOORENA Deployment Guide

This directory contains deployment scripts and documentation for the SOORENA Shiny application.

---

## Deployment Options

Choose the deployment guide that matches your target environment:

### 1. University of Helsinki Institutional Server

**→ See [HELSINKI_DEPLOYMENT.md](HELSINKI_DEPLOYMENT.md)**

Complete step-by-step guide for deploying to University of Helsinki server with:
- Ubuntu 24.04 LTS
- Nginx reverse proxy with SSL/HTTPS
- SSL certificates provided by Helsinki IT
- Comprehensive beginner-friendly instructions
- Estimated deployment time: 45-60 minutes

**Files for Helsinki deployment:**
- [HELSINKI_DEPLOYMENT.md](HELSINKI_DEPLOYMENT.md) - Main deployment guide
- [helsinki_server_setup.sh](helsinki_server_setup.sh) - Automated server setup script
- [helsinki_deploy_app.sh](helsinki_deploy_app.sh) - Application deployment script
- [configs/nginx_helsinki.conf](configs/nginx_helsinki.conf) - Nginx configuration
- [configs/shiny-server_helsinki.conf](configs/shiny-server_helsinki.conf) - Shiny Server configuration

### 2. DigitalOcean Cloud Deployment

**→ Continue reading this document**

Instructions for deploying to DigitalOcean cloud servers with:
- GitHub Actions CI/CD automation
- Manual deployment scripts
- Support for existing or new droplets

---

## DigitalOcean Deployment

## Recommended: CI/CD (GitHub Actions)

The GitHub Actions workflow in `.github/workflows/deploy.yml` automatically deploys when you merge to `main`:
- Syncs `shiny_app/app.R`
- Syncs `shiny_app/www/`
- Restarts Shiny Server on the droplet

**Important:** The workflow **does not upload** `shiny_app/data/predictions.db`. You must upload the database separately.

### Required GitHub Secrets

Before the workflow can run, you need to configure these secrets in your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add each of these:

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `DO_SSH_KEY` | Your private SSH key for the DigitalOcean droplet | Contents of your `~/.ssh/id_rsa` or downloaded key file |
| `DO_HOST` | Public IP address of your DigitalOcean droplet | `164.90.xxx.xxx` |
| `DO_USER` | SSH username (usually `root` for DigitalOcean) | `root` |

**How to get your SSH private key:**
```bash
cat ~/.ssh/id_rsa
# Copy the entire output including -----BEGIN and -----END lines
```

---

## Files in This Directory

### Documentation
- **`README.md`** - This file (DigitalOcean deployment guide)
- **`DEPLOYMENT_GUIDE.md`** - Detailed DigitalOcean setup instructions
- **`USING_EXISTING_DROPLET.md`** - Deploy to an existing server/droplet

### Scripts
- **`server_setup_digitalocean.sh`** - Server configuration script
- **`deploy_to_digitalocean.sh`** - Manual deployment script
- **`update_app.sh`** - Quick update for app.R changes only

---

## Deployment Instructions

### Option 1: Automated CI/CD (Recommended)

1. **Set up GitHub Secrets** (see table above)
2. **Merge to main branch:**
   ```bash
   git checkout main
   git merge CLEAN-REPO
   git push origin main
   ```
3. **Upload database manually:**
   ```bash
   rsync -avz shiny_app/data/predictions.db root@<DO_HOST>:/srv/shiny-server/soorena/data/
   ssh root@<DO_HOST> "chown -R shiny:shiny /srv/shiny-server/soorena && systemctl restart shiny-server"
   ```

### Option 2: Manual Deployment

1. **Configure server** (SSH into DigitalOcean droplet):
   ```bash
   ssh root@YOUR_DROPLET_IP
   # Copy the contents of server_setup_digitalocean.sh and run it
   bash server_setup_digitalocean.sh
   ```

2. **Deploy application** (run from your local machine):
   ```bash
   cd deployment
   ./deploy_to_digitalocean.sh
   ```

---

## Scripts Usage

### server_setup_digitalocean.sh
**Purpose:** Install R, Shiny Server, and all dependencies on a fresh Ubuntu server

**Run on:** The DigitalOcean droplet (via SSH)

**Usage:**
```bash
# SSH into your droplet first
ssh root@YOUR_DROPLET_IP

# Then run the setup script
bash server_setup_digitalocean.sh
```

**What it does:**
- Updates Ubuntu
- Installs R and system dependencies
- Installs Shiny Server
- Installs required R packages (shiny, DT, plotly, etc.)
- Configures firewall (ports 22, 80, 443, 3838)
- Creates app directory at `/srv/shiny-server/soorena/`

**Run once:** You only need to run this once when setting up a new droplet.

---

### deploy_to_digitalocean.sh
**Purpose:** Deploy your complete SOORENA app to the server

**Run on:** Your local machine

**Usage:**
```bash
cd deployment
./deploy_to_digitalocean.sh
```

**What it does:**
- Tests SSH connection
- Creates app directory structure
- Uploads app.R
- Uploads database (244 MB) - **takes a few minutes**
- Uploads www/ assets
- Sets correct permissions
- Restarts Shiny Server

**When to use:**
- First deployment
- Major updates that include database changes
- When you've updated images or other assets

---

### update_app.sh
**Purpose:** Quick update when you've only changed app.R

**Run on:** Your local machine

**Usage:**
```bash
cd deployment
./update_app.sh
```

**What it does:**
- Uploads only app.R (fast!)
- Restarts Shiny Server

**When to use:**
- You fixed a UI bug
- You updated colors or styling
- You changed filters or query logic
- Any change to app.R only (no database/images)

**Advantage:** Takes seconds instead of minutes!

---

## Resource Requirements

**Recommended DigitalOcean Droplet:**
- **Size:** Basic or General Purpose
- **RAM:** 2-4 GB (minimum 2 GB for smooth operation)
- **Storage:** 50-80 GB SSD
- **OS:** Ubuntu 22.04 LTS
- **Cost:** ~$12-24/month

The database is 244 MB and the Shiny app requires ~1-2 GB RAM for comfortable operation with concurrent users.

---

## Typical Workflow

### Initial Deployment
1. Create DigitalOcean droplet (Ubuntu 22.04, 2+ GB RAM)
2. Add your SSH key during droplet creation
3. SSH into droplet: `ssh root@DROPLET_IP`
4. Run: `bash server_setup_digitalocean.sh` (on server)
5. Exit SSH
6. Run: `./deploy_to_digitalocean.sh` (on local machine)
7. Access: `http://DROPLET_IP:3838/soorena/`

### After Making Changes to app.R
1. Edit `shiny_app/app.R` on your local machine
2. Run: `./update_app.sh` (from deployment directory)
3. Refresh browser

### After Updating Database
1. Rebuild database: `python scripts/python/data_processing/create_sqlite_db.py`
2. Upload new database:
   ```bash
   rsync -avz shiny_app/data/predictions.db root@DROPLET_IP:/srv/shiny-server/soorena/data/
   ssh root@DROPLET_IP "systemctl restart shiny-server"
   ```
3. Refresh browser

---

## Security Notes

1. **SSH Key:** Keep your private SSH key secure
   - Don't commit it to git
   - Don't share it
   - Store it safely (e.g., `~/.ssh/`)

2. **Firewall:** Ports 22 (SSH), 80 (HTTP), 443 (HTTPS), and 3838 (Shiny) are open

3. **Updates:** Regularly update your server
   ```bash
   ssh root@DROPLET_IP
   sudo apt update && sudo apt upgrade -y
   ```

4. **Access Control:** Consider IP whitelisting for sensitive data

---

## Troubleshooting

### App won't load
1. Check Shiny Server status:
   ```bash
   ssh root@DROPLET_IP "sudo systemctl status shiny-server"
   ```

2. Check logs:
   ```bash
   ssh root@DROPLET_IP "sudo tail -f /var/log/shiny-server.log"
   ```

3. Verify database exists:
   ```bash
   ssh root@DROPLET_IP "ls -lh /srv/shiny-server/soorena/data/"
   ```

### Can't SSH into droplet
1. Verify IP address is correct
2. Check SSH key is added to DigitalOcean
3. Verify key permissions: `chmod 400 ~/.ssh/id_rsa`

### Port 3838 not accessible
1. Check DigitalOcean firewall settings
2. Check Ubuntu firewall: `ssh root@DROPLET_IP "sudo ufw status"`

### GitHub Actions deployment fails
1. Verify all three secrets are set correctly (`DO_SSH_KEY`, `DO_HOST`, `DO_USER`)
2. Check Actions tab on GitHub for error logs
3. Ensure the droplet is running and SSH accessible

---

## Pre-Deployment Checklist

Before running deployment scripts, verify:

- [ ] Database exists: `shiny_app/data/predictions.db`
- [ ] Database is up to date (run `create_sqlite_db.py` if needed)
- [ ] app.R has no syntax errors
- [ ] You have a DigitalOcean droplet created (Ubuntu 22.04, 2+ GB RAM)
- [ ] You have SSH access to the droplet
- [ ] GitHub secrets are configured (if using CI/CD)
- [ ] Firewall allows port 3838

---

## Success Indicators

Your deployment is successful when:
- You can access `http://DROPLET_IP:3838/soorena/` in browser
- Dashboard loads with all tabs working
- Data Explorer shows records
- Statistics charts display correctly
- Filters work properly
- Images load on all pages
- No errors in browser console
- No errors in Shiny Server logs

---

## Support

For detailed setup instructions, see:
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Step-by-step DigitalOcean setup
- [USING_EXISTING_DROPLET.md](USING_EXISTING_DROPLET.md) - Deploy to existing server